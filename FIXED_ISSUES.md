# 🔧 FIXED: Mixed Content & HTTPS Issues

## What Was Wrong:
The HTMX attribute had a hardcoded URL:
```html
<!-- ❌ BEFORE -->
hx-get="http://localhost:3000/api/songs"

<!-- ✅ AFTER -->
hx-get="/api/songs"
```

This caused the browser to:
1. Load the page over HTTPS (`https://music.potassulfide.com`)
2. Try to fetch API from HTTP localhost (blocked by browser security)

## What Was Fixed:
Changed to a **relative URL** (`/api/songs`) which automatically uses the same protocol and domain as the page.

## Deployment Steps:

### 1. Upload the Updated index.html
```bash
# From your local machine, upload to EC2:
scp index.html user@your-server:/path/to/music-player/

# Or if files are synced via git:
cd /path/to/music-player
git pull
```

### 2. Verify the File is Updated
```bash
# On EC2, check the file:
grep "hx-get" index.html

# Should show:
# hx-get="/api/songs"
# NOT: hx-get="http://localhost:3000/api/songs"
```

### 3. Clear Browser Cache
**IMPORTANT**: Your browser might have cached the old file!

**Option A - Hard Refresh:**
- Chrome/Edge: `Ctrl + Shift + R` (Windows) or `Cmd + Shift + R` (Mac)
- Firefox: `Ctrl + F5` (Windows) or `Cmd + Shift + R` (Mac)

**Option B - Clear Cache:**
1. Open DevTools (F12)
2. Right-click the refresh button
3. Select "Empty Cache and Hard Reload"

**Option C - Incognito Mode:**
- Test in a new incognito/private window

### 4. Test Again
1. Open `https://music.potassulfide.com`
2. Open DevTools (F12) → Console tab
3. Should see: `API Base URL: https://music.potassulfide.com`
4. Check Network tab - all requests should go to `https://music.potassulfide.com`

### 5. Verify No Errors
Check for these in Console (F12):
- ✅ No `ERR_BLOCKED_BY_CLIENT` errors
- ✅ No `localhost:3000` requests
- ✅ All API calls to `https://music.potassulfide.com`
- ✅ Songs list loads successfully

## Why Relative URLs Are Better:

Using `/api/songs` instead of full URL:
- ✅ Works with HTTP and HTTPS automatically
- ✅ Works with any domain
- ✅ No mixed content issues
- ✅ Easier to maintain
- ✅ Browser security friendly

## Troubleshooting:

### Still seeing localhost:3000?
**Clear your browser cache!** The old file is cached.

### Still getting ERR_BLOCKED_BY_CLIENT?
1. Check if you have ad blocker/privacy extensions blocking requests
2. Try in incognito mode
3. Check DevTools → Network tab → click failed request to see details

### Getting 404 errors?
Make sure your C++ server is running and listening on port 3000:
```bash
sudo netstat -tlnp | grep 3000
# Should show your music_player process
```

### HTTPS not working?
If using HTTPS, ensure your tunnel/proxy handles SSL termination correctly.

## Expected Behavior Now:

### When you visit https://music.potassulfide.com:
1. ✅ Page loads over HTTPS
2. ✅ HTMX fetches `/api/songs` (becomes `https://music.potassulfide.com/api/songs`)
3. ✅ JavaScript uses `window.location.origin` = `https://music.potassulfide.com`
4. ✅ All requests go through HTTPS to your domain
5. ✅ Tunnel routes to port 3000 on EC2
6. ✅ Music plays!

## Quick Test Commands:

```bash
# 1. Test API locally on EC2
curl http://localhost:3000/api/songs

# 2. Test API via domain (should work)
curl https://music.potassulfide.com/api/songs

# 3. Both should return the same JSON with your songs list
```

## Success! 🎉

Once you've uploaded the new `index.html` and cleared your browser cache, everything should work perfectly!
