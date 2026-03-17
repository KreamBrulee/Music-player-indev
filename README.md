# Potassium-music-player

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