#!/bin/bash
# podcast_transcriber.sh - Download and transcribe all episodes from a podcast RSS feed
# 
# This script takes a podcast RSS feed URL, extracts all episode URLs,
# downloads each episode, transcribes it using transcribe_large_file.sh,
# and organizes the transcripts in a folder structure.
#
# Usage: ./podcast_transcriber.sh <rss_feed_url> [--language <lang>] [--prompt <prompt>] [--limit <num>]

set -e  # Exit immediately if a command exits with a non-zero status

# Function to display usage information
usage() {
    echo "Usage: $0 <rss_feed_url> [--language <lang>] [--prompt <prompt>] [--limit <num>]"
    echo
    echo "Arguments:"
    echo "  rss_feed_url           URL of the podcast RSS feed"
    echo "  --language <lang>      (Optional) Language code (e.g., 'en' for English)"
    echo "  --prompt <prompt>      (Optional) Context to improve transcription accuracy"
    echo "  --limit <num>          (Optional) Limit the number of episodes to process (newest first)"
    echo
    echo "Example:"
    echo "  $0 https://example.com/podcast.rss --language en --prompt \"Tech podcast about AI\" --limit 5"
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

# Check if required tools are installed
for cmd in curl xmllint ffmpeg; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ $cmd is required but not installed."
        echo "Please install $cmd to use this script."
        echo "On macOS: brew install $cmd"
        echo "On Ubuntu: sudo apt-get install $cmd"
        exit 1
    fi
done

# Parse arguments
RSS_URL="$1"
LANGUAGE=""
PROMPT=""
LIMIT=""

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
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        *)
            echo "Unknown parameter: $1"
            usage
            ;;
    esac
done

# Create a temporary directory
TEMP_DIR=$(mktemp -d)
echo "🔧 Created temporary directory: $TEMP_DIR"

# Set trap to clean up on exit
trap cleanup EXIT

# Download the RSS feed
echo "⬇️ Downloading RSS feed from: $RSS_URL"
RSS_FILE="$TEMP_DIR/podcast.rss"
curl -s -L -o "$RSS_FILE" "$RSS_URL"

# Check if download was successful
if [ ! -f "$RSS_FILE" ] || [ ! -s "$RSS_FILE" ]; then
    echo "❌ Failed to download the RSS feed. Please check the URL and try again."
    exit 1
fi

echo "✅ RSS feed downloaded successfully"

# Extract podcast title
PODCAST_TITLE=$(xmllint --xpath "string(/rss/channel/title)" "$RSS_FILE" 2>/dev/null)
if [ -z "$PODCAST_TITLE" ]; then
    # Try alternative XPath for different RSS formats
    PODCAST_TITLE=$(xmllint --xpath "string(/*[local-name()='rss']/*[local-name()='channel']/*[local-name()='title'])" "$RSS_FILE" 2>/dev/null)
fi

# If still empty, use a default name
if [ -z "$PODCAST_TITLE" ]; then
    PODCAST_TITLE="Unknown_Podcast_$(date +%Y%m%d)"
fi

# Sanitize podcast title for use as directory name
PODCAST_DIR_NAME=$(echo "$PODCAST_TITLE" | tr -cd '[:alnum:][:space:]' | tr '[:space:]' '_')
echo "📂 Podcast Title: $PODCAST_TITLE"

# Create podcast directory in podcast-transcripts
PODCAST_DIR="/Users/rahulnandakumar/Desktop/code/podscript/podcast-transcripts/$PODCAST_DIR_NAME"
mkdir -p "$PODCAST_DIR"
echo "📁 Created directory: $PODCAST_DIR"

# Extract episode information
echo "🔍 Extracting episode information..."

# Create a temporary file to store episode data
EPISODES_FILE="$TEMP_DIR/episodes.txt"

# Extract all enclosure URLs (audio files) along with titles and publication dates
# This uses xmllint to extract the data and formats it as: "title|pub_date|url"
xmllint --xpath "//*[local-name()='item']" "$RSS_FILE" 2>/dev/null | 
    grep -o '<title>.*</title>\|<pubDate>.*</pubDate>\|<enclosure [^>]*url="[^"]*"[^>]*>' |
    awk 'BEGIN {RS="<item>"; FS="\n"} 
    {
        title=""; pubDate=""; url="";
        for(i=1;i<=NF;i++) {
            if($i ~ /<title>/) {title=gensub(/<title>(.*)<\/title>/,"\\1","g",$i)}
            if($i ~ /<pubDate>/) {pubDate=gensub(/<pubDate>(.*)<\/pubDate>/,"\\1","g",$i)}
            if($i ~ /<enclosure/) {url=gensub(/.*url="([^"]*).*/,"\\1","g",$i)}
        }
        if(title != "" && url != "") {
            gsub(/\|/,"_",title);
            print title "|" pubDate "|" url
        }
    }' > "$EPISODES_FILE"

