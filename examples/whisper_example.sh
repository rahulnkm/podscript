#!/bin/bash

# Example script for using podscript with OpenAI's Whisper API
# This script demonstrates how to transcribe an audio file using OpenAI's Whisper model

# Set up environment variables
# Replace with your actual OpenAI API key
export OPENAI_API_KEY="your-openai-api-key-here"

# Check if an audio file was provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <path-to-audio-file>"
    echo "Example: $0 ~/Downloads/podcast.mp3"
    exit 1
fi

AUDIO_FILE=$1
OUTPUT_FILE="${AUDIO_FILE%.*}_transcript.txt"

echo "🎙️ Transcribing audio file: $AUDIO_FILE"
echo "📝 Output will be saved to: $OUTPUT_FILE"

# Run the transcription
# You can customize these options:
# --model: Choose a Whisper model (default: whisper-1)
# --language: Specify the language (e.g., en, fr, es)
# --prompt: Provide context to improve transcription
# --temperature: Control randomness (0.0 to 1.0)
./podscript open-ai-whisper "$AUDIO_FILE" --output "$OUTPUT_FILE"

# Check if transcription was successful
if [ $? -eq 0 ]; then
    echo "✅ Transcription completed successfully!"
    echo "📄 First few lines of the transcript:"
    head -n 5 "$OUTPUT_FILE"
    echo "..."
else
    echo "❌ Transcription failed. Please check your API key and try again."
fi
