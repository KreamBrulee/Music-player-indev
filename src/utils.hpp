// Small, dependency-free helpers. Kept in a header (rather than main.cpp) so
// they can be unit-tested without starting the HTTP server — see tests/.
#pragma once

#include <algorithm>
#include <string>

// "My_Song.mp3" -> "My Song"
inline std::string getTitleFromFilename(const std::string& filename) {
    size_t lastDot = filename.find_last_of('.');
    std::string title = (lastDot != std::string::npos) ? filename.substr(0, lastDot) : filename;
    std::replace(title.begin(), title.end(), '_', ' ');
    return title;
}

// True for the audio formats the library scanner accepts (case-sensitive,
// matching the scanner's existing behaviour).
inline bool isSupportedAudioExtension(const std::string& ext) {
    return ext == ".mp3" || ext == ".wav" || ext == ".ogg";
}

// Collapses a raw request path into a small, fixed set of route labels so
// metrics don't get one time series per song id (label-cardinality explosion).
inline std::string normalizeRoute(const std::string& path) {
    static const char* const kExact[] = {
        "/api/songs", "/api/songs/next", "/api/songs/previous",
        "/api/playlist/add", "/metrics", "/healthz", "/readyz", "/config.js"};
    for (const char* r : kExact) {
        if (path == r) return path;
    }
    const std::string prefix = "/api/songs/";
    const std::string suffix = "/play";
    if (path.size() > prefix.size() + suffix.size() &&
        path.compare(0, prefix.size(), prefix) == 0 &&
        path.compare(path.size() - suffix.size(), suffix.size(), suffix) == 0) {
        return "/api/songs/{id}/play";
    }
    if (path.compare(0, 5, "/api/") == 0) return "/api/other";
    return "static";
}
