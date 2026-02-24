# 🚀 Quick Deployment Guide

## TL;DR - Quick Start:

### First Time Setup (Production - Recommended):
```bash
# 1. Make scripts executable
chmod +x deploy.sh deploy_systemd.sh

# 2. Build and setup service
./deploy.sh  # Build the project (will fail to start, that's OK)
# Press Ctrl+C after it starts

# 3. Setup systemd service (runs in background, auto-restarts)
sudo ./deploy_systemd.sh

# Done! Service is running and will auto-start on reboot
```

### Quick Manual Run (Testing):
```bash
chmod +x deploy.sh
./deploy.sh  # Builds and runs (foreground)
# Press Ctrl+C to stop
```

## Detailed Deployment Options:

### Option 1: Systemd Service (Recommended for Production) ✅

**Pros:**
- Runs in background
- Auto-starts on server reboot
- Auto-restarts if crashes
- Easy to manage
- Logs to systemd journal

**Steps:**
```bash
# Step 1: Build the project
chmod +x deploy.sh
./deploy.sh
# Press Ctrl+C after it starts (or wait for error)

# Step 2: Setup systemd service
chmod +x deploy_systemd.sh
sudo ./deploy_systemd.sh
```

**Management Commands:**
```bash
# Check if running
sudo systemctl status music-player

# View logs (live)
sudo journalctl -u music-player -f

# View recent logs
sudo journalctl -u music-player -n 100

# Restart (after code changes)
sudo systemctl restart music-player

# Stop
sudo systemctl stop music-player

# Start
sudo systemctl start music-player

# Disable auto-start
sudo systemctl disable music-player
```

### Option 2: Direct Run (Good for Testing)

**Pros:**
- Simple
- See output directly
- Easy to stop (Ctrl+C)

**Cons:**
- Stops when you close terminal
- Doesn't auto-restart
- Not suitable for production

**Steps:**
```bash
chmod +x deploy.sh
./deploy.sh
```

### Option 3: Run in Background with nohup

**Pros:**
- Runs in background
- Survives terminal close

**Cons:**
- No auto-restart
- Manual management

**Steps:**
```bash
# Build first
chmod +x deploy.sh
./deploy.sh
# Press Ctrl+C after build completes

# Then run in background
nohup ./build/music_player > music_player.log 2>&1 &

# Check if running
ps aux | grep music_player

# Stop it
pkill music_player

# View logs
tail -f music_player.log
```

## What About setup.sh? 🤔

The old `setup.sh` script:
- Starts **two** servers (Python + C++)
- Python server on port 8000 was for serving `index.html`
- **No longer needed!** The C++ server now serves `index.html` directly

**Don't use `setup.sh` for deployment** - it's outdated and starts an unnecessary Python server.

## After Code Changes:

### If using systemd:
```bash
# 1. Rebuild
cd /path/to/music-player
mkdir -p build
cd build
cmake ..
make -j$(nproc)
cd ..

# 2. Restart service
sudo systemctl restart music-player

# 3. Check status
sudo systemctl status music-player
```

### If running manually:
```bash
# 1. Stop current process (Ctrl+C or pkill)
pkill music_player

# 2. Rebuild and run
./deploy.sh
```

## File Checklist Before Deployment:

```
music-player/
├── deploy.sh              ✅ New deployment script
├── deploy_systemd.sh      ✅ Systemd setup script
├── setup.sh              ❌ Old script (ignore)
├── index.html            ✅ Must be in root
├── CMakeLists.txt        ✅ Build configuration
├── build/                ✅ Created by deploy.sh
│   └── music_player      ✅ Created after build
├── src/
│   └── main.cpp          ✅ Updated server code
├── songs/                ✅ Must contain .mp3 files
│   ├── song1.mp3
│   ├── song2.mp3
│   └── ...
└── include/              ✅ Headers (if any)
```

## Troubleshooting:

### Build fails?
```bash
# Check if CMakeLists.txt exists
ls -la CMakeLists.txt

# Check for compiler
g++ --version

# Install dependencies
sudo apt update
sudo apt install build-essential cmake g++
```

### Service won't start?
```bash
# Check logs
sudo journalctl -u music-player -n 50

# Check if port is in use
sudo netstat -tlnp | grep 3000

# Kill any existing process
sudo pkill music_player
sudo systemctl restart music-player
```

### No songs showing?
```bash
# Check songs directory
ls -la songs/

# Check permissions
chmod +r songs/*.mp3

# Restart service
sudo systemctl restart music-player
```

### Can't access from browser?
```bash
# Check if server is running
sudo netstat -tlnp | grep 3000

# Check firewall
sudo ufw status
sudo ufw allow 3000/tcp

# Test locally
curl http://localhost:3000/api/songs

# Test externally
curl http://music.potassulfide.com/api/songs
```

## Port Information:

- **Port 3000**: C++ music player server (serves both API and frontend)
  - Frontend: `http://your-server:3000/`
  - API: `http://your-server:3000/api/songs`
  - Streaming: `http://your-server:3000/api/songs/{id}/play`

- **Port 8000**: ~~Python server~~ (no longer used/needed!)

## Summary:

**For Production:** Use `deploy_systemd.sh` ✅  
**For Testing:** Use `deploy.sh` ✅  
**Old `setup.sh`:** Ignore it ❌  

Your music player now runs as a single server on port 3000, serving both the frontend and API! 🎵
