# Media Transcription Scripts

This directory contains scripts for transcribing media from various sources using OpenAI's Whisper API.

## Main Script

### Media Transcriber

**`media_transcriber.sh`**: A comprehensive script that can process podcasts, YouTube videos, and YouTube channels

```bash
./media_transcriber.sh --source <url> [--language <lang>] [--prompt <prompt>] [--limit <num>] [--api-key <key>]
```

This script:
- Automatically detects the source type (podcast or YouTube)
- Downloads and transcribes content
- Organizes transcripts in the `transcripts` directory
- Creates metadata files with source information

#### Examples:

```bash
# Process a podcast RSS feed
./media_transcriber.sh --source https://feeds.megaphone.fm/vergecast --language en --prompt "Tech podcast" --limit 5

# Process a YouTube video
./media_transcriber.sh --source "https://www.youtube.com/watch?v=example" --language en

# Process multiple sources from a file
./media_transcriber.sh --file sample_sources.txt --language en --limit 3
```

## Supporting Scripts

1. **`transcribe_large_file.sh`**: Handles large audio files by splitting them into smaller chunks
   ```bash
   ./transcribe_large_file.sh large-podcast.mp3 --language en --prompt "Podcast about technology"
   ```

2. **`compress_audio.sh`**: Compresses audio files to reduce their size
   ```bash
   ./compress_audio.sh large_podcast.mp3 64
   ```

## Usage Tips

1. Make scripts executable before running them:
   ```bash
   chmod +x script_name.sh
   ```

2. All scripts support optional language and prompt parameters:
   ```bash
   ./script_name.sh input_file.mp3 --language en --prompt "Context for better transcription"
   ```

## Dependencies

- **curl, xmllint, ffmpeg**: Required for all sources
- **yt-dlp**: Required for YouTube sources (`pip install yt-dlp`)

## Troubleshooting

If you encounter issues:

1. Check that your OpenAI API key is correctly configured
2. Ensure all dependencies are installed
3. Verify that the URL or file is accessible
4. For large files, the script automatically handles splitting
