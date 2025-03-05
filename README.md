# Media Transcriber

A streamlined tool to transcribe any audio or video media from various sources using OpenAI's Whisper API. This tool can process podcast RSS feeds, YouTube videos, YouTube channels, and more.

## Overview

This tool provides a single unified script that can:

1. Process podcast RSS feeds - downloading and transcribing all episodes
2. Process YouTube videos - transcribing individual videos
3. Process YouTube channels/playlists - transcribing all videos from a channel
4. Process multiple sources at once from a sources file

All transcriptions are performed using OpenAI's Whisper API, which provides high-quality multilingual transcription.

## Installation

```shell
# Clone the repository
git clone https://github.com/deepakjois/podscript.git
cd podscript

# Build the binary
go build -o podscript
```

## Getting Started

```bash
# Configure your OpenAI API key
./podscript configure

# Transcribe a YouTube video
./podscript ytt https://www.youtube.com/watch?v=example

# Transcribe audio using OpenAI's Whisper API
./podscript openai-whisper --file interview.mp3 --language en
```

## Media Transcriber Script

The `media_transcriber.sh` script in the examples directory provides a comprehensive solution for batch processing media from various sources:

```bash
./examples/media_transcriber.sh [--source <url>] [--file <sources_file>] [--language <lang>] [--prompt <prompt>] [--limit <num>] [--api-key <key>]
```

### Examples:

```bash
# Process a podcast RSS feed
./examples/media_transcriber.sh --source https://feeds.megaphone.fm/vergecast --language en --prompt "Tech podcast" --limit 5

# Process a YouTube video
./examples/media_transcriber.sh --source "https://www.youtube.com/watch?v=example" --language en

# Process multiple sources from a file
./examples/media_transcriber.sh --file examples/sample_sources.txt --language en --limit 3
```

## Requirements

- OpenAI API key for Whisper transcription
- Dependencies:
  - curl, xmllint, ffmpeg (for all sources)
  - yt-dlp (for YouTube sources)

## API Key Configuration

You can provide your OpenAI API key in several ways:

1. **Command-line option**: `--api-key <your-api-key>`
2. **Environment variable**: `export OPENAI_API_KEY=your-api-key`
3. **.env file**: Create a `.env` file in the project root with `OPENAI_API_KEY=your-api-key`
4. **Configuration command**: Run `./podscript configure` to set up your API key

## Large File Handling

For audio files exceeding the 25MB Whisper API limit, the script automatically:
1. Splits files into smaller chunks
2. Transcribes each chunk separately
3. Combines the results into a single transcript

## License

[MIT](https://github.com/deepakjois/podscript/raw/main/LICENSE)
