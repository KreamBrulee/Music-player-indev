// Dependency-free unit tests (no framework to vendor). Run via `ctest`.
#include "../src/metrics.hpp"
#include "../src/utils.hpp"

#include <cstdlib>
#include <iostream>

static int failures = 0;

#define CHECK(cond)                                                          \
    do {                                                                     \
        if (!(cond)) {                                                       \
            std::cerr << "FAIL " << __FILE__ << ":" << __LINE__ << "  "      \
                      << #cond << std::endl;                                 \
            ++failures;                                                      \
        }                                                                    \
    } while (0)

static bool contains(const std::string& hay, const std::string& needle) {
    return hay.find(needle) != std::string::npos;
}

int main() {
    // getTitleFromFilename
    CHECK(getTitleFromFilename("My_Song.mp3") == "My Song");
    CHECK(getTitleFromFilename("no_extension") == "no extension");
    CHECK(getTitleFromFilename("a.b.c.ogg") == "a.b.c");
    CHECK(getTitleFromFilename("") == "");

    // isSupportedAudioExtension
    CHECK(isSupportedAudioExtension(".mp3"));
    CHECK(isSupportedAudioExtension(".wav"));
    CHECK(isSupportedAudioExtension(".ogg"));
    CHECK(!isSupportedAudioExtension(".txt"));
    CHECK(!isSupportedAudioExtension("mp3"));

    // normalizeRoute keeps metric label cardinality bounded
    CHECK(normalizeRoute("/api/songs") == "/api/songs");
    CHECK(normalizeRoute("/api/songs/42/play") == "/api/songs/{id}/play");
    CHECK(normalizeRoute("/api/songs/9999/play") == "/api/songs/{id}/play");
    CHECK(normalizeRoute("/api/songs/next") == "/api/songs/next");
    CHECK(normalizeRoute("/api/nope") == "/api/other");
    CHECK(normalizeRoute("/index.html") == "static");
    CHECK(normalizeRoute("/") == "static");

    // Metrics exposition
    Metrics m;
    m.observeRequest("GET", "/api/songs", 200, 0.004);
    m.observeRequest("GET", "/api/songs", 200, 0.2);
    m.observeRequest("GET", "/api/songs", 500, 0.02);
    m.incStreams();
    std::string out = m.render(7, 3);
    CHECK(contains(out, "http_requests_total{method=\"GET\",route=\"/api/songs\",status=\"200\"} 2"));
    CHECK(contains(out, "http_requests_total{method=\"GET\",route=\"/api/songs\",status=\"500\"} 1"));
    CHECK(contains(out, "http_request_duration_seconds_count{route=\"/api/songs\"} 3"));
    CHECK(contains(out, "http_request_duration_seconds_bucket{route=\"/api/songs\",le=\"0.005\"} 1"));
    CHECK(contains(out, "http_request_duration_seconds_bucket{route=\"/api/songs\",le=\"+Inf\"} 3"));
    CHECK(contains(out, "songs_streamed_total 1"));
    CHECK(contains(out, "songs_library_size 7"));
    CHECK(contains(out, "playlist_queue_length 3"));

    if (failures) {
        std::cerr << failures << " check(s) failed" << std::endl;
        return EXIT_FAILURE;
    }
    std::cout << "all unit tests passed" << std::endl;
    return EXIT_SUCCESS;
}
