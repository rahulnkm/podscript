# Rust Media Transcriber

A fast, efficient implementation of the media transcription functionality in Rust.

## Overview

This Rust implementation provides a high-performance alternative to the bash script for transcribing media from various sources:

- Podcast RSS feeds
- YouTube videos
- YouTube channels/playlists
- Multiple sources from a file

## Features

- **High Performance**: Optimized for speed and efficiency
- **Flexible Source Support**: Process podcasts and YouTube content
- **Large File Handling**: Automatically splits files larger than 25MB
- **Organized Output**: Structured directory hierarchy for transcripts
- **Robust Error Handling**: Comprehensive error reporting and recovery
- **Multiple API Key Methods**: Command-line, environment variable, or .env file

## Requirements

- Rust (1.56.0 or later)
- OpenAI API key
- External dependencies:
  - ffmpeg
  - yt-dlp (for YouTube sources)

## Building

```bash
cd rust-transcriber
cargo build --release
```

## Usage

```bash
# Process a podcast RSS feed
./target/release/media-transcriber --source https://example.com/podcast.rss

# Process a YouTube video
./target/release/media-transcriber --source https://www.youtube.com/watch?v=VIDEO_ID

# Process a YouTube channel
./target/release/media-transcriber --source https://www.youtube.com/c/CHANNEL_NAME

# Process multiple sources from a file
./target/release/media-transcriber --file sources.txt

# Specify language and prompt
./target/release/media-transcriber --source URL --language en --prompt "This is a podcast about technology"

# Limit the number of episodes/videos
./target/release/media-transcriber --source URL --limit 5

# Specify API key
./target/release/media-transcriber --source URL --api-key YOUR_API_KEY

# Specify output directory
./target/release/media-transcriber --source URL --output-dir my-transcripts
```

## API Key Configuration

The API key can be provided in several ways (in order of precedence):

1. Command-line option: `--api-key YOUR_API_KEY`
2. Environment variable: `OPENAI_API_KEY=YOUR_API_KEY`
3. `.env` file in the current directory, parent directory, or podscript subdirectory

## Output Structure

Transcripts are organized in the following directory structure:

```
transcripts/
├── Podcast_Name/
│   ├── podcast_info.txt
│   ├── Episode_Title_1/
│   │   └── transcript.txt
│   └── Episode_Title_2/
│       └── transcript.txt
└── YouTube_Channel/
    ├── channel_info.txt
    ├── Video_Title_1/
    │   ├── video_info.txt
    │   └── transcript.txt
    └── Video_Title_2/
        ├── video_info.txt
        └── transcript.txt
```

## Performance Comparison

The Rust implementation offers significant performance improvements over the bash script:

- Faster processing of large files
- More efficient memory usage
- Better parallelization of tasks
- Improved error handling and recovery

## License

MIT
