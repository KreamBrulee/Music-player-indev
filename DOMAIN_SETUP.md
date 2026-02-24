# Domain Setup for music.potassulfide.com

## Your Setup:
- **Domain**: `music.potassulfide.com`
- **Tunneled Port**: 3000 (on EC2)
- **Other Service**: `player.potassulfide.com` → Port 8000

## Current Configuration: ✅ Already Optimized

The code is configured to automatically work with your domain:
- `API_BASE_URL = window.location.origin` dynamically adapts to:
  - **Production**: `http://music.potassulfide.com` or `https://music.potassulfide.com`
  - **Local Dev**: `http://localhost:3000`
  - **Direct IP**: `http://your-ip:3000`

## How It Works:

1. User visits `music.potassulfide.com`
2. JavaScript detects the domain automatically
3. All API calls go to `music.potassulfide.com/api/...`
4. Your tunnel routes traffic to EC2 instance port 3000
5. Music streams successfully! 🎵

## Deployment Steps:

### 1. Rebuild Application
```bash
cd /path/to/music-player
mkdir -p build
cd build
cmake ..
make
```

### 2. Ensure Directory Structure
```
music-player/
├── music_player (or your executable)
├── index.html
└── songs/
    ├── song1.mp3
    ├── song2.mp3
    └── ...
```

### 3. Upload Songs
Make sure your music files are in the `songs/` directory on the EC2 instance.

### 4. Run the Server
```bash
./music_player
```

Or with systemd service (recommended):
```bash
sudo systemctl start music-player
```

### 5. Configure Your Tunnel/Reverse Proxy
If you're using a reverse proxy (like Nginx or Cloudflare Tunnel), ensure it's configured to forward to port 3000:

**Example Nginx Config:**
```nginx
server {
    listen 80;
    server_name music.potassulfide.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering off;
    }
}
```

**Example Cloudflare Tunnel Config (cloudflared):**
```yaml
tunnel: your-tunnel-id
credentials-file: /path/to/credentials.json

ingress:
  - hostname: music.potassulfide.com
    service: http://localhost:3000
  - hostname: player.potassulfide.com
    service: http://localhost:8000
  - service: http_status:404
```

## SSL/HTTPS Setup (Recommended)

If using HTTPS (recommended for production), the code will automatically use `https://music.potassulfide.com`.

**With Let's Encrypt:**
```bash
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d music.potassulfide.com
```

## Testing:

### 1. Test API Endpoints
```bash
# From your EC2 instance:
curl http://localhost:3000/api/songs

# From outside:
curl http://music.potassulfide.com/api/songs
```

### 2. Check if Songs Load
```bash
# Should return JSON with your songs list
curl http://music.potassulfide.com/api/songs
```

### 3. Test in Browser
1. Open `http://music.potassulfide.com` (or `https://` if SSL is configured)
2. Open Developer Console (F12)
3. Check for "API Base URL:" log
4. Should show: `http://music.potassulfide.com` or `https://music.potassulfide.com`
5. Check Network tab to see if API calls are successful

## Troubleshooting:

### Songs don't load:
1. **Check console logs**: Open F12 → Console tab
   - Look for the "API Base URL:" log
   - Check for any red error messages

2. **Check Network tab**: F12 → Network tab
   - Click on failed requests
   - Check if they're going to the correct URL

3. **Verify songs directory**:
   ```bash
   ls -la /path/to/music-player/songs/
   ```

4. **Check file permissions**:
   ```bash
   chmod +r songs/*.mp3
   ```

5. **Test API directly**:
   ```bash
   curl http://music.potassulfide.com/api/songs
   ```

### CORS Issues:
The server already has CORS enabled for all origins. If you still have issues:
- Check if your tunnel/proxy is stripping CORS headers
- Verify the proxy configuration forwards headers correctly

### Tunnel Issues:
- Verify port 3000 is running: `sudo netstat -tlnp | grep 3000`
- Check tunnel status (if using cloudflared): `cloudflared tunnel info`
- Test locally first: `curl http://localhost:3000`

## Security Notes:

1. **CORS**: Currently allows all origins (`*`). For production, consider restricting:
   ```cpp
   {"Access-Control-Allow-Origin", "https://music.potassulfide.com"}
   ```

2. **HTTPS**: Strongly recommended for production to prevent man-in-the-middle attacks

3. **File Access**: Ensure songs directory has appropriate permissions (readable but not writable by web server)

## Performance Optimization:

1. **Enable gzip compression** in your reverse proxy for faster loading
2. **Add caching headers** for static assets
3. **Consider CDN** for music files if serving many users
4. **Monitor bandwidth** usage if streaming large files

## Success Indicators:
✅ Can access `http://music.potassulfide.com`  
✅ Console shows correct API Base URL  
✅ Song list appears in the UI  
✅ Songs play when clicked  
✅ No CORS errors in console  
✅ Network tab shows successful API calls  

---

**Note**: The code is already configured to work with your domain setup. Just rebuild, deploy, and test!
