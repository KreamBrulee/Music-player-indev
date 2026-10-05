package io.musicplayer;

import static org.junit.jupiter.api.Assertions.*;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

/** Black-box tests against a running music-player server (see pom.xml). */
class ApiTest {
    private static final String BASE = System.getProperty("api.baseUrl", "http://localhost:3000");
    private static final HttpClient HTTP =
            HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(2)).build();

    private static HttpResponse<String> send(HttpRequest.Builder b) throws Exception {
        return HTTP.send(b.timeout(Duration.ofSeconds(5)).build(), HttpResponse.BodyHandlers.ofString());
    }

    private static HttpRequest.Builder get(String path) {
        return HttpRequest.newBuilder(URI.create(BASE + path)).GET();
    }

    @BeforeAll
    static void serverIsUp() {
        try {
            assumeTrue(send(get("/healthz")).statusCode() == 200, "server not healthy at " + BASE);
        } catch (Exception e) {
            assumeTrue(false, "server not reachable at " + BASE + ": " + e);
        }
    }

    @Test
    void healthzReportsOk() throws Exception {
        var r = send(get("/healthz"));
        assertEquals(200, r.statusCode());
        assertTrue(r.body().contains("\"status\":\"ok\""));
    }

    @Test
    void songsEndpointReturnsJsonList() throws Exception {
        var r = send(get("/api/songs"));
        assertEquals(200, r.statusCode());
        assertTrue(r.headers().firstValue("Content-Type").orElse("").contains("application/json"));
        assertTrue(r.body().contains("\"songs\""));
    }

    @Test
    void unknownSongIs404() throws Exception {
        assertEquals(404, send(get("/api/songs/99999/play")).statusCode());
    }

    @Test
    void malformedPlaylistBodyIs400AndServerSurvives() throws Exception {
        var bad = send(HttpRequest.newBuilder(URI.create(BASE + "/api/playlist/add"))
                .POST(HttpRequest.BodyPublishers.ofString("not json")));
        assertEquals(400, bad.statusCode());
        assertEquals(200, send(get("/healthz")).statusCode());
    }

    @Test
    void metricsExposePrometheusFormat() throws Exception {
        send(get("/api/songs")); // make sure at least one request is counted
        var r = send(get("/metrics"));
        assertEquals(200, r.statusCode());
        assertTrue(r.body().contains("# TYPE http_requests_total counter"));
        assertTrue(r.body().contains("http_request_duration_seconds_bucket"));
        assertTrue(r.body().contains("songs_library_size"));
    }

    @Test
    void everyResponseCarriesARequestId() throws Exception {
        assertTrue(send(get("/healthz")).headers().firstValue("X-Request-ID").isPresent());
    }
}
