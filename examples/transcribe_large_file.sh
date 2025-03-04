#!/bin/bash
# transcribe_large_file.sh - Split and transcribe large audio files
# 
# This script handles audio files that exceed OpenAI's 25MB limit by:
# 1. Downloading the audio file
# 2. Splitting it into smaller chunks
# 3. Transcribing each chunk
# 4. Combining the transcripts
#
# Usage: ./transcribe_large_file.sh <audio_url> [language] [prompt]

set -e  # Exit immediately if a command exits with a non-zero status

# Function to display usage information
usage() {
    echo "Usage: $0 <audio_url> [--language <lang>] [--prompt <prompt>]"
    echo
    echo "Arguments:"
    echo "  audio_url             URL of the audio file to download and transcribe"
    echo "  --language <lang>     (Optional) Language code (e.g., 'en' for English)"
    echo "  --prompt <prompt>     (Optional) Context to improve transcription accuracy"
    echo
    echo "Example:"
    echo "  $0 https://example.com/podcast.mp3 --language en --prompt \"Tech podcast about AI\""
    exit 1
}

# Function to clean up temporary files
cleanup() {
    echo "🧹 Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    echo "✅ Cleanup complete"
}

# Check if URL is provided
if [ $# -lt 1 ]; then
    usage
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ ffmpeg is required but not installed."
    echo "Please install ffmpeg to use this script."
    echo "On macOS: brew install ffmpeg"
    echo "On Ubuntu: sudo apt-get install ffmpeg"
    exit 1
fi

# Parse arguments
AUDIO_URL="$1"
LANGUAGE=""
PROMPT=""

# Process optional arguments
shift
while [[ $# -gt 0 ]]; do
    case "$1" in
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --prompt)
            PROMPT="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            usage
            ;;
    esac
done

# Extract OpenAI API key from config file
CONFIG_FILE=~/.podscript.toml
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    echo "Please run 'podscript configure' to set up your API keys"
    exit 1
fi

# Extract the OpenAI API key from the config file
OPENAI_API_KEY=$(grep "openai-api-key" "$CONFIG_FILE" | cut -d "=" -f2 | tr -d ' "')

if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ OpenAI API key not found in config file"
    echo "Please run 'podscript configure' to set up your OpenAI API key"
    exit 1
fi

echo "✅ Found OpenAI API key in configuration"

# Export the API key as an environment variable
export OPENAI_API_KEY

echo "🔑 Set OPENAI_API_KEY environment variable"

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
echo "🔧 Created temporary directory: $TEMP_DIR"

# Set trap to clean up on exit
trap cleanup EXIT

# Extract filename from URL
FILENAME=$(basename "$AUDIO_URL")
if [[ ! $FILENAME =~ \.(mp3|mp4|mpeg|mpga|m4a|wav|webm)$ ]]; then
    # If URL doesn't end with a recognized audio extension, use a default name
    FILENAME="downloaded_audio.mp3"
fi

# Full path to the downloaded file
AUDIO_FILE="$TEMP_DIR/$FILENAME"
FINAL_OUTPUT_FILE="${FILENAME%.*}_transcript.txt"

# Download the file
echo "⬇️ Downloading audio from: $AUDIO_URL"
echo "📁 Saving to: $AUDIO_FILE"
curl -L -o "$AUDIO_FILE" "$AUDIO_URL"

# Check if download was successful
if [ ! -f "$AUDIO_FILE" ] || [ ! -s "$AUDIO_FILE" ]; then
    echo "❌ Failed to download the audio file. Please check the URL and try again."
    exit 1
fi

echo "✅ Download completed successfully"

# Get file size in bytes
FILE_SIZE=$(stat -f%z "$AUDIO_FILE")
echo "📊 File size: $FILE_SIZE bytes"

# OpenAI's limit is 25MB (26214400 bytes)
MAX_SIZE=25000000  # Slightly under the limit to be safe

if [ "$FILE_SIZE" -le "$MAX_SIZE" ]; then
    echo "✅ File size is within OpenAI's limit, proceeding with direct transcription"
    
    echo "🎙️ Transcribing audio file"
    echo "📝 Output will be saved to: $FINAL_OUTPUT_FILE"
    
    # Build the command with optional parameters
    CMD=("./podscript" "open-ai-whisper" "$AUDIO_FILE" "--output" "$FINAL_OUTPUT_FILE")
    
    # Add language if provided
    if [ -n "$LANGUAGE" ]; then
        CMD+=("--language" "$LANGUAGE")
    fi
    
    # Add prompt if provided
    if [ -n "$PROMPT" ]; then
        CMD+=("--prompt" "$PROMPT")
    fi
    
    # Run the transcription
    echo "🔄 Running command: ${CMD[@]}"
    "${CMD[@]}"
else
    echo "⚠️ File size exceeds OpenAI's 25MB limit, splitting into smaller chunks"
    
    # Get audio duration in seconds
    DURATION=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$AUDIO_FILE")
    echo "⏱️ Audio duration: $DURATION seconds"
    
    # Calculate chunk duration based on file size
    # We'll aim for chunks of about 20MB to be safe
    CHUNK_COUNT=$(( (FILE_SIZE / 20000000) + 1 ))
    CHUNK_DURATION=$(echo "$DURATION / $CHUNK_COUNT" | bc -l)
    echo "🧩 Splitting into $CHUNK_COUNT chunks of approximately $CHUNK_DURATION seconds each"
    
    # Create a directory for chunks
    CHUNKS_DIR="$TEMP_DIR/chunks"
    mkdir -p "$CHUNKS_DIR"
    
    # Create a directory for individual transcripts
    TRANSCRIPTS_DIR="$TEMP_DIR/transcripts"
    mkdir -p "$TRANSCRIPTS_DIR"
    
    # Split the audio file into chunks
    echo "✂️ Splitting audio file..."
    
    for i in $(seq 1 $CHUNK_COUNT); do
        START_TIME=$(echo "($i - 1) * $CHUNK_DURATION" | bc -l)
        
        # For all chunks except the last one, set a specific duration
        if [ "$i" -lt "$CHUNK_COUNT" ]; then
            CHUNK_FILE="$CHUNKS_DIR/chunk_${i}.mp3"
            echo "🔪 Creating chunk $i: Starting at $START_TIME seconds for $CHUNK_DURATION seconds"
            ffmpeg -v quiet -y -i "$AUDIO_FILE" -ss "$START_TIME" -t "$CHUNK_DURATION" -acodec libmp3lame -b:a 128k "$CHUNK_FILE"
        else
            # For the last chunk, don't specify duration to get the remainder of the file
            CHUNK_FILE="$CHUNKS_DIR/chunk_${i}.mp3"
            echo "🔪 Creating final chunk $i: Starting at $START_TIME seconds until the end"
            ffmpeg -v quiet -y -i "$AUDIO_FILE" -ss "$START_TIME" -acodec libmp3lame -b:a 128k "$CHUNK_FILE"
        fi
        
        # Check chunk size
        CHUNK_SIZE=$(stat -f%z "$CHUNK_FILE")
        echo "📊 Chunk $i size: $CHUNK_SIZE bytes"
        
        # Transcribe the chunk
        CHUNK_TRANSCRIPT="$TRANSCRIPTS_DIR/transcript_${i}.txt"
        echo "🎙️ Transcribing chunk $i..."
        
        # Build the command with optional parameters
        CMD=("./podscript" "open-ai-whisper" "$CHUNK_FILE" "--output" "$CHUNK_TRANSCRIPT")
        
        # Add language if provided
        if [ -n "$LANGUAGE" ]; then
            CMD+=("--language" "$LANGUAGE")
        fi
        
        # Add prompt if provided
        if [ -n "$PROMPT" ]; then
            CMD+=("--prompt" "$PROMPT")
        fi
        
        # Run the transcription
        echo "🔄 Running command for chunk $i: ${CMD[@]}"
        "${CMD[@]}"
        
        echo "✅ Chunk $i transcribed successfully"
    done
    
    # Combine all transcripts
    echo "🔄 Combining all transcripts..."
    echo "# Transcription of $FILENAME" > "$FINAL_OUTPUT_FILE"
    echo "# Generated on $(date)" >> "$FINAL_OUTPUT_FILE"
    echo "" >> "$FINAL_OUTPUT_FILE"
    
    for i in $(seq 1 $CHUNK_COUNT); do
        CHUNK_TRANSCRIPT="$TRANSCRIPTS_DIR/transcript_${i}.txt"
        echo "## Part $i" >> "$FINAL_OUTPUT_FILE"
        cat "$CHUNK_TRANSCRIPT" >> "$FINAL_OUTPUT_FILE"
        echo "" >> "$FINAL_OUTPUT_FILE"
        echo "" >> "$FINAL_OUTPUT_FILE"
    done
    
    echo "✅ All chunks combined into: $FINAL_OUTPUT_FILE"
fi

# Check if transcription was successful
if [ -f "$FINAL_OUTPUT_FILE" ] && [ -s "$FINAL_OUTPUT_FILE" ]; then
    echo "✅ Transcription completed successfully!"
    echo "📄 First few lines of the transcript:"
    head -n 5 "$FINAL_OUTPUT_FILE"
    echo "..."
    echo "📋 Full transcript saved to: $FINAL_OUTPUT_FILE"
else
    echo "❌ Transcription failed. Please check the logs above for errors."
    exit 1
fi

echo "✅ All operations completed successfully"
