#!/bin/bash
# compress_audio.sh - Compress audio files to meet OpenAI's 25MB limit
# 
# This script compresses an audio file to a lower bitrate to reduce its size
# while maintaining reasonable quality.
#
# Usage: ./compress_audio.sh <input_file> [bitrate]

set -e  # Exit immediately if a command exits with a non-zero status

# Function to display usage information
usage() {
    echo "Usage: $0 <input_file> [bitrate]"
    echo
    echo "Arguments:"
    echo "  input_file   Path to the audio file to compress"
    echo "  bitrate      (Optional) Target bitrate in kbps (default: 64)"
    echo
    echo "Example:"
    echo "  $0 large_podcast.mp3 48"
    exit 1
}

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ ffmpeg is required but not installed."
    echo "Please install ffmpeg to use this script."
    echo "On macOS: brew install ffmpeg"
    echo "On Ubuntu: sudo apt-get install ffmpeg"
    exit 1
fi

# Check if input file is provided
if [ $# -lt 1 ]; then
    usage
fi

# Parse arguments
INPUT_FILE="$1"
BITRATE="${2:-64}"  # Default to 64kbps if not specified

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Input file not found: $INPUT_FILE"
    exit 1
fi

# Get file extension
EXTENSION="${INPUT_FILE##*.}"
BASENAME="${INPUT_FILE%.*}"
OUTPUT_FILE="${BASENAME}_compressed.${EXTENSION}"

# Get original file size
ORIGINAL_SIZE=$(stat -f%z "$INPUT_FILE")
ORIGINAL_SIZE_MB=$(echo "scale=2; $ORIGINAL_SIZE / 1048576" | bc)

echo "📊 Original file: $INPUT_FILE ($ORIGINAL_SIZE_MB MB)"
echo "🔧 Compressing to $BITRATE kbps..."

# Compress the file
ffmpeg -i "$INPUT_FILE" -b:a "${BITRATE}k" -v warning "$OUTPUT_FILE"

# Get compressed file size
COMPRESSED_SIZE=$(stat -f%z "$OUTPUT_FILE")
COMPRESSED_SIZE_MB=$(echo "scale=2; $COMPRESSED_SIZE / 1048576" | bc)
REDUCTION=$(echo "scale=2; 100 - ($COMPRESSED_SIZE * 100 / $ORIGINAL_SIZE)" | bc)

echo "✅ Compression complete!"
echo "📊 Compressed file: $OUTPUT_FILE ($COMPRESSED_SIZE_MB MB)"
echo "📉 Size reduction: $REDUCTION%"

# Check if still over 25MB
if (( $(echo "$COMPRESSED_SIZE > 26214400" | bc -l) )); then
    echo "⚠️ Warning: Compressed file is still over 25MB"
    echo "Try compressing with a lower bitrate:"
    echo "  $0 $INPUT_FILE $(($BITRATE / 2))"
else
    echo "✅ File size is now under OpenAI's 25MB limit"
    echo
    echo "To transcribe the compressed file, run:"
    echo "  podscript open-ai-whisper \"$OUTPUT_FILE\""
fi
