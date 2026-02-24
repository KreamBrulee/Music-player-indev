#!/bin/bash

# Music Player Systemd Service Setup Script
# This script creates and enables a systemd service for production deployment

set -e  # Exit on error

echo "=================================="
echo "Music Player Systemd Service Setup"
echo "=================================="

# Get current directory
CURRENT_DIR=$(pwd)
EXECUTABLE_PATH="$CURRENT_DIR/build/music_player"

# Check if executable exists
if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "ERROR: music_player executable not found at $EXECUTABLE_PATH"
    echo "Please run ./deploy.sh first to build the project"
    exit 1
fi

# Get current user
CURRENT_USER=$(whoami)

echo "Creating systemd service file..."
echo "Working directory: $CURRENT_DIR"
echo "Executable: $EXECUTABLE_PATH"
echo "User: $CURRENT_USER"

# Create systemd service file
sudo tee /etc/systemd/system/music-player.service > /dev/null <<EOF
[Unit]
Description=Music Player Server
After=network.target
Documentation=https://github.com/KreamBrulee/Music-player-indev

[Service]
Type=simple
User=$CURRENT_USER
WorkingDirectory=$CURRENT_DIR
ExecStart=$EXECUTABLE_PATH
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true

# Resource limits
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

echo "Systemd service file created ✓"

# Reload systemd daemon
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable service to start on boot
echo "Enabling service to start on boot..."
sudo systemctl enable music-player

# Start the service
echo "Starting music player service..."
sudo systemctl start music-player

# Wait a moment for service to start
sleep 2

# Check status
echo ""
echo "=================================="
echo "Service Status:"
echo "=================================="
sudo systemctl status music-player --no-pager || true

echo ""
echo "=================================="
echo "Setup Complete!"
echo "=================================="
echo ""
echo "Useful commands:"
echo "  Start:   sudo systemctl start music-player"
echo "  Stop:    sudo systemctl stop music-player"
echo "  Restart: sudo systemctl restart music-player"
echo "  Status:  sudo systemctl status music-player"
echo "  Logs:    sudo journalctl -u music-player -f"
echo "  Disable: sudo systemctl disable music-player"
echo ""
echo "The service will automatically start on system reboot."
