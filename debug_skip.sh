#!/bin/bash

# Debug Helper: Find where the song skips

echo "=========================================="
echo "Song Skip Point Debugger"
echo "=========================================="
echo ""
echo "This will help identify EXACTLY where and why the song skips."
echo ""

# Ask which song
echo "Available songs:"
cd "$(dirname "$0")/songs" || exit 1
ls -1 *.mp3 2>/dev/null | nl
echo ""
read -p "Which song number is skipping? " SONG_NUM

SONG_FILE=$(ls -1 *.mp3 2>/dev/null | sed -n "${SONG_NUM}p")

if [ -z "$SONG_FILE" ]; then
    echo "Invalid selection!"
    exit 1
fi

cd ..

echo ""
echo "=========================================="
echo "Analyzing: $SONG_FILE"
echo "=========================================="

# Get detailed info
echo ""
echo "1. File Information:"
ls -lh "songs/$SONG_FILE"

echo ""
echo "2. FFmpeg Analysis:"
ffmpeg -i "songs/$SONG_FILE" 2>&1 | grep -E "(Duration|bitrate|Stream|Audio)"

echo ""
echo "3. Checking for corruption:"
if ffmpeg -v error -i "songs/$SONG_FILE" -f null - 2>&1 | grep -q .; then
    echo "   ⚠️  File has errors:"
    ffmpeg -v error -i "songs/$SONG_FILE" -f null - 2>&1 | head -5
else
    echo "   ✅ No corruption detected"
fi

echo ""
echo "4. MP3 Frame Analysis:"
ffprobe -v error -show_entries format=duration,bit_rate -of default=noprint_wrappers=1 "songs/$SONG_FILE" 2>&1

echo ""
echo "=========================================="
echo "NEXT: Tell me at what time it skips?"
read -p "Enter skip time in seconds (e.g., 23.5): " SKIP_TIME

if [ -n "$SKIP_TIME" ]; then
    echo ""
    echo "Extracting audio around skip point ($SKIP_TIME seconds)..."
    
    # Extract 5 seconds before and after the skip point
    START_TIME=$(echo "$SKIP_TIME - 5" | bc)
    if (( $(echo "$START_TIME < 0" | bc -l) )); then
        START_TIME=0
    fi
    
    mkdir -p debug_samples
    OUTPUT="debug_samples/skip_point_sample.mp3"
    
    ffmpeg -i "songs/$SONG_FILE" -ss "$START_TIME" -t 15 -c copy "$OUTPUT" -y 2>&1 | grep -E "(Duration|error)"
    
    if [ -f "$OUTPUT" ]; then
        echo ""
        echo "✅ Extracted 15-second sample around skip point"
        echo "   Sample file: $OUTPUT"
        echo ""
        echo "Test this sample on your local machine."
        echo "If it plays fine locally but skips on the server,"
        echo "the issue is with the streaming/server, not the file."
    fi
    
    echo ""
    echo "=========================================="
    echo "Byte Offset Calculation:"
    
    # Get bitrate
    BITRATE=$(ffprobe -v error -select_streams a:0 -show_entries stream=bit_rate -of default=noprint_wrappers=1:nokey=1 "songs/$SONG_FILE" 2>/dev/null)
    
    if [ -n "$BITRATE" ]; then
        # Calculate approximate byte offset
        BYTES=$(echo "$SKIP_TIME * $BITRATE / 8" | bc)
        echo "   Approximate byte offset: $BYTES bytes"
        echo "   (Look for this in server logs when streaming)"
    fi
fi

echo ""
echo "=========================================="
echo "Additional Diagnostics:"
echo "=========================================="
echo ""
echo "Run these commands to get more info:"
echo ""
echo "1. Watch server logs in real-time:"
echo "   sudo journalctl -u music-player -f"
echo ""
echo "2. In your browser (F12 Console), check for:"
echo "   - 'Unexpected time jump detected'"
echo "   - Error messages"
echo ""
echo "3. In Network tab (F12), check:"
echo "   - All range requests"
echo "   - Response codes (should be 206)"
echo "   - Content-Range headers"
echo ""
echo "4. Rebuild with debug logging:"
echo "   cd build && cmake .. && make && cd .."
echo "   sudo systemctl restart music-player"
echo ""
