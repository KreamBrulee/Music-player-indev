#include "httplib.h"
#include "json.hpp"
#include <filesystem>
#include <vector>
#include <string>
#include <fstream>
#include <algorithm>
#include <deque>

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

// Function to extract title from filename
std::string getTitleFromFilename(const std::string& filename) {
    size_t lastDot = filename.find_last_of('.');
    std::string title = (lastDot != std::string::npos) ? filename.substr(0, lastDot) : filename;
    std::replace(title.begin(), title.end(), '_', ' ');
    return title;
}


// Function to scan songs directory
void scanSongsDirectory(const std::string& dirPath) {
    songs.clear();
    int id = 1;

    try {
        for (const auto& entry : fs::directory_iterator(dirPath)) {
            if (entry.is_regular_file()) {
                std::string extension = entry.path().extension().string();
                if (extension == ".mp3" || extension == ".wav" || extension == ".ogg") {
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
        std::cerr << "Error scanning directory: " << e.what() << std::endl;
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
        auto json = json::parse(req.body);
        std::string songId = json["id"];
        auto it = std::find_if(songs.begin(), songs.end(),
            [&songId](const Song& song) { return song.id == songId; });
        if (it != songs.end()) {
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
            std::cerr << "Song not found: " << id << std::endl;
            res.status = 404;
            return;
        }

        std::error_code ec;
        auto fileSize = fs::file_size(it->filepath, ec);
        if (ec) {
            std::cerr << "Cannot open file: " << it->filepath << std::endl;
            res.status = 404;
            return;
        }

        std::cout << "Streaming song: " << it->title << " (ID: " << id
                  << ", " << fileSize << " bytes)" << std::endl;

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

    std::cout << "Server starting on " << config.host << ":" << config.port << "..." << std::endl;
    svr.listen(config.host, config.port);

    return 0;
}