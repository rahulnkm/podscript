# Media Transcripts

This directory contains transcripts of podcasts and YouTube videos processed using the `media_transcriber.sh` script.

## Directory Structure

Each media source has its own subdirectory named after the podcast or YouTube channel title:

### For Podcasts:
- `podcast_info.txt`: Contains metadata about the podcast and processing details
- Episode transcripts: Named after the episode title

### For YouTube Channels/Videos:
- `channel_info.txt`: Contains metadata about the YouTube channel and processing details
- Video transcripts: Named after the video title

## Using the Media Transcriber

The `media_transcriber.sh` script can process both podcast RSS feeds and YouTube videos/channels. It uses OpenAI's Whisper for all transcription tasks, providing high-quality results.

### Prerequisites

- An OpenAI API key (set via `podscript configure` or the `OPENAI_API_KEY` environment variable)
- For YouTube sources: `yt-dlp` installed (`pip install yt-dlp`)
- For podcast sources: `xmllint` and `ffmpeg` installed

```bash
./examples/media_transcriber.sh [--source <url>] [--file <sources_file>] [--language <lang>] [--prompt <prompt>] [--limit <num>] [--api-key <key>]
```

### Arguments

- `--source <url>`: URL of a podcast RSS feed or YouTube channel/video
- `--file <sources_file>`: File containing a list of sources (one URL per line)
- `--language <lang>`: (Optional) Language code (e.g., 'en' for English)
- `--prompt <prompt>`: (Optional) Context to improve transcription accuracy
- `--limit <num>`: (Optional) Limit the number of episodes/videos to process (newest first)
- `--api-key <key>`: (Optional) OpenAI API key for transcription

### Examples

#### Processing a podcast:
```bash
./examples/media_transcriber.sh --source https://feeds.megaphone.fm/vergecast --language en --prompt "Tech news podcast" --limit 5
```

#### Processing a YouTube video:
```bash
./examples/media_transcriber.sh --source "https://www.youtube.com/watch?v=dQw4w9WgXcQ" --language en
```

#### Processing multiple sources from a file:
```bash
./examples/media_transcriber.sh --file examples/sample_sources.txt --language en --limit 3
```

## Notes

- For podcasts, the script handles audio files of any size by splitting them into smaller chunks
- Transcription may take some time depending on the length and number of episodes/videos
- OpenAI API usage charges apply for each transcription

## Troubleshooting

If you encounter issues:

1. Ensure you have all dependencies installed:
   - For podcasts: curl, xmllint, ffmpeg
   - For YouTube: curl, yt-dlp, ffmpeg
2. Check that your OpenAI API key is properly configured
3. Verify the URL is correct and accessible
4. For large collections, consider using the `--limit` option to test with fewer items first
