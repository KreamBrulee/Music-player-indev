#!/bin/bash

# Music Player Deployment Script for Production
# This script builds and runs the music player for deployment
# Works on macOS and Linux.

set -e  # Exit on error

echo "=================================="
echo "Music Player Deployment Setup"
echo "=================================="

OS="$(uname -s)"

# Portable CPU core count (nproc is Linux-only)
if command -v nproc &> /dev/null; then
    JOBS="$(nproc)"
elif [ "$OS" = "Darwin" ]; then
    JOBS="$(sysctl -n hw.ncpu)"
else
    JOBS=2
fi

# 1. Install required build tools and compilers (if needed)
echo "Checking for required build tools..."
if ! command -v cmake &> /dev/null || ! command -v c++ &> /dev/null; then
    echo "Installing required build tools..."
    if [ "$OS" = "Darwin" ]; then
        if ! xcode-select -p &> /dev/null; then
            echo "Installing Xcode Command Line Tools (provides clang/make)..."
            xcode-select --install
            echo "Re-run this script after the Command Line Tools install finishes."
            exit 1
        fi
        if ! command -v brew &> /dev/null; then
            echo "ERROR: Homebrew not found. Install it from https://brew.sh, then re-run this script."
            exit 1
        fi
        brew install cmake
    elif [ "$OS" = "Linux" ]; then
        sudo apt-get update
        sudo apt-get install -y build-essential cmake g++ gcc
    else
        echo "ERROR: Unsupported OS '$OS'. Please install CMake and a C++17 compiler manually."
        exit 1
    fi
else
    echo "Build tools already installed ✓"
fi

# 2. Create necessary directories
echo "Creating directories..."
mkdir -p build songs src include public

# 3. Ensure the frontend is in place
if [ ! -f public/index.html ]; then
    echo "ERROR: public/index.html not found!"
    exit 1
fi
echo "public/index.html found ✓"

# 4. Ensure songs directory has music files
SONG_COUNT=$(find songs -name "*.mp3" -o -name "*.wav" -o -name "*.ogg" | wc -l | tr -d ' ')
if [ "$SONG_COUNT" -eq 0 ]; then
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
cmake --build . -j"$JOBS"
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
# To run in the background instead:
#   nohup ./build/music_player > music_player.log 2>&1 &
# For a managed, auto-restarting service on Linux:
#   sudo ./deploy_systemd.sh
