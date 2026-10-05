#include "httplib.h"
#include "json.hpp"
#include "metrics.hpp"
#include "utils.hpp"
#include <algorithm>
#include <atomic>
#include <chrono>
#include <deque>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <mutex>
#include <string>
#include <vector>

using json = nlohmann::json;
namespace fs = std::filesystem;

struct Config {
    std::string host = "0.0.0.0";
    int port = 3000;
    std::string musicDirectory = "songs";
    size_t maxQueueSize = 50;
    size_t maxHistorySize = 10;
    int readTimeout = 15;
    int writeTimeout = 15;
    size_t keepAliveMaxCount = 20;
    std::string baseUrl = "";
    // "text" (default, human-friendly) or "json" (one JSON object per line on
    // stdout — what the ELK stack in monitoring/ ingests).
    std::string logFormat = "text";
};

Config config;

// Loads settings from config.json, falling back to the defaults above for
// anything missing. Missing/unparseable file is not fatal — just a warning.
void loadConfig(const std::string& path) {
    std::ifstream file(path);
    if (!file) {
        std::cerr << "WARNING: " << path << " not found, using default settings" << std::endl;
        return;
    }
    try {
        json j;
        file >> j;
        if (j.contains("host")) config.host = j["host"].get<std::string>();
        if (j.contains("port")) config.port = j["port"].get<int>();
        if (j.contains("music_directory")) config.musicDirectory = j["music_directory"].get<std::string>();
        if (j.contains("max_queue_size")) config.maxQueueSize = j["max_queue_size"].get<size_t>();
        if (j.contains("max_history_size")) config.maxHistorySize = j["max_history_size"].get<size_t>();
        if (j.contains("read_timeout")) config.readTimeout = j["read_timeout"].get<int>();
        if (j.contains("write_timeout")) config.writeTimeout = j["write_timeout"].get<int>();
        if (j.contains("keep_alive_max_count")) config.keepAliveMaxCount = j["keep_alive_max_count"].get<size_t>();
        if (j.contains("base_url")) config.baseUrl = j["base_url"].get<std::string>();
        if (j.contains("log_format")) config.logFormat = j["log_format"].get<std::string>();
    } catch (const std::exception& e) {
        std::cerr << "WARNING: failed to parse " << path << ": " << e.what()
                  << " — using default settings" << std::endl;
    }
}

struct Song {
    std::string id;
    std::string title;
    std::string artist;
    std::string filepath;
};

std::deque<Song> playlist;
std::deque<Song> history;
std::vector<Song> songs;
std::mutex playlistMutex;  // guards playlist (requests run on a thread pool)

Metrics metrics;

// Per-request state for the access log. httplib handles one request per
// thread at a time, so thread_local is safe between the pre-routing hook and
// the logger callback.
thread_local std::chrono::steady_clock::time_point requestStart;
thread_local std::string currentRequestId;
std::atomic<uint64_t> requestCounter{0};

// Structured log line. In "json" mode: one JSON object per line on stdout.
// In "text" mode: a plain line, same style as the original server.
void logEvent(const std::string& level, const std::string& message,
              json fields = json::object()) {
    if (config.logFormat == "json") {
        auto now = std::chrono::system_clock::now();
        auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(
                      now.time_since_epoch()).count();
        fields["ts_ms"] = ms;
        fields["level"] = level;
        fields["msg"] = message;
        fields["service"] = "music-player";
        std::cout << fields.dump() << std::endl;
    } else {
        std::ostream& out = (level == "error" || level == "warn") ? std::cerr : std::cout;
        out << message << std::endl;
    }
}


// Function to scan songs directory
void scanSongsDirectory(const std::string& dirPath) {
    songs.clear();
    int id = 1;

    try {
        for (const auto& entry : fs::directory_iterator(dirPath)) {
            if (entry.is_regular_file()) {
                std::string extension = entry.path().extension().string();
                if (isSupportedAudioExtension(extension)) {
                    Song song;
                    song.id = std::to_string(id++);
                    song.title = getTitleFromFilename(entry.path().filename().string());
                    song.artist = "Unknown Artist";
                    song.filepath = entry.path().string();
                    songs.push_back(song);
                }
            }
        }
    } catch (const fs::filesystem_error& e) {
        logEvent("error", std::string("Error scanning directory: ") + e.what(),
                 {{"dir", dirPath}});
    }
}


void addToPlaylist(const Song& song) {
    playlist.push_back(song);
    while (playlist.size() > config.maxQueueSize) playlist.pop_front();
}

Song getNextSong() {
    if (playlist.empty()) {
        throw std::runtime_error("Playlist is empty");
    }
    Song nextSong = playlist.front();
    playlist.pop_front();
    return nextSong;
}

