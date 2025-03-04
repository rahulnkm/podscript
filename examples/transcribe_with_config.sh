#!/bin/bash
# transcribe_with_config.sh - Transcribe audio using OpenAI Whisper with config file
# 
# This script reads the OpenAI API key from the podscript config file,
# downloads an audio file from a URL, and transcribes it using OpenAI Whisper.
#
# Usage: ./transcribe_with_config.sh <audio_url> [language] [prompt]

set -e  # Exit immediately if a command exits with a non-zero status

# Function to display usage information
usage() {
    echo "Usage: $0 <audio_url> [language] [prompt]"
    echo
    echo "Arguments:"
    echo "  audio_url   URL of the audio file to download and transcribe"
    echo "  language    (Optional) Language code (e.g., 'en' for English)"
    echo "  prompt      (Optional) Context to improve transcription accuracy"
    echo
    echo "Example:"
    echo "  $0 https://example.com/podcast.mp3 en \"Tech podcast about AI\""
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

# Parse arguments
AUDIO_URL="$1"
LANGUAGE="${2:-}"  # Optional language parameter
PROMPT="${3:-}"    # Optional prompt parameter

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
OUTPUT_FILE="${FILENAME%.*}_transcript.txt"

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
echo "🎙️ Transcribing audio file"
echo "📝 Output will be saved to: $OUTPUT_FILE"

# Build the command with optional parameters
CMD="./podscript open-ai-whisper \"$AUDIO_FILE\" --output \"$OUTPUT_FILE\""

# Add language if provided
if [ -n "$LANGUAGE" ]; then
    CMD="$CMD --language \"$LANGUAGE\""
fi

# Add prompt if provided
if [ -n "$PROMPT" ]; then
    CMD="$CMD --prompt \"$PROMPT\""
fi

# Run the transcription
echo "🔄 Running command: $CMD"
echo "🔑 Using OpenAI API key from config file"
eval $CMD

# Check if transcription was successful
if [ $? -eq 0 ]; then
    echo "✅ Transcription completed successfully!"
    echo "📄 First few lines of the transcript:"
    head -n 5 "$OUTPUT_FILE"
    echo "..."
    echo "📋 Full transcript saved to: $OUTPUT_FILE"
else
    echo "❌ Transcription failed. Please check your API key and try again."
    exit 1
fi

echo "✅ All operations completed successfully"
