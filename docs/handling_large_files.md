# Handling Large Audio Files with OpenAI Whisper

OpenAI's Whisper API has a file size limit of 25MB. This document explains how to handle audio files that exceed this limit.

## Size Limitations

- **OpenAI Whisper API Limit**: 25MB (26,214,400 bytes)
- **Supported File Formats**: mp3, mp4, mpeg, mpga, m4a, wav, webm

## Solutions for Large Files

### 1. Using the `transcribe_large_file.sh` Script

We've created a script that automatically handles large files by:
1. Checking the file size
2. For files under 25MB: Transcribing directly
3. For files over 25MB: Splitting into smaller chunks, transcribing each chunk, and combining the results

#### Prerequisites

- ffmpeg (for audio splitting)
  ```bash
  # macOS
  brew install ffmpeg
  
  # Ubuntu
  sudo apt-get install ffmpeg
  ```

#### Usage

```bash
./examples/transcribe_large_file.sh <audio_url> [language] [prompt]
```

**Arguments:**
- `audio_url`: URL of the audio file to download and transcribe
- `language` (Optional): Language code (e.g., 'en' for English)
- `prompt` (Optional): Context to improve transcription accuracy

**Example:**
```bash
./examples/transcribe_large_file.sh https://example.com/podcast.mp3 en "Tech podcast about AI"
```

### 2. Manual Compression

If you prefer to handle large files manually, you can compress them first:

```bash
# Compress an MP3 file to a lower bitrate
ffmpeg -i input.mp3 -b:a 64k compressed.mp3

# Check the new file size
ls -lh compressed.mp3
```

### 3. Manual Splitting

You can also manually split a large file:

```bash
# Split a file into 10-minute segments
ffmpeg -i input.mp3 -f segment -segment_time 600 -c copy output_%03d.mp3
```

## Best Practices

1. **Pre-process Audio Files**: Consider compressing or converting files before transcription
2. **Use Chunking for Long Content**: Breaking audio into logical segments can improve transcription quality
3. **Provide Language and Context**: Use the `--language` and `--prompt` options for better results

## Troubleshooting

### Common Errors

- **413 Request Entity Too Large**: This means your file exceeds the 25MB limit
  ```
  413: Maximum content size limit (26214400) exceeded
  ```

- **File Format Issues**: Ensure you're using a supported format (mp3, mp4, mpeg, mpga, m4a, wav, webm)

- **Response Format Errors**: When using non-JSON response formats, you might encounter errors like:
  ```
  expected destination type of 'string' or '[]byte' for responses with content-type that is not 'application/json'
  ```
  This has been fixed in the latest version by implementing a direct HTTP request for non-JSON formats.

### Solutions

1. Check file size: `ls -lh your_file.mp3`
2. Compress the file: `ffmpeg -i your_file.mp3 -b:a 64k compressed.mp3`
3. Use the `transcribe_large_file.sh` script for automatic handling
4. For response format issues, ensure you're using the latest version of podscript

## Technical Implementation

### Response Format Handling

The OpenAI Whisper integration uses two different approaches based on the response format:

1. **JSON Formats** (`json`, `verbose_json`):
   - Uses the OpenAI Go SDK's structured client
   - Returns a parsed JSON response with the transcription text

2. **Non-JSON Formats** (`text`, `srt`, `vtt`):
   - Implements a direct HTTP multipart form request
   - Bypasses the SDK's limitations with non-JSON responses
   - Handles the raw response text directly

This dual approach ensures reliable handling of all response formats.

## Performance Considerations

- Splitting files adds processing time but enables transcription of files of any size
- Lower quality audio may result in less accurate transcriptions
- Consider the trade-off between file size and audio quality
- Direct HTTP implementation for non-JSON formats may be slightly faster than using the SDK

## Security Notes

- The script creates temporary files that are automatically cleaned up
- API keys are read from your configuration file and not stored in the script
