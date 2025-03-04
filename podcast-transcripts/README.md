# Podcast Transcripts

This directory contains transcripts of podcasts processed using the `podcast_transcriber.sh` script.

## Directory Structure

Each podcast has its own subdirectory named after the podcast title. Within each podcast directory:

- `podcast_info.txt`: Contains metadata about the podcast and processing details
- Episode transcripts: Named in the format `[number]_[episode_title]_transcript.txt`

## Using the Podcast Transcriber

To transcribe all episodes from a podcast RSS feed:

```bash
./examples/podcast_transcriber.sh <rss_feed_url> [--language <lang>] [--prompt <prompt>] [--limit <num>]
```

### Arguments

- `rss_feed_url`: URL of the podcast RSS feed
- `--language <lang>`: (Optional) Language code (e.g., 'en' for English)
- `--prompt <prompt>`: (Optional) Context to improve transcription accuracy
- `--limit <num>`: (Optional) Limit the number of episodes to process (newest first)

### Example

```bash
./examples/podcast_transcriber.sh https://feeds.megaphone.fm/vergecast --language en --prompt "Tech news podcast" --limit 5
```

This will:
1. Download the RSS feed from the provided URL
2. Extract information about the podcast episodes
3. Process the 5 newest episodes
4. Transcribe each episode using OpenAI Whisper
5. Save the transcripts in a folder named after the podcast

## Notes

- The script uses `transcribe_large_file.sh` to handle audio files of any size
- Transcription may take some time depending on the length and number of episodes
- OpenAI API usage charges apply for each transcription
- Make sure your OpenAI API key is configured using `podscript configure`

## Troubleshooting

If you encounter issues:

1. Ensure you have all dependencies installed (curl, xmllint, ffmpeg)
2. Check that your OpenAI API key is properly configured
3. Verify the RSS feed URL is correct and accessible
4. For large podcasts, consider using the `--limit` option to test with fewer episodes first
