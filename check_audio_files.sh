#!/bin/bash

# Audio File Corruption Checker and Fixer
# This script checks MP3 files for corruption and re-encodes if needed

echo "=========================================="
echo "Audio File Corruption Checker"
echo "=========================================="

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "Installing ffmpeg..."
    sudo apt-get update
    sudo apt-get install -y ffmpeg
fi

# Check songs directory
if [ ! -d "songs" ]; then
    echo "ERROR: songs directory not found!"
    exit 1
fi

SONG_COUNT=$(find songs -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.ogg" \) | wc -l)
echo "Found $SONG_COUNT audio file(s) to check"
echo ""

# Create backup directory
mkdir -p songs_backup
mkdir -p songs_fixed

CORRUPTED=0
FIXED=0

# Check each audio file
find songs -type f \( -name "*.mp3" -o -name "*.wav" -o -name "*.ogg" \) -print0 | while IFS= read -r -d '' file; do
    filename=$(basename "$file")
    echo "Checking: $filename"
    
    # Check for errors
    ffmpeg -v error -i "$file" -f null - 2> /tmp/ffmpeg_error.txt
    
    if [ -s /tmp/ffmpeg_error.txt ]; then
        echo "  ⚠️  CORRUPTED - Found errors:"
        cat /tmp/ffmpeg_error.txt | head -3
        
        # Backup original
        cp "$file" "songs_backup/$filename"
        echo "  📦 Backed up to songs_backup/$filename"
        
        # Re-encode
        echo "  🔧 Re-encoding..."
        ffmpeg -i "$file" -c:a libmp3lame -b:a 192k -y "songs_fixed/$filename" 2>&1 | grep -E "(Duration|Output|error)" || true
        
        if [ -f "songs_fixed/$filename" ]; then
            echo "  ✅ Fixed file created: songs_fixed/$filename"
            echo "  💡 Replace original with: cp \"songs_fixed/$filename\" \"songs/$filename\""
        else
            echo "  ❌ Failed to fix"
        fi
    else
        echo "  ✅ File is OK"
    fi
    
    echo ""
done

# Count corrupted and fixed files after the loop
CORRUPTED=$(find songs_backup -type f 2>/dev/null | wc -l)
FIXED=$(find songs_fixed -type f 2>/dev/null | wc -l)

echo "=========================================="
echo "Summary:"
echo "  Total files checked: $SONG_COUNT"
echo "  Corrupted files: $CORRUPTED"
echo "  Fixed files: $FIXED"
echo "=========================================="

if [ $CORRUPTED -gt 0 ]; then
    echo ""
    echo "To use fixed files:"
    echo "  1. Test fixed files: ls -lh songs_fixed/"
    echo "  2. Replace originals: cp songs_fixed/* songs/"
    echo "  3. Restart server: sudo systemctl restart music-player"
fi
