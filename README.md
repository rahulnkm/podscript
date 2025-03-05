# Media Transcriber

A streamlined tool to transcribe any audio or video media from various sources using OpenAI's Whisper API. This tool can process podcast RSS feeds, YouTube videos, YouTube channels, and more.

## Overview

This tool provides high-performance transcription services using a Rust implementation that:

- Processes podcast RSS feeds - downloading and transcribing all episodes
- Processes YouTube videos - transcribing individual videos
- Processes YouTube channels/playlists - transcribing all videos from a channel
- Processes multiple sources at once from a sources file

All transcriptions are performed using OpenAI's Whisper API, which provides high-quality multilingual transcription.

## Installation

```shell
# Clone the repository
git clone https://github.com/deepakjois/podscript.git
cd podscript

# Navigate to the rust-transcriber directory
cd rust-transcriber

# Run the installation script (installs Rust if needed)
./install_rust.sh

# Alternatively, if you already have Rust installed:
cargo build --release
```

## Getting Started

```bash
# Navigate to the rust-transcriber directory
cd rust-transcriber

# Process a podcast RSS feed
./target/release/media-transcriber --source https://example.com/podcast.rss

# Process a YouTube video
./target/release/media-transcriber --source https://www.youtube.com/watch?v=VIDEO_ID

# Process with language and prompt specification
./target/release/media-transcriber --source URL --language en --prompt "Tech podcast"

# Process multiple sources from a file
./target/release/media-transcriber --file sources.txt
```

## Rust Implementation Features

The Rust implementation offers excellent performance characteristics:

```bash
# Navigate to the rust-transcriber directory
cd rust-transcriber

# Run the transcriber with various options
./target/release/media-transcriber --source <url> [options]
```

Key benefits:
- **Higher Performance**: Faster processing and better multithreading
- **Better Memory Management**: More efficient handling of large files
- **Improved Error Handling**: Robust recovery from transient failures
- **Consistent Behavior**: Reliable operation across different platforms

## Requirements

- OpenAI API key for Whisper transcription
- Rust 1.56.0 or later (installed via the provided script)
- Dependencies:
  - ffmpeg (for audio processing)
  - yt-dlp (for YouTube sources)

## API Key Configuration

The implementation supports multiple API key sources (in order of precedence):

1. **Command-line option**: `--api-key YOUR_API_KEY`
2. **Environment variable**: `OPENAI_API_KEY=YOUR_API_KEY`
3. **.env file**: In the current directory, parent directory, or podscript subdirectory

## Large File Handling

The implementation handles audio files exceeding the 25MB Whisper API limit by:
1. Splitting files into smaller chunks
2. Transcribing each chunk separately
3. Combining the results into a single transcript

This offers efficient processing of large files with excellent parallelization and memory management.

## Output Structure

Transcripts are organized in a consistent directory structure:

```
podcast-transcripts/
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

## Troubleshooting

### Common Issues

1. **API Key Not Found**: Ensure your OpenAI API key is correctly set using one of the methods described above.

2. **Dependencies Missing**: Verify that all required dependencies are installed:
   ```bash
   # Check ffmpeg installation
   ffmpeg -version
   
   # Check yt-dlp installation
   yt-dlp --version
   ```

3. **File Format Issues**: Ensure your audio files are in a format supported by ffmpeg (MP3, WAV, M4A, etc.).

4. **Compilation Errors**: If you encounter compilation errors, ensure your Rust toolchain is up-to-date:
   ```bash
   rustup update
   ```

5. **Running from Wrong Directory**: Make sure to run the Rust binary from within the rust-transcriber directory or specify the full path.

## License

[MIT](https://github.com/deepakjois/podscript/raw/main/LICENSE)
