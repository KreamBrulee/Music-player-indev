# Potassium Music Player

A self-hosted music player. A small C++ server streams your local music
library (mp3, wav, ogg) over HTTP and serves a web UI to browse and play it.
No external services or accounts required — point it at a folder of songs and
run it.

Runs on macOS and Linux.

## Requirements

- CMake 3.15+
- A C++17 compiler (Xcode Command Line Tools on macOS, `build-essential` on
  Linux — `deploy.sh` installs these for you if they're missing)

## Quick Start

1. Put your music files in `songs/` (`.mp3`, `.wav`, `.ogg`).
2. Build and run:

   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

3. Open `http://localhost:3000` in a browser.

`deploy.sh` detects your OS, installs any missing build tools (Homebrew +
CMake on macOS, apt + build-essential on Linux), builds the project with
CMake, and starts the server in the foreground. Press Ctrl+C to stop it.

## Running in the Background

To keep the server running after you close the terminal, without installing
it as a system service:

```bash
nohup ./build/music_player > music_player.log 2>&1 &
```

Check it's running with `ps aux | grep music_player`, and stop it with
`pkill music_player`.

### Linux: systemd service

On Linux you can instead install the server as a systemd service, which adds
auto-restart on crash and auto-start on boot:

```bash
chmod +x deploy_systemd.sh
sudo ./deploy_systemd.sh
```

Manage it with `sudo systemctl {start|stop|restart|status} music-player` and
view logs with `sudo journalctl -u music-player -f`.

There's no equivalent script for macOS — use the `nohup` approach above, or
manage the process however you'd normally run a background tool on your
machine.

## Docker

Build and run the server in a container — no local compiler or CMake needed
on the host, just Docker.

```bash
docker compose up -d --build
```

Open `http://localhost:3000` in a browser.

This uses `Dockerfile` (multi-stage: compiles `music_player` in a build
image, ships only the binary + `public/` + `config.json` in a slim,
non-root runtime image) and `docker-compose.yml`. The real `songs/` mp3s
are never baked into the image — see `.dockerignore`.

### Pointing it at your music library

`docker-compose.yml` bind-mounts a `songs/` folder by default:

```yaml
volumes:
  - ./songs:/app/songs
```

Change the host side (left of the `:`) to your real music folder, e.g.
`/Users/you/Music:/app/songs`, then `docker compose up -d`. No rebuild
needed for a volume path change.

### Editing config.json without rebuilding

`config.json` is baked into the image at build time. To change settings
without rebuilding, uncomment the `config.json` line under `volumes:` in
`docker-compose.yml`, edit the file on the host, then
`docker compose restart`.

### Permissions

The container runs as a fixed non-root user (uid 1000). It only ever reads
`songs/`, never writes to it, so normal file permissions on your music
folder (readable by anyone, the default on most systems) are enough. If you
get permission errors, `chmod -R a+rX /path/to/your/music` on the host.

### Without Docker Compose

```bash
docker build -t music-player .
docker run -d --name music-player -p 3000:3000 \
  -v /path/to/your/music:/app/songs music-player
```

## Configuration

All settings live in [config.json](config.json) (edit it directly — it's
committed with sensible defaults, no secrets in it). It's read at startup; a
missing or invalid file just logs a warning and falls back to defaults, it
won't stop the server from starting.

| Key                    | Default     | What it does                                                             |
|-------------------------|-------------|---------------------------------------------------------------------------|
| `host`                  | `0.0.0.0`   | Bind address. Keep this as `0.0.0.0` to stay reachable from other devices/containers — `localhost` would restrict it to the machine it's running on. |
| `port`                  | `3000`      | Port to listen on.                                                       |
| `music_directory`       | `songs`     | Folder scanned for `.mp3`/`.wav`/`.ogg` files.                          |
| `max_queue_size`        | `50`        | Cap on the server-side play queue (`/api/playlist/add`).                |
| `max_history_size`      | `10`        | Cap on the server-side play history (`/api/songs/previous`).            |
| `read_timeout` / `write_timeout` | `15` (seconds) | HTTP socket timeouts.                                          |
| `keep_alive_max_count`  | `20`        | Max requests per keep-alive connection.                                 |
| `base_url`              | `""`        | Only needed if the frontend is ever served from a different origin than this backend (e.g. frontend on a CDN, backend as a separate API server on the cloud). Leave empty for the normal setup, where this server serves both the frontend and the API together. |

## Project Structure

```
music-player/
├── deploy.sh          build and run (macOS/Linux)
├── deploy_systemd.sh  install as a systemd service (Linux only)
├── Dockerfile          multi-stage container build
├── docker-compose.yml  container build + run, with songs/ mounted
├── CMakeLists.txt     build configuration
├── config.json         server settings (see Configuration below)
├── src/main.cpp       the server
├── include/           vendored headers (cpp-httplib, nlohmann/json)
├── public/            the web UI (index.html, style.css, app.js)
└── songs/             your music library
```

## API

The server exposes a small JSON API alongside the web UI, all on the
configured port (3000 by default):

| Method | Path                    | Description                                  |
|--------|-------------------------|-----------------------------------------------|
| GET    | `/api/songs`             | List all songs                               |
| GET    | `/api/songs/{id}/play`   | Stream a song (supports HTTP range requests) |
| GET    | `/api/songs/next`        | Advance to the next song                     |
| GET    | `/api/songs/previous`    | Go back to the previous song                 |
| POST   | `/api/playlist/add`      | Add a song to the play queue (`{"id": "..."}`) |

## Troubleshooting

See [QUICK_DEPLOY.md](QUICK_DEPLOY.md) for a more detailed deployment guide
and troubleshooting steps (build failures, port conflicts, firewall issues).

Note: `setup.sh` is an old script that starts a separate Python server for
the frontend. It's no longer needed — the C++ server serves the frontend
directly — and shouldn't be used.
