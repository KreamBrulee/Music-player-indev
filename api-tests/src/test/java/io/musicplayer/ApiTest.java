package io.musicplayer;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

import org.junit.jupiter.api.Test;

// Black-box tests against a running music-player instance. The base URL comes
// from the api.baseUrl system property (the pipeline points it at the smoke
// container); defaults to localhost:3000 for running by hand.
class ApiTest {

    private static final String BASE =
        System.getProperty("api.baseUrl", "http://localhost:3000");

    private static final HttpClient CLIENT = HttpClient.newBuilder()
        .connectTimeout(Duration.ofSeconds(5))
        .build();

    private HttpResponse<String> get(String path) throws Exception {
        HttpRequest req = HttpRequest.newBuilder()
            .uri(URI.create(BASE + path))
            .timeout(Duration.ofSeconds(10))
            .GET()
            .build();
        return CLIENT.send(req, HttpResponse.BodyHandlers.ofString());
    }

    @Test
    void songsEndpointReturnsJson() throws Exception {
        HttpResponse<String> res = get("/api/songs");
        assertEquals(200, res.statusCode(), "/api/songs should return 200");
        assertTrue(res.body().contains("\"songs\""),
            "response should contain a 'songs' array, got: " + res.body());
    }

    @Test
    void frontendIsServed() throws Exception {
        HttpResponse<String> res = get("/");
        assertEquals(200, res.statusCode(), "/ should return 200");
        assertTrue(res.body().contains("NOVA"),
            "frontend HTML should contain the app title");
    }

    @Test
    void staticAssetsAreServed() throws Exception {
        assertEquals(200, get("/app.js").statusCode(), "/app.js should return 200");
        assertEquals(200, get("/style.css").statusCode(), "/style.css should return 200");
    }
}