# Count episodes
EPISODE_COUNT=$(wc -l < "$EPISODES_FILE")
echo "🎙️ Found $EPISODE_COUNT episodes"

# Apply limit if specified
if [ -n "$LIMIT" ] && [ "$LIMIT" -gt 0 ] && [ "$LIMIT" -lt "$EPISODE_COUNT" ]; then
    echo "⚠️ Limiting to the newest $LIMIT episodes"
    # Sort by publication date (newest first) and take the first $LIMIT lines
    sort -t'|' -k2,2r "$EPISODES_FILE" | head -n "$LIMIT" > "$TEMP_DIR/limited_episodes.txt"
    mv "$TEMP_DIR/limited_episodes.txt" "$EPISODES_FILE"
    EPISODE_COUNT=$LIMIT
fi

# Process each episode
echo "🔄 Processing $EPISODE_COUNT episodes..."

COUNTER=1
while IFS="|" read -r TITLE PUB_DATE URL; do
    # Sanitize title for use as filename
    SAFE_TITLE=$(echo "$TITLE" | tr -cd '[:alnum:][:space:]' | tr '[:space:]' '_')
    
    # Add counter to ensure unique filenames
    EPISODE_NAME="${COUNTER}_${SAFE_TITLE}"
    
    echo "⏳ Processing episode $COUNTER/$EPISODE_COUNT: $TITLE"
    echo "🔗 URL: $URL"
    
    # Prepare transcribe_large_file.sh command
    TRANSCRIBE_CMD=("./examples/transcribe_large_file.sh" "$URL")
    
    # Add language if provided
    if [ -n "$LANGUAGE" ]; then
        TRANSCRIBE_CMD+=("--language" "$LANGUAGE")
    fi
    
    # Add prompt if provided
    if [ -n "$PROMPT" ]; then
        TRANSCRIBE_CMD+=("--prompt" "$PROMPT")
    fi
    
    # Run transcription
    echo "🎙️ Transcribing episode..."
    echo "🔄 Running command: ${TRANSCRIBE_CMD[@]}"
    
    # Run the transcription in the main directory to ensure proper paths
    (cd /Users/rahulnandakumar/Desktop/code/podscript && "${TRANSCRIBE_CMD[@]}")
    
    # Get the output filename from transcribe_large_file.sh (it's the basename of the URL with _transcript.txt)
    FILENAME=$(basename "$URL")
    TRANSCRIPT_FILE="${FILENAME%.*}_transcript.txt"
    
    # Move the transcript to the podcast directory with the sanitized name
    if [ -f "/Users/rahulnandakumar/Desktop/code/podscript/$TRANSCRIPT_FILE" ]; then
        mv "/Users/rahulnandakumar/Desktop/code/podscript/$TRANSCRIPT_FILE" "$PODCAST_DIR/${EPISODE_NAME}_transcript.txt"
        echo "✅ Transcript saved to: $PODCAST_DIR/${EPISODE_NAME}_transcript.txt"
    else
        echo "❌ Transcript file not found. There may have been an error in transcription."
    fi
    
    # Increment counter
    COUNTER=$((COUNTER + 1))
    
    echo "-------------------------------------------"
done < "$EPISODES_FILE"

echo "🎉 All episodes processed!"
echo "📂 Transcripts are saved in: $PODCAST_DIR"

# Create a metadata file with podcast information
echo "📝 Creating metadata file..."
METADATA_FILE="$PODCAST_DIR/podcast_info.txt"
{
    echo "Podcast Title: $PODCAST_TITLE"
    echo "RSS Feed: $RSS_URL"
    echo "Episodes Processed: $EPISODE_COUNT"
    echo "Processing Date: $(date)"
    echo "Language: ${LANGUAGE:-'Not specified'}"
    echo "Prompt: ${PROMPT:-'Not specified'}"
} > "$METADATA_FILE"

echo "✅ Metadata saved to: $METADATA_FILE"
echo "✅ All operations completed successfully"

# Log completion with detailed information
logger "podcast_transcriber.sh: Completed transcription of $EPISODE_COUNT episodes from '$PODCAST_TITLE'"
