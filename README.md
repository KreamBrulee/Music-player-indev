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

## Project Structure

```
music-player/
├── deploy.sh          build and run (macOS/Linux)
├── deploy_systemd.sh  install as a systemd service (Linux only)
├── CMakeLists.txt     build configuration
├── src/main.cpp       the server
├── include/           vendored headers (cpp-httplib, nlohmann/json)
├── index.html         the web UI
└── songs/             your music library
```

## API

The server exposes a small JSON API alongside the web UI, all on port 3000:

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
