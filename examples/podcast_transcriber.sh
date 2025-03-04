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
touch "$EPISODES_FILE"

# Use a more compatible approach to extract episode information
# First, save all item nodes to a temporary file
ITEMS_FILE="$TEMP_DIR/items.xml"
xmllint --xpath "//*[local-name()='item']" "$RSS_FILE" 2>/dev/null > "$ITEMS_FILE" || true

# Function to extract content between XML tags
extract_content() {
    local xml="$1"
    local tag="$2"
    local pattern="<$tag>([^<]*)</$tag>"
    
    if [[ $xml =~ $pattern ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Function to extract URL from enclosure tag
extract_url() {
    local xml="$1"
    local pattern="url=\"([^\"]*)\""
    
    if [[ $xml =~ $pattern ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Process the XML file to extract episodes
echo "" > "$EPISODES_FILE"

# Extract titles, enclosures, and publication dates separately
TITLES_FILE="$TEMP_DIR/titles.txt"
PUBDATES_FILE="$TEMP_DIR/pubdates.txt"
ENCLOSURES_FILE="$TEMP_DIR/enclosures.txt"

xmllint --xpath "//*[local-name()='item']/*[local-name()='title']/text()" "$RSS_FILE" 2>/dev/null | sed 's/|/_/g' > "$TITLES_FILE" || echo "" > "$TITLES_FILE"
xmllint --xpath "//*[local-name()='item']/*[local-name()='pubDate']/text()" "$RSS_FILE" 2>/dev/null > "$PUBDATES_FILE" || echo "" > "$PUBDATES_FILE"
xmllint --xpath "//*[local-name()='item']/*[local-name()='enclosure']/@url" "$RSS_FILE" 2>/dev/null | sed 's/url=//g' | sed 's/"//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' > "$ENCLOSURES_FILE" || echo "" > "$ENCLOSURES_FILE"

# Combine the extracted data
TITLE_COUNT=$(wc -l < "$TITLES_FILE")
ENCLOSURE_COUNT=$(wc -l < "$ENCLOSURES_FILE")
PUBDATE_COUNT=$(wc -l < "$PUBDATES_FILE")

# Use the minimum count to avoid index errors
MIN_COUNT=$(( TITLE_COUNT < ENCLOSURE_COUNT ? TITLE_COUNT : ENCLOSURE_COUNT ))
MIN_COUNT=$(( MIN_COUNT < PUBDATE_COUNT ? MIN_COUNT : PUBDATE_COUNT ))

for i in $(seq 1 $MIN_COUNT); do
    TITLE=$(sed -n "${i}p" "$TITLES_FILE")
    PUBDATE=$(sed -n "${i}p" "$PUBDATES_FILE")
    URL=$(sed -n "${i}p" "$ENCLOSURES_FILE")
    
    # Only add if we have both title and URL
    if [ -n "$TITLE" ] && [ -n "$URL" ]; then
        echo "$TITLE|$PUBDATE|$URL" >> "$EPISODES_FILE"
    fi
done

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
    # Skip empty lines
    if [ -z "$TITLE" ] || [ -z "$URL" ]; then
        continue
    fi
    
    # Trim leading and trailing whitespace from URL
    URL=$(echo "$URL" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
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
    # First, check for the expected filename pattern based on the current URL
    EXPECTED_TRANSCRIPT="downloaded_audio_transcript.txt"
    
    # Check if the expected transcript exists and was recently created (within the last 5 minutes)
    if [ -f "/Users/rahulnandakumar/Desktop/code/podscript/$EXPECTED_TRANSCRIPT" ] && 
       [ $(( $(date +%s) - $(stat -f %m "/Users/rahulnandakumar/Desktop/code/podscript/$EXPECTED_TRANSCRIPT") )) -lt 300 ]; then
        TRANSCRIPT_PATH="/Users/rahulnandakumar/Desktop/code/podscript/$EXPECTED_TRANSCRIPT"
        echo "✅ Found newly generated transcript at: $TRANSCRIPT_PATH"
    elif [ -f "/Users/rahulnandakumar/Desktop/code/podscript/$TRANSCRIPT_FILE" ]; then
        TRANSCRIPT_PATH="/Users/rahulnandakumar/Desktop/code/podscript/$TRANSCRIPT_FILE"
        echo "✅ Found transcript at: $TRANSCRIPT_PATH"
    else
        # If not found, try to find any recently created *_transcript.txt files in the main directory
        echo "🔍 Searching for recent transcript files..."
        TRANSCRIPT_PATH=$(find /Users/rahulnandakumar/Desktop/code/podscript -maxdepth 1 -name "*_transcript.txt" -type f -mmin -5 -print | head -n 1)
        
        if [ -z "$TRANSCRIPT_PATH" ]; then
            echo "❌ No recent transcript files found. There may have been an error in transcription."
            continue
        else
            echo "✅ Found recent transcript at: $TRANSCRIPT_PATH"
        fi
    fi
    
    # Now that we have a transcript file, process it
    if [ -f "$TRANSCRIPT_PATH" ]; then
        # Verify transcript content is relevant to the podcast
        echo "🔍 Verifying transcript content relevance..."
        
        # Extract podcast title keywords (excluding common words)
        TITLE_KEYWORDS=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' ' ' | tr -s ' ' | sed 's/\<and\>\|\<the\>\|\<a\>\|\<an\>\|\<in\>\|\<on\>\|\<of\>\|\<to\>\|\<for\>\|\<with\>\|\<by\>\|\<at\>\|\<from\>\|\<podcast\>//g' | tr -s ' ')
        
        # Check if at least one keyword from the title appears in the first 20 lines of the transcript
        CONTENT_RELEVANT=false
        for KEYWORD in $TITLE_KEYWORDS; do
            if [ "${#KEYWORD}" -gt 3 ] && head -n 20 "$TRANSCRIPT_PATH" | grep -i -q "$KEYWORD"; then
                CONTENT_RELEVANT=true
                echo "✅ Transcript content appears relevant to podcast topic"
                break
            fi
        done
        
        if [ "$CONTENT_RELEVANT" = false ]; then
            echo "⚠️ Warning: Transcript content may not be relevant to the podcast topic"
            echo "🔄 Attempting to re-transcribe..."
            
            # Re-download and transcribe the episode
            echo "💾 Re-downloading episode: $TITLE"
            ./examples/transcribe_large_file.sh "$URL" $LANGUAGE_OPT $PROMPT_OPT
            
            # Check if the new transcript was created
            if [ -f "/Users/rahulnandakumar/Desktop/code/podscript/downloaded_audio_transcript.txt" ]; then
                TRANSCRIPT_PATH="/Users/rahulnandakumar/Desktop/code/podscript/downloaded_audio_transcript.txt"
                echo "✅ Successfully re-transcribed episode"
            else
                echo "❌ Failed to re-transcribe episode. Using original transcript."
            fi
        fi
        
        # Use the episode title as the filename (sanitized)
        TRANSCRIPT_DEST="$PODCAST_DIR/${SAFE_TITLE}.txt"
        
        # Check if the transcript file is complete or has formatting issues
        if grep -q "^## Part [0-9]\+$" "$TRANSCRIPT_PATH"; then
            echo "🔄 Fixing transcript formatting..."
            
            # Create a temporary file for the fixed transcript
            FIXED_TRANSCRIPT="$TEMP_DIR/fixed_transcript.txt"
            
            # Extract the podcast title and date from the original transcript
            head -n 2 "$TRANSCRIPT_PATH" > "$FIXED_TRANSCRIPT"
            echo "" >> "$FIXED_TRANSCRIPT"
            
            # Check for repeated content in Part 4 (common issue)
            if grep -q "podcast podcast podcast podcast podcast" "$TRANSCRIPT_PATH"; then
                echo "⚠️ Detected repeated content issue, applying fix..."
                # Only include content up to the problematic part
                sed -n '/^## Part/,/^## Part 4$/p' "$TRANSCRIPT_PATH" | grep -v "^## Part 4$" > "$TEMP_DIR/clean_parts.txt"
                cat "$TEMP_DIR/clean_parts.txt" | grep -v "^## Part" >> "$FIXED_TRANSCRIPT"
            else
                # Extract and combine the content from each part, removing the part headers
                sed -n '/^## Part/,/^## Part\|^$/p' "$TRANSCRIPT_PATH" | grep -v "^## Part" >> "$FIXED_TRANSCRIPT"
            fi
            
            # Use the fixed transcript
            TRANSCRIPT_PATH="$FIXED_TRANSCRIPT"
        fi
        
        # Add episode information to the transcript
        FINAL_TRANSCRIPT="$TEMP_DIR/final_transcript.txt"
        {
            echo "# $TITLE"
            echo "# Publication Date: $PUB_DATE"
            echo "# Transcribed on: $(date)"
            echo "# Source: $URL"
            echo ""
            cat "$TRANSCRIPT_PATH"
        } > "$FINAL_TRANSCRIPT"
        
        # Move the transcript to its final destination
        mv "$FINAL_TRANSCRIPT" "$TRANSCRIPT_DEST"
        echo "✅ Transcript saved to: $TRANSCRIPT_DEST"
        
        # Cleanup any original transcript files to avoid confusion
        if [ "$TRANSCRIPT_PATH" != "$FIXED_TRANSCRIPT" ]; then
            rm -f "$TRANSCRIPT_PATH"
        fi
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
