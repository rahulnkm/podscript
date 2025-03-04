# Using OpenAI's Whisper API with Podscript

This document explains how to use OpenAI's Whisper speech-to-text model with Podscript.

## Overview

OpenAI's Whisper is a powerful speech recognition model that can transcribe audio in multiple languages. Podscript now includes direct integration with the Whisper API, allowing you to easily transcribe audio files.

## Prerequisites

- An OpenAI API key (get one at [https://platform.openai.com/api-keys](https://platform.openai.com/api-keys))
- Audio file in a supported format (mp3, mp4, mpeg, mpga, m4a, wav, or webm)
- File size must be under 25MB (see [Handling Large Files](#handling-large-files) for larger files)

## Configuration

Set your OpenAI API key in one of the following ways:

1. Using environment variables:
   ```bash
   export OPENAI_API_KEY="your-openai-api-key"
   ```

2. Using the `.env` file:
   ```
   OPENAI_API_KEY = "your-openai-api-key"
   ```

3. Using the configuration command:
   ```bash
   podscript configure
   ```
   This will prompt you for your OpenAI API key and save it to `~/.podscript.toml`.

## Basic Usage

Transcribe an audio file using the default settings:

```bash
podscript open-ai-whisper your-audio-file.mp3
```

Save the transcription to a file:

```bash
podscript open-ai-whisper your-audio-file.mp3 --output transcript.txt
```

## Advanced Options

### Model Selection

Whisper offers different models with varying levels of accuracy:

```bash
podscript open-ai-whisper your-audio-file.mp3 --model whisper-1
```

Available models:
- `whisper-1` (default): Latest model with best quality

### Language Specification

Specify the language of the audio for better accuracy:

```bash
podscript open-ai-whisper your-audio-file.mp3 --language en
```

### Context Prompting

Provide context to improve transcription accuracy:

```bash
podscript open-ai-whisper your-audio-file.mp3 --prompt "This is a podcast about artificial intelligence"
```

### Output Format

Choose the output format:

```bash
podscript open-ai-whisper your-audio-file.mp3 --response-format srt
```

Available formats:
- `text` (default): Plain text
- `json`: JSON format
- `srt`: SubRip subtitle format
- `vtt`: WebVTT subtitle format
- `verbose_json`: Detailed JSON with timestamps

### Temperature Control

Adjust the randomness of the transcription:

```bash
podscript open-ai-whisper your-audio-file.mp3 --temperature 0.2
```

Temperature range: 0.0 (deterministic) to 1.0 (more random), default is 0.

## Handling Large Files

The OpenAI Whisper API has a 25MB file size limit. For larger files, Podscript provides several solutions:

### Using the Large File Transcription Script

```bash
./examples/transcribe_large_file.sh your-large-audio-file.mp3 --language en --prompt "Optional context"
```

This script will:
1. Check if the file exceeds 25MB
2. Split the file into smaller chunks if necessary
3. Transcribe each chunk separately
4. Combine all transcripts into a single output file

### Compressing Audio Files

Alternatively, you can reduce the file size using the compression utility:

```bash
./examples/compress_audio.sh your-large-audio-file.mp3 --bitrate 64k
```

See `docs/handling_large_files.md` for more detailed information.

## Technical Implementation

### Response Format Handling

Podscript implements two different approaches for handling OpenAI Whisper API responses:

1. **JSON Formats** (`json`, `verbose_json`):
   - Uses the OpenAI Go SDK's structured client
   - Returns a parsed JSON response with the transcription text

2. **Non-JSON Formats** (`text`, `srt`, `vtt`):
   - Implements a direct HTTP multipart form request
   - Bypasses the SDK's limitations with non-JSON responses
   - Handles the raw response text directly

This dual approach ensures reliable handling of all response formats and avoids type conversion errors.

## Examples

### Podcast Transcription

```bash
podscript open-ai-whisper podcast.mp3 --language en --prompt "Tech podcast discussing AI developments"
```

### Multi-speaker Meeting

```bash
podscript open-ai-whisper meeting.mp3 --response-format verbose_json
```

### Subtitle Generation

```bash
podscript open-ai-whisper video.mp4 --response-format srt --output subtitles.srt
```

### Transcribing from URL

To transcribe audio from a URL, you'll need to download the file first. We've provided a helper script for this purpose:

```bash
# Download and transcribe from URL
./examples/whisper_url_example.sh https://example.com/podcast.mp3
```

The script will:
1. Download the audio file from the URL
2. Save it to a temporary location
3. Transcribe it using the OpenAI Whisper API
4. Save the transcript to a file named after the original audio file
5. Clean up the temporary files

## Troubleshooting

### API Key Issues

If you encounter authentication errors, check that your API key is correctly set and has sufficient permissions.

### File Size Limitations

OpenAI's Whisper API has a 25MB file size limit. If your file exceeds this limit, you have several options:

1. **Use our specialized script for large files**:
   ```bash
   ./examples/transcribe_large_file.sh https://example.com/large-podcast.mp3
   ```
   This script automatically:
   - Checks if the file exceeds the 25MB limit
   - Splits large files into smaller chunks using ffmpeg
   - Transcribes each chunk separately
   - Combines all transcripts into a single output file
   
   See `docs/handling_large_files.md` for more details.

2. **Compress the audio manually**:
   ```bash
   ffmpeg -i input.mp3 -b:a 64k compressed.mp3
   ```

3. **Split it into smaller segments manually**:
   ```bash
   ffmpeg -i input.mp3 -f segment -segment_time 600 -c copy output_%03d.mp3
   ```

4. **Use a different format** (mp3 is typically more compact than wav)

### Audio Quality Issues

For better transcription results:
1. Use high-quality audio sources
2. Reduce background noise
3. Specify the correct language
4. Provide relevant context in the prompt

## Comparing with Other Services

Podscript supports multiple transcription services:

| Service | Command | Strengths |
|---------|---------|-----------|
| OpenAI Whisper | `open-ai-whisper` | High accuracy, multilingual support |
| Groq | `groq` | Fast processing, similar model |
| Deepgram | `deepgram` | Real-time capabilities, specialized models |
| AssemblyAI | `assemblyai` | Speaker diarization, sentiment analysis |

Choose the service that best fits your specific needs and budget constraints.
