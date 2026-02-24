#!/bin/bash

# Install required build tools and compilers
echo "Installing required build tools..."
sudo apt-get update
sudo apt-get install -y build-essential cmake g++ gcc

# Create necessary directories
mkdir -p build songs src

# Move main.cpp to src directory if it's not already there
if [ ! -f src/main.cpp ]; then
    mv main.cpp src/ 2>/dev/null || true
fi

# Clean build directory
cd build
rm -rf *
cmake ..
cmake --build . -j$(nproc)

# Go back to root directory
cd ..

# Start the servers
echo "Starting music player servers..."

# Start Python HTTP server for frontend
python3 -m http.server 8000 &
FRONTEND_PID=$!

# Start the C++ backend server
./build/music_player &
BACKEND_PID=$!

echo "Music player is running!"
echo "Access the frontend at: http://localhost:8000"
echo "Backend API is running at: http://localhost:3000"
echo "Press Ctrl+C to stop the servers"

# Handle cleanup on script termination
trap "kill $FRONTEND_PID $BACKEND_PID; exit" INT TERM

# Wait for either server to exit
wait