#!/bin/bash

# Simple audio file checker with better filename handling

echo "=========================================="
echo "Audio File Checker (Filename-Safe Version)"
echo "=========================================="

cd "$(dirname "$0")" || exit 1

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

# Create directories
mkdir -p songs_backup songs_fixed

echo ""
echo "Checking files in songs/ directory..."
echo ""

TOTAL=0
CORRUPTED=0
FIXED=0

# Use process substitution to handle filenames with spaces properly
while IFS= read -r -d $'\0' filepath; do
    TOTAL=$((TOTAL + 1))
    filename=$(basename "$filepath")
    
    echo "[$TOTAL] Checking: $filename"
    
    # Check for errors using the full path
    if ffmpeg -v error -i "$filepath" -f null - 2>&1 | tee /tmp/check_output.txt | grep -q .; then
        echo "  ⚠️  CORRUPTED - Found errors:"
        head -n 3 /tmp/check_output.txt | sed 's/^/      /'
        CORRUPTED=$((CORRUPTED + 1))
        
        # Backup
        if cp "$filepath" "songs_backup/$filename" 2>/dev/null; then
            echo "  📦 Backed up successfully"
        fi
        
        # Re-encode
        echo "  🔧 Re-encoding..."
        if ffmpeg -i "$filepath" -c:a libmp3lame -b:a 192k -y "songs_fixed/$filename" -loglevel warning 2>&1; then
            if [ -f "songs_fixed/$filename" ]; then
                size=$(stat -f%z "songs_fixed/$filename" 2>/dev/null || stat -c%s "songs_fixed/$filename" 2>/dev/null)
                if [ "$size" -gt 1000 ]; then
                    echo "  ✅ Fixed! Size: $((size / 1024)) KB"
                    FIXED=$((FIXED + 1))
                else
                    echo "  ❌ Fixed file too small, might be invalid"
                    rm -f "songs_fixed/$filename"
                fi
            fi
        else
            echo "  ❌ Re-encoding failed"
        fi
    else
        echo "  ✅ File is OK"
    fi
    
    echo ""
done < <(find songs -type f \( -iname "*.mp3" -o -iname "*.wav" -o -iname "*.ogg" \) -print0)

echo "=========================================="
echo "Summary:"
echo "  Total files: $TOTAL"
echo "  Corrupted: $CORRUPTED"
echo "  Fixed: $FIXED"
echo "=========================================="

if [ $FIXED -gt 0 ]; then
    echo ""
    echo "✅ Fixed files are in: songs_fixed/"
    echo ""
    echo "To use them:"
    echo "  1. Test a fixed file first"
    echo "  2. If it works, replace all:"
    echo "     cp songs_fixed/* songs/"
    echo "  3. Restart server:"
    echo "     sudo systemctl restart music-player"
fi

if [ $CORRUPTED -eq 0 ]; then
    echo ""
    echo "✅ All files are OK! The issue is not file corruption."
    echo ""
    echo "Next steps to diagnose:"
    echo "  1. Check server logs: sudo journalctl -u music-player -f"
    echo "  2. Open browser console (F12) and check for errors"
    echo "  3. Look for 'Unexpected time jump' warnings"
fi
