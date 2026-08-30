# Quick Deployment Guide

Works on macOS and Linux. `deploy.sh` detects your OS and installs what it
needs (Homebrew + CMake on macOS, apt + build-essential on Linux).

## Quick Start

Build and run in the foreground (good for testing):

```bash
chmod +x deploy.sh
./deploy.sh
# Press Ctrl+C to stop
```

## Deployment Options

### Option 1: Direct Run

Simple, shows output directly, stops when the terminal closes or you press
Ctrl+C. Good for testing, not for leaving the server running long-term.

```bash
chmod +x deploy.sh
./deploy.sh
```

### Option 2: Background with nohup

Runs in the background and survives closing the terminal. No auto-restart on
crash — you restart it manually if it dies. Works the same on macOS and
Linux.

```bash
# Build first
chmod +x deploy.sh
./deploy.sh
# Press Ctrl+C once it starts

# Then run in the background
nohup ./build/music_player > music_player.log 2>&1 &

# Check if it's running
ps aux | grep music_player

# Stop it
pkill music_player

# View logs
tail -f music_player.log
```

### Option 3: systemd Service (Linux only)

Runs in the background, auto-starts on boot, and auto-restarts if it
crashes. There's no macOS equivalent set up in this repo — use the nohup
approach above on macOS instead.

```bash
# Step 1: Build the project
chmod +x deploy.sh
./deploy.sh
# Press Ctrl+C after it starts

# Step 2: Install the systemd service
chmod +x deploy_systemd.sh
sudo ./deploy_systemd.sh
```

**Management commands:**

```bash
# Check if running
sudo systemctl status music-player

# View logs (live)
sudo journalctl -u music-player -f

# View recent logs
sudo journalctl -u music-player -n 100

# Restart (after code changes)
sudo systemctl restart music-player

# Stop / start
sudo systemctl stop music-player
sudo systemctl start music-player

# Disable auto-start
sudo systemctl disable music-player
```

### Option 4: Docker

Runs in a container — no local compiler/CMake install needed at all.

```bash
docker compose up -d --build
```

Point it at your real music library by editing the volume line in
`docker-compose.yml` (`./songs:/app/songs` → `/path/to/your/music:/app/songs`)
before running. See the [Docker section](README.md#docker) in the README
for permissions notes, editing `config.json` without rebuilding, and plain
`docker run` usage.

```bash
docker compose logs -f     # logs
docker compose down        # stop
```

## What About setup.sh?

The old `setup.sh` script starts two servers — a Python HTTP server for the
frontend on port 8000, plus the C++ backend. It's no longer needed: the C++
server now serves the frontend (`public/index.html`) directly. Don't use it
for deployment.

## After Code Changes

**If using systemd (Linux):**

```bash
cd /path/to/music-player
mkdir -p build && cd build
cmake ..
make -j$(nproc)
cd ..

sudo systemctl restart music-player
sudo systemctl status music-player
```

**If running manually (macOS or Linux):**

```bash
pkill music_player
./deploy.sh
```

## File Checklist Before Deployment

```
music-player/
├── deploy.sh              build and run script (macOS/Linux)
├── deploy_systemd.sh      systemd install script (Linux only)
├── Dockerfile              multi-stage container build
├── docker-compose.yml      container build + run, with songs/ mounted
├── setup.sh                old script, do not use
├── public/                 the web UI (index.html, style.css, app.js)
├── CMakeLists.txt          build configuration
├── build/                  created by deploy.sh
│   └── music_player        created after building
├── src/
│   └── main.cpp             server source
├── songs/                  must contain your music files
└── include/                 vendored headers
```

## Troubleshooting

### Build fails

```bash
# Check if CMakeLists.txt exists
ls -la CMakeLists.txt

# Check for a compiler
c++ --version

# Install dependencies
# macOS:
brew install cmake
xcode-select --install   # provides clang/make

# Linux:
sudo apt update
sudo apt install build-essential cmake g++
```

### Server won't start

```bash
# Check logs (systemd, Linux)
sudo journalctl -u music-player -n 50

# Check if the port is already in use (macOS and Linux)
lsof -i :3000

# Kill any existing process
pkill music_player
```

### No songs showing

```bash
# Check the songs directory
ls -la songs/

# Check permissions
chmod +r songs/*.mp3
```

### Can't access from a browser

```bash
# Check the server is running and listening
lsof -i :3000

# Check the firewall
# Linux (ufw):
sudo ufw status
sudo ufw allow 3000/tcp
# macOS (Application Firewall, only relevant if it's enabled):
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Test locally
curl http://localhost:3000/api/songs
```

## Port Information

- **Port 3000** — the C++ server, serving both the API and the frontend:
  - Frontend: `http://your-server:3000/`
  - API: `http://your-server:3000/api/songs`
  - Streaming: `http://your-server:3000/api/songs/{id}/play`
- **Port 8000** — used only by the old `setup.sh`; not used otherwise.

## Summary

- For quick testing: `./deploy.sh`
- For a background process: `nohup ./build/music_player > music_player.log 2>&1 &`
- For a managed, auto-restarting service on Linux: `sudo ./deploy_systemd.sh`
- For a container: `docker compose up -d --build`
- Ignore `setup.sh`