void addToHistory(const Song& song) {
    history.push_back(song);
    while (history.size() > config.maxHistorySize) history.pop_front();
}

Song getPreviousSong() {
    if (history.empty()) {
        throw std::runtime_error("No previous songs");
    }
    Song prevSong = history.back();
    history.pop_back();
    return prevSong;
}


int main() {
    loadConfig("config.json");

    httplib::Server svr;

    // Scan the songs directory at startup
    scanSongsDirectory(config.musicDirectory);

    // Serve the frontend (index.html, style.css, app.js) from ./public
    if (!svr.set_mount_point("/", "./public")) {
        std::cerr << "ERROR: could not find ./public directory to serve the frontend from" << std::endl;
        return 1;
    }

    svr.set_read_timeout(config.readTimeout);
    svr.set_write_timeout(config.writeTimeout);
    svr.set_keep_alive_max_count(config.keepAliveMaxCount);

    // Add CORS headers to all responses
    svr.set_default_headers({
        {"Access-Control-Allow-Origin", "*"},
        {"Access-Control-Allow-Methods", "GET, POST, OPTIONS"},
        {"Access-Control-Allow-Headers", "*"}
    });

    // Observability: time every request and assign it an id (reuses a
    // caller-supplied X-Request-ID so traces can be correlated across hops).
    svr.set_pre_routing_handler([](const httplib::Request& req, httplib::Response& res) {
        requestStart = std::chrono::steady_clock::now();
        currentRequestId = req.has_header("X-Request-ID")
            ? req.get_header_value("X-Request-ID")
            : std::to_string(++requestCounter);
        res.set_header("X-Request-ID", currentRequestId);
        return httplib::Server::HandlerResponse::Unhandled;
    });

    // Runs after each response: record metrics and emit the access log line.
    svr.set_logger([](const httplib::Request& req, const httplib::Response& res) {
        double seconds = std::chrono::duration<double>(
            std::chrono::steady_clock::now() - requestStart).count();
        std::string route = normalizeRoute(req.path);
        metrics.observeRequest(req.method, route, res.status, seconds);
        if (config.logFormat == "json") {
            logEvent(res.status >= 500 ? "error" : "info", "request",
                     {{"request_id", currentRequestId},
                      {"method", req.method},
                      {"path", req.path},
                      {"route", route},
                      {"status", res.status},
                      {"duration_ms", seconds * 1000.0}});
        }
    });

    // Liveness: the process is up and serving HTTP.
    svr.Get("/healthz", [](const httplib::Request&, httplib::Response& res) {
        json body = {{"status", "ok"}, {"songs", songs.size()}};
        res.set_content(body.dump(), "application/json");
    });

    // Readiness: only report ready when there is something to play. Lets an
    // orchestrator (Kubernetes) keep traffic away from an instance whose
    // music library is missing or empty.
    svr.Get("/readyz", [](const httplib::Request&, httplib::Response& res) {
        if (songs.empty()) {
            res.status = 503;
            res.set_content(R"({"status":"not ready","reason":"no songs in library"})", "application/json");
            return;
        }
        res.set_content(R"({"status":"ready"})", "application/json");
    });

    // Prometheus scrape endpoint.
    svr.Get("/metrics", [](const httplib::Request&, httplib::Response& res) {
        size_t queueLen;
        {
            std::lock_guard<std::mutex> lock(playlistMutex);
            queueLen = playlist.size();
        }
        res.set_content(metrics.render(songs.size(), queueLen),
                        "text/plain; version=0.0.4; charset=utf-8");
    });

    // Handle OPTIONS requests for CORS
    svr.Options("/(.*)", [](const httplib::Request&, httplib::Response& res) {
        res.status = 204;  // No content
    });

    // Runtime config for the frontend. base_url (config.json) is only needed
    // when the frontend is served from a different origin than this backend
    // (e.g. frontend on a CDN, backend as a separate API server); left empty
    // it stays empty and the frontend just uses relative URLs (today's setup).
    svr.Get("/config.js", [](const httplib::Request&, httplib::Response& res) {
        json frontendConfig;
        frontendConfig["baseUrl"] = config.baseUrl;
        res.set_content("window.APP_CONFIG = " + frontendConfig.dump() + ";", "application/javascript");
    });

    // Get all songs
    svr.Get("/api/songs", [](const httplib::Request&, httplib::Response& res) {
        json response;
        json songList = json::array();
        
        for (const auto& song : songs) {
            json songObj;
            songObj["id"] = song.id;
            songObj["title"] = song.title;
            songObj["artist"] = song.artist;
            songList.push_back(songObj);
        }
        
        response["songs"] = songList;
        res.set_content(response.dump(), "application/json");
    });


    // Add song to playlist
    svr.Post("/api/playlist/add", [](const httplib::Request& req, httplib::Response& res) {
        // Malformed bodies used to throw out of the handler; answer 400 instead.
        std::string songId;
        try {
            auto body = json::parse(req.body);
            songId = body.at("id").get<std::string>();
        } catch (const std::exception&) {
            res.status = 400;
            res.set_content("Invalid request body: expected {\"id\": \"<song id>\"}", "text/plain");
            return;
        }
        auto it = std::find_if(songs.begin(), songs.end(),
            [&songId](const Song& song) { return song.id == songId; });
        if (it != songs.end()) {
            std::lock_guard<std::mutex> lock(playlistMutex);
            addToPlaylist(*it);
            res.set_content("Song added to playlist", "text/plain");
        } else {
            res.status = 404;
            res.set_content("Song not found", "text/plain");
        }
    });

    // Get next song (from playlist if available, otherwise from general list)
    svr.Get("/api/songs/next", [](const httplib::Request&, httplib::Response& res) {
        Song nextSong;
        std::lock_guard<std::mutex> lock(playlistMutex);
        if (!playlist.empty()) {
            nextSong = playlist.front();
            playlist.pop_front();
        } else if (!songs.empty()) {
            static size_t currentIndex = 0;
            nextSong = songs[currentIndex];
            currentIndex = (currentIndex + 1) % songs.size();
        } else {
            res.status = 404;
            res.set_content("No songs available", "text/plain");
            return;
        }
        json response = {
            {"id", nextSong.id},
            {"title", nextSong.title},
            {"artist", nextSong.artist}
        };
        res.set_content(response.dump(), "application/json");
    });

    // Get previous song
    svr.Get("/api/songs/previous", [](const httplib::Request&, httplib::Response& res) {
        if (history.empty()) {
            res.status = 404;
            res.set_content("No previous songs", "text/plain");
            return;
        }
        Song prevSong = history.back();
        history.pop_back();
        json response = {
            {"id", prevSong.id},
            {"title", prevSong.title},
            {"artist", prevSong.artist}
        };
        res.set_content(response.dump(), "application/json");
    });

    // Play song (streams via httplib's own range-request handling)
    svr.Get(R"(/api/songs/(\d+)/play)", [](const httplib::Request& req, httplib::Response& res) {
        std::string id = req.matches[1].str();
        auto it = std::find_if(songs.begin(), songs.end(),
            [&id](const Song& song) { return song.id == id; });

        if (it == songs.end()) {
            logEvent("warn", "Song not found: " + id, {{"song_id", id}});
            res.status = 404;
            return;
        }

        std::error_code ec;
        auto fileSize = fs::file_size(it->filepath, ec);
        if (ec) {
            logEvent("error", "Cannot open file: " + it->filepath, {{"song_id", id}});
            res.status = 404;
            return;
        }

        metrics.incStreams();
        logEvent("info", "Streaming song: " + it->title + " (ID: " + id + ", " +
                             std::to_string(fileSize) + " bytes)",
                 {{"song_id", id}, {"bytes", fileSize}});

        res.set_header("Accept-Ranges", "bytes");
        res.set_header("Cache-Control", "public, max-age=3600");
        res.set_header("Connection", "keep-alive");

        // Let httplib parse the Range header and drive this provider with the
        // exact (offset, length) it needs — it also sets the matching status
        // (200/206) and Content-Range/Content-Length headers itself. Handling
        // ranges manually here caused httplib's own range validation to run a
        // second time against an already-sliced body and reject most seeks
        // with a spurious 416 (this only "worked" for full-file, open-ended
        // requests, which is why Chrome played fine but Safari, which makes
        // precise bounded range requests, didn't).
        std::string filepath = it->filepath;
        res.set_content_provider(
            fileSize, "audio/mpeg",
            [filepath](size_t offset, size_t length, httplib::DataSink& sink) {
                std::ifstream file(filepath, std::ios::binary);
                if (!file) return false;

                file.seekg(static_cast<std::streamoff>(offset));
                std::vector<char> buffer(length);
                file.read(buffer.data(), static_cast<std::streamsize>(length));
                if (file.bad()) return false;

                return sink.write(buffer.data(), static_cast<size_t>(file.gcount()));
            });
    });

    logEvent("info", "Server starting on " + config.host + ":" + std::to_string(config.port) + "...",
             {{"library_size", songs.size()}});
    svr.listen(config.host, config.port);

    return 0;
}