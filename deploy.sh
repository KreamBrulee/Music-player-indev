#!/bin/bash

# Music Player Deployment Script for Production
# This script builds and runs the music player for deployment

set -e  # Exit on error

echo "=================================="
echo "Music Player Deployment Setup"
echo "=================================="

# 1. Install required build tools and compilers (if needed)
echo "Checking for required build tools..."
if ! command -v cmake &> /dev/null || ! command -v g++ &> /dev/null; then
    echo "Installing required build tools..."
    sudo apt-get update
    sudo apt-get install -y build-essential cmake g++ gcc
else
    echo "Build tools already installed ✓"
fi

# 2. Create necessary directories
echo "Creating directories..."
mkdir -p build songs src include

# 3. Ensure index.html is in the root directory
if [ ! -f index.html ]; then
    echo "ERROR: index.html not found in root directory!"
    exit 1
fi
echo "index.html found ✓"

# 4. Ensure songs directory has music files
SONG_COUNT=$(find songs -name "*.mp3" -o -name "*.wav" -o -name "*.ogg" | wc -l)
if [ $SONG_COUNT -eq 0 ]; then
    echo "WARNING: No music files found in songs/ directory"
    echo "Please add .mp3, .wav, or .ogg files to the songs/ directory"
else
    echo "Found $SONG_COUNT song(s) in songs/ directory ✓"
fi

# 5. Clean and build
echo "Building music player..."
cd build
rm -rf *
cmake ..
cmake --build . -j$(nproc)
cd ..

if [ ! -f build/music_player ]; then
    echo "ERROR: Build failed - music_player executable not found"
    exit 1
fi
echo "Build successful ✓"

# 6. Stop any existing instance
echo "Checking for existing instances..."
if pgrep -x "music_player" > /dev/null; then
    echo "Stopping existing music_player process..."
    pkill -x "music_player" || true
    sleep 2
fi

# 7. Start the server
echo "=================================="
echo "Starting Music Player Server..."
echo "=================================="
./build/music_player

# Note: Server runs in foreground. Use Ctrl+C to stop.
# For production, consider using systemd service (see deploy_systemd.sh)
