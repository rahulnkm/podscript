# Media Transcriber

The `media_transcriber.sh` script is a unified tool for downloading and transcribing content from multiple sources using OpenAI's Whisper API:

1. Podcast RSS feeds - transcribing all episodes from a podcast
2. YouTube videos - transcribing individual videos
3. YouTube channels/playlists - transcribing all videos from a channel or playlist
4. Multiple sources at once - processing a list of feeds/channels/videos

## Features

- Single unified script for all media transcription needs
- Automatic detection of source type (podcast or YouTube)
- Support for language specification and prompt context
- Limit option to control the number of episodes/videos processed
- Organized transcript storage with metadata
- API key handling with multiple configuration options

## Prerequisites

- OpenAI API key for Whisper transcription
- Required tools:
  - `curl` - For downloading files
  - `xmllint` - For parsing XML/RSS feeds
  - `ffmpeg` - For audio processing
  - `yt-dlp` - For YouTube video/channel processing

## Installation

1. Install the required dependencies:

   ```bash
   # On macOS
   brew install curl libxml2 ffmpeg
   pip install yt-dlp
   
   # On Ubuntu/Debian
   sudo apt-get install curl libxml2-utils ffmpeg
   pip install yt-dlp
   ```

2. Make the script executable:

   ```bash
   chmod +x examples/media_transcriber.sh
   ```

## Usage

```bash
./examples/media_transcriber.sh [--source <url>] [--file <sources_file>] [--language <lang>] [--prompt <prompt>] [--limit <num>] [--api-key <key>]
```

### Arguments

- `--source <url>`: URL of a podcast RSS feed or YouTube channel/video
- `--file <sources_file>`: File containing a list of sources (one URL per line)
- `--language <lang>`: (Optional) Language code (e.g., 'en' for English)
- `--prompt <prompt>`: (Optional) Context to improve transcription accuracy
- `--limit <num>`: (Optional) Limit the number of episodes/videos to process
- `--api-key <key>`: (Optional) OpenAI API key for transcription

### Examples

#### Process a podcast RSS feed:

```bash
./examples/media_transcriber.sh --source https://feeds.megaphone.fm/vergecast --language en --prompt "Tech news podcast" --limit 5
```

#### Process a YouTube video:

```bash
./examples/media_transcriber.sh --source "https://www.youtube.com/watch?v=example" --language en
```

#### Process multiple sources from a file:

```bash
./examples/media_transcriber.sh --file examples/sample_sources.txt --language en --limit 3
```

## Output

Transcripts are saved in the `transcripts` directory, organized by podcast/channel name:

```
transcripts/
├── The_Vergecast_/
│   ├── Episode_Title_1.txt
│   ├── Episode_Title_2.txt
│   └── podcast_info.txt
└── YouTube_Channel_Name/
    ├── Video_Title_1.txt
    ├── Video_Title_2.txt
    └── channel_info.txt
```

## API Key Configuration

You can provide your OpenAI API key in several ways:

1. **Command-line option**: `--api-key <your-api-key>`
2. **Environment variable**: `export OPENAI_API_KEY=your-api-key`
3. **.env file**: Create a `.env` file in the project root with `OPENAI_API_KEY=your-api-key`

## Troubleshooting

- Ensure you have all dependencies installed
- Check that your OpenAI API key is properly configured
- Verify the URL is correct and accessible
- For large files, the script automatically handles splitting
