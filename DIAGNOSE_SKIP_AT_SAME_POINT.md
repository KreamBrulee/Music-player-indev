# 🔍 DIAGNOSIS: Song Skips at Same Point Every Time

## This is CRITICAL information! ⚠️

If the song **always skips at the exact same point**, this tells us it's NOT:
- ❌ Network issue (would be random)
- ❌ Buffering issue (would vary)
- ❌ Browser cache issue (would be inconsistent)

It IS likely:
- ✅ **Corrupted audio file** (most common)
- ✅ **Malformed MP3 header** at that specific point
- ✅ **File read error** on the server
- ✅ **Character encoding issue** in the filename

## Quick Diagnostic Steps:

### Step 1: Check Which Exact Song
```bash
# On your EC2 instance, list all songs
cd /path/to/music-player
ls -lh songs/

# Note which song is skipping
```

### Step 2: Check the Audio File for Corruption
```bash
# Run the corruption checker
chmod +x check_audio_files.sh
./check_audio_files.sh

# This will:
# - Check all MP3 files for errors
# - Show you which files are corrupted
# - Create fixed versions in songs_fixed/
```

### Step 3: Check Server Logs (NEW!)
I've added detailed logging to the server. Restart it and watch the logs:

```bash
# If using systemd:
sudo systemctl restart music-player
sudo journalctl -u music-player -f

# If running manually:
pkill music_player
./build/music_player

# Play the problematic song and watch the output
```

You should see:
```
Streaming song: Song Title (ID: 1)
  File size: 5234567 bytes
  Range request: bytes=0-1048575
  Serving bytes 0-1048575/5234567 (1048576 bytes)
  Range request: bytes=1048576-2097151
  Serving bytes 1048576-2097151/5234567 (1048576 bytes)
  ...
```

**Look for:**
- ❌ `ERROR: Failed to read` messages
- ❌ Byte count mismatches
- ❌ Range requests that jump to near the end suddenly

### Step 4: Check Filename Issues
Some filenames can cause problems:

```bash
# Check for problematic characters
find songs/ -name "*[^a-zA-Z0-9._\-\ ]*" -type f

# Fix filenames if needed
cd songs/
for f in *; do
    # Remove problematic characters
    newname=$(echo "$f" | tr -cd '[:alnum:]._- ')
    if [ "$f" != "$newname" ]; then
        echo "Renaming: $f -> $newname"
        mv "$f" "$newname"
    fi
done
```

### Step 5: Test the Specific File

Let me list your songs:
```bash
ls -1 songs/
```

Then test the specific problematic file:
```bash
# Replace with your actual filename
TEST_FILE="songs/your-song-here.mp3"

# Check for corruption
echo "Testing: $TEST_FILE"
ffmpeg -v error -i "$TEST_FILE" -f null - 2>&1

# If errors shown, the file IS corrupted
# Re-encode it:
ffmpeg -i "$TEST_FILE" -c:a libmp3lame -b:a 192k "songs/fixed_song.mp3"
```

## Common Causes & Fixes:

### Cause 1: Downloaded YouTube/Online Audio (Common!)
**Problem:** Audio downloaded from YouTube or converters is often corrupted

**Fix:**
```bash
# Re-encode all songs to standard format
cd songs/
mkdir -p ../songs_reencoded

for file in *.mp3; do
    echo "Re-encoding: $file"
    ffmpeg -i "$file" -c:a libmp3lame -b:a 192k -ar 44100 -y "../songs_reencoded/$file"
done

# Test one re-encoded file first, then:
# mv ../songs_reencoded/* .
```

### Cause 2: Variable Bitrate (VBR) MP3
**Problem:** Some VBR MP3s have timing issues

**Fix:**
```bash
# Convert to Constant Bitrate (CBR)
ffmpeg -i input.mp3 -c:a libmp3lame -b:a 192k -write_xing 0 output.mp3
```

### Cause 3: Embedded Metadata/Cover Art
**Problem:** Large embedded album art can cause issues

**Fix:**
```bash
# Strip metadata and cover art
ffmpeg -i input.mp3 -map 0:a -c:a copy -map_metadata -1 output.mp3
```

### Cause 4: ID3 Tag Issues
**Problem:** Malformed ID3 tags

**Fix:**
```bash
# Remove all ID3 tags
ffmpeg -i input.mp3 -codec:a copy -map_metadata -1 -id3v2_version 0 output.mp3
```

## Automated Fix Script

I've created `check_audio_files.sh` for you. Run it:

```bash
chmod +x check_audio_files.sh
./check_audio_files.sh
```

This will:
1. ✅ Check ALL songs for corruption
2. ✅ Backup corrupted files
3. ✅ Create fixed versions
4. ✅ Give you a summary

Then:
```bash
# Review fixed files
ls -lh songs_fixed/

# Test a fixed file
# (upload to songs/ and try playing)

# If it works, replace all:
cp songs_fixed/* songs/
sudo systemctl restart music-player
```

## Real-Time Debugging:

### Browser Console (F12):
Watch for the time it jumps:
```javascript
// You'll see:
Playing song: 1 Song Title Artist
Playback started successfully
⚠️ Unexpected time jump detected! {
  from: 23.456,    // ← Note this timestamp!
  to: 187.890,
  ...
}
```

### Server Logs:
Watch for the byte range when it fails:
```bash
sudo journalctl -u music-player -f

# Look for range requests around the skip point
# If song skips at 23 seconds, and it's 192kbps:
# 23 seconds × 192,000 bits/second ÷ 8 = ~552,960 bytes
# Look for issues around byte offset 500,000-600,000
```

## Quick Test: Download Clean Sample

To verify it's the audio file and not the code:

```bash
# Download a clean test MP3
cd songs/
wget https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3

# Restart server
sudo systemctl restart music-player

# Test this song in browser
# If this plays fine, your original files are corrupted
```

## Expected Outcomes:

### If audio files are corrupted:
- ✅ `check_audio_files.sh` will find errors
- ✅ Fixed files will play smoothly
- ✅ Server logs won't show read errors

### If still skipping after fixing files:
This would indicate a different issue. Report:
1. Complete server logs during playback
2. Browser console output
3. Network tab showing all requests
4. The exact byte offset where it fails

## Priority Actions (Do These First!):

```bash
# 1. Check audio file
cd /path/to/music-player
ffmpeg -v error -i "songs/[PROBLEMATIC_FILE].mp3" -f null -

# 2. If errors shown, re-encode
ffmpeg -i "songs/[PROBLEMATIC_FILE].mp3" \
       -c:a libmp3lame -b:a 192k \
       "songs/[PROBLEMATIC_FILE]_fixed.mp3"

# 3. Test the fixed file
mv "songs/[PROBLEMATIC_FILE].mp3" "songs_backup/"
mv "songs/[PROBLEMATIC_FILE]_fixed.mp3" "songs/[PROBLEMATIC_FILE].mp3"

# 4. Restart server
sudo systemctl restart music-player

# 5. Test in browser with F12 console open
```

## 99% of the time:
The issue is **corrupted/malformed audio files**. The `check_audio_files.sh` script will fix this. 🎵

Let me know what the corruption checker finds!
