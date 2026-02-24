# Deployment Guide for Music Player on DigitalOcean

## Issues Fixed:
1. ✅ Changed API_BASE_URL from hardcoded `http://localhost:3000` to dynamic `window.location.origin`
2. ✅ Added route to serve `index.html` at root path `/`

## Prerequisites on Your EC2 Instance:
- C++ compiler (g++)
- CMake or build tools
- cpp-httplib library
- nlohmann-json library

## Deployment Steps:

### 1. Rebuild Your Application
After making the changes, rebuild your application on the EC2 instance:

```bash
cd /path/to/your/music-player
mkdir -p build
cd build
cmake ..
make
```

Or if using direct compilation:
```bash
g++ -std=c++17 src/main.cpp -o music_player -lpthread
```

### 2. Ensure Songs Directory Exists
Make sure your `songs` directory is in the same location as your executable:

```bash
# Create songs directory if it doesn't exist
mkdir -p songs

# Upload your music files to the songs directory
# You can use scp from your local machine:
# scp *.mp3 user@your-server-ip:/path/to/music-player/songs/
```

### 3. Ensure index.html is Accessible
Make sure `index.html` is in the same directory as your executable or specify the correct path.

### 4. Run the Server
```bash
./music_player
# or if built with cmake:
./build/music_player
```

### 5. Configure Firewall
Make sure port 3000 is open on your DigitalOcean droplet:

```bash
# If using ufw:
sudo ufw allow 3000/tcp
sudo ufw reload

# Check status:
sudo ufw status
```

### 6. Access Your Music Player
Open your browser and navigate to:
```
http://your-server-ip:3000
```

## Optional: Run as a Service (Recommended for Production)

Create a systemd service file to keep the server running:

```bash
sudo nano /etc/systemd/system/music-player.service
```

Add the following content:
```ini
[Unit]
Description=Music Player Server
After=network.target

[Service]
Type=simple
User=your-username
WorkingDirectory=/path/to/your/music-player
ExecStart=/path/to/your/music-player/build/music_player
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Then enable and start the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable music-player
sudo systemctl start music-player
sudo systemctl status music-player
```

## Optional: Use Nginx as Reverse Proxy

For production, it's recommended to use Nginx as a reverse proxy:

1. Install Nginx:
```bash
sudo apt update
sudo apt install nginx
```

2. Configure Nginx:
```bash
sudo nano /etc/nginx/sites-available/music-player
```

Add:
```nginx
server {
    listen 80;
    server_name your-domain.com;  # or your IP

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

3. Enable the site:
```bash
sudo ln -s /etc/nginx/sites-available/music-player /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

4. Allow HTTP traffic:
```bash
sudo ufw allow 'Nginx Full'
```

Now you can access your site via: `http://your-server-ip` (port 80)

## Troubleshooting:

### If songs still don't play:
1. Check if songs directory exists and has music files:
   ```bash
   ls -la songs/
   ```

2. Check file permissions:
   ```bash
   chmod +r songs/*.mp3
   ```

3. Check if server is running:
   ```bash
   sudo netstat -tlnp | grep 3000
   ```

4. Check server logs:
   ```bash
   journalctl -u music-player -f
   ```

5. Test API endpoints directly:
   ```bash
   curl http://localhost:3000/api/songs
   ```

6. Check browser console (F12) for JavaScript errors

### Common Issues:
- **403 Forbidden**: Check file permissions
- **404 Not Found**: Ensure songs directory is in the correct location
- **Connection Refused**: Check if firewall allows port 3000
- **CORS errors**: Already handled in the code with wildcard CORS headers

## Security Note:
The current CORS configuration allows all origins (`*`). For production, consider restricting this to specific domains.
