#include "httplib.h"
#include "json.hpp"
#include <filesystem>
#include <vector>
#include <string>
#include <fstream>
#include <algorithm>
#include <deque>
#include <stack>

using json = nlohmann::json;
namespace fs = std::filesystem;

struct Song {
    std::string id;
    std::string title;
    std::string artist;
    std::string filepath;
};

std::deque<Song> playlist;
std::stack<Song> history;
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
    history.push(song);
}

Song getPreviousSong() {
    if (history.empty()) {
        throw std::runtime_error("No previous songs");
    }
    Song prevSong = history.top();
    history.pop();
    return prevSong;
}


int main() {
    httplib::Server svr;

    // Scan the songs directory at startup
    scanSongsDirectory("songs");

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
            playlist.push_back(*it);
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
        Song prevSong = history.top();
        history.pop();
        json response = {
            {"id", prevSong.id},
            {"title", prevSong.title},
            {"artist", prevSong.artist}
        };
        res.set_content(response.dump(), "application/json");
    });

    // Play song (streaming)
    svr.Get(R"(/api/songs/(\d+)/play)", [](const httplib::Request& req, httplib::Response& res) {
        std::string id = req.matches[1].str();
        auto it = std::find_if(songs.begin(), songs.end(),
            [&id](const Song& song) { return song.id == id; });
            
        if (it == songs.end()) {
            res.status = 404;
            return;
        }
            
        std::ifstream file(it->filepath, std::ios::binary);
        if (!file) {
            res.status = 404;
            return;
        }

        // Get file size
        file.seekg(0, std::ios::end);
        size_t fileSize = file.tellg();
        file.seekg(0, std::ios::beg);

        // Handle range request if present
        if (req.has_header("Range")) {
            std::string range = req.get_header_value("Range");
            size_t start = 0, end = fileSize - 1;
            
            sscanf(range.c_str(), "bytes=%zu-%zu", &start, &end);
            
            if (end >= fileSize) end = fileSize - 1;
            size_t contentLength = end - start + 1;

            file.seekg(start);
            std::vector<char> buffer(contentLength);
            file.read(buffer.data(), contentLength);

            res.set_header("Content-Range", "bytes " + std::to_string(start) + "-" + 
                          std::to_string(end) + "/" + std::to_string(fileSize));
            res.set_header("Accept-Ranges", "bytes");
            res.set_header("Content-Length", std::to_string(contentLength));
            res.set_header("Content-Type", "audio/mpeg");
            res.status = 206;
            res.body.assign(buffer.data(), contentLength);
        } else {
            // Send entire file
            std::vector<char> buffer(fileSize);
            file.read(buffer.data(), fileSize);
            
            res.set_header("Content-Length", std::to_string(fileSize));
            res.set_header("Content-Type", "audio/mpeg");
            res.body.assign(buffer.data(), fileSize);
        }
    });

    // Serve the index.html file at root
    svr.Get("/", [](const httplib::Request&, httplib::Response& res) {
        std::ifstream file("index.html");
        if (!file) {
            res.status = 404;
            res.set_content("index.html not found", "text/plain");
            return;
        }
        std::string content((std::istreambuf_iterator<char>(file)),
                           std::istreambuf_iterator<char>());
        res.set_content(content, "text/html");
    });

    std::cout << "Server starting on port 3000..." << std::endl;
    svr.listen("0.0.0.0", 3000);
    
    return 0;
}