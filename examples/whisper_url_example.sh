#!/bin/bash

# Example script for transcribing audio from a URL using OpenAI's Whisper API
# This script demonstrates how to download an MP3 from a URL and transcribe it

# Set up environment variables
# Replace with your actual OpenAI API key
export OPENAI_API_KEY="your-openai-api-key-here"

# Check if a URL was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <url-to-mp3-file>"
    echo "Example: $0 https://example.com/podcast.mp3"
    exit 1
fi

# Get the URL from command line argument
MP3_URL=$1

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
echo "🔧 Created temporary directory: $TEMP_DIR"

# Extract filename from URL
FILENAME=$(basename "$MP3_URL")
if [[ ! $FILENAME =~ \.(mp3|mp4|mpeg|mpga|m4a|wav|webm)$ ]]; then
    # If URL doesn't end with a recognized audio extension, use a default name
    FILENAME="downloaded_audio.mp3"
fi

# Full path to the downloaded file
AUDIO_FILE="$TEMP_DIR/$FILENAME"
OUTPUT_FILE="${FILENAME%.*}_transcript.txt"

# Download the file
echo "⬇️ Downloading audio from: $MP3_URL"
echo "📁 Saving to: $AUDIO_FILE"
curl -L -o "$AUDIO_FILE" "$MP3_URL"

# Check if download was successful
if [ $? -ne 0 ]; then
    echo "❌ Failed to download the audio file. Please check the URL and try again."
    rm -rf "$TEMP_DIR"
    exit 1
fi

echo "✅ Download completed successfully"
echo "🎙️ Transcribing audio file"
echo "📝 Output will be saved to: $OUTPUT_FILE"

# Run the transcription
# You can customize these options:
# --model: Choose a Whisper model (default: whisper-1)
# --language: Specify the language (e.g., en, fr, es)
# --prompt: Provide context to improve transcription
# --temperature: Control randomness (0.0 to 1.0)
podscript open-ai-whisper "$AUDIO_FILE" --output "$OUTPUT_FILE"

# Check if transcription was successful
if [ $? -eq 0 ]; then
    echo "✅ Transcription completed successfully!"
    echo "📄 First few lines of the transcript:"
    head -n 5 "$OUTPUT_FILE"
    echo "..."
else
    echo "❌ Transcription failed. Please check your API key and try again."
fi

# Clean up temporary files
echo "🧹 Cleaning up temporary files"
rm -rf "$TEMP_DIR"
echo "✅ Done! Transcript saved to $OUTPUT_FILE"
