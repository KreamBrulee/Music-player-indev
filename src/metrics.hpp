// Minimal Prometheus-compatible metrics registry (text exposition format
// 0.0.4). Hand-rolled on purpose: the project has no package manager and
// vendors its dependencies, so pulling in prometheus-cpp would be heavy.
#pragma once

#include <array>
#include <atomic>
#include <cstdint>
#include <map>
#include <mutex>
#include <sstream>
#include <string>
#include <tuple>

class Metrics {
public:
    static constexpr std::array<double, 11> kBuckets = {
        0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0};

    void observeRequest(const std::string& method, const std::string& route,
                        int status, double seconds) {
        std::lock_guard<std::mutex> lock(mu_);
        ++requests_[std::make_tuple(method, route, status)];
        Histogram& h = latency_[route];
        for (size_t i = 0; i < kBuckets.size(); ++i) {
            if (seconds <= kBuckets[i]) ++h.buckets[i];
        }
        ++h.count;
        h.sum += seconds;
    }

    void incStreams() { ++streams_; }

    // libraryTracks / queueLength are sampled by the caller at scrape time.
    std::string render(size_t libraryTracks, size_t queueLength) const {
        std::ostringstream out;
        std::lock_guard<std::mutex> lock(mu_);

        out << "# HELP http_requests_total Total HTTP requests handled.\n"
            << "# TYPE http_requests_total counter\n";
        for (const auto& kv : requests_) {
            out << "http_requests_total{method=\"" << std::get<0>(kv.first)
                << "\",route=\"" << std::get<1>(kv.first) << "\",status=\""
                << std::get<2>(kv.first) << "\"} " << kv.second << "\n";
        }

        out << "# HELP http_request_duration_seconds HTTP request latency.\n"
            << "# TYPE http_request_duration_seconds histogram\n";
        for (const auto& kv : latency_) {
            const std::string& route = kv.first;
            const Histogram& h = kv.second;
            for (size_t i = 0; i < kBuckets.size(); ++i) {
                out << "http_request_duration_seconds_bucket{route=\"" << route
                    << "\",le=\"" << kBuckets[i] << "\"} " << h.buckets[i] << "\n";
            }
            out << "http_request_duration_seconds_bucket{route=\"" << route
                << "\",le=\"+Inf\"} " << h.count << "\n"
                << "http_request_duration_seconds_sum{route=\"" << route << "\"} "
                << h.sum << "\n"
                << "http_request_duration_seconds_count{route=\"" << route << "\"} "
                << h.count << "\n";
        }

        out << "# HELP songs_streamed_total Songs whose stream was started.\n"
            << "# TYPE songs_streamed_total counter\n"
            << "songs_streamed_total " << streams_.load() << "\n"
            << "# HELP songs_library_size Tracks found in the music directory.\n"
            << "# TYPE songs_library_size gauge\n"
            << "songs_library_size " << libraryTracks << "\n"
            << "# HELP playlist_queue_length Songs waiting in the play queue.\n"
            << "# TYPE playlist_queue_length gauge\n"
            << "playlist_queue_length " << queueLength << "\n";
        return out.str();
    }

private:
    struct Histogram {
        std::array<uint64_t, kBuckets.size()> buckets{};
        uint64_t count = 0;
        double sum = 0.0;
    };

    mutable std::mutex mu_;
    std::map<std::tuple<std::string, std::string, int>, uint64_t> requests_;
    std::map<std::string, Histogram> latency_;
    std::atomic<uint64_t> streams_{0};
};
