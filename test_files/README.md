# Testing MP3 Transcription

This directory contains test MP3 files for the local file transcription feature.

## How to Use

1. Place your MP3 files in this directory
2. Run the transcription command:

```bash
# Navigate to the media-transcriber directory
cd ../media-transcriber

# Run the transcriber with a local MP3 file
./target/release/media-transcriber --source /path/to/your/audio.mp3

# Example with a file in this directory
./target/release/media-transcriber --source ../test_files/sample.mp3
```

## Expected Output

The transcripts will be saved in the `transcripts/local_files/` directory, organized by filename.

For example, if you transcribe a file named `sample.mp3`, the transcript will be saved at:
```
transcripts/local_files/sample/transcript.txt
```

## Troubleshooting

If you encounter any issues:

1. Make sure the file exists and is a valid MP3 file
2. Check that you have set your OpenAI API key correctly
3. Verify that ffmpeg is installed on your system

## Notes

- Files larger than 25MB will be automatically split into smaller chunks for transcription
- The transcription uses OpenAI's Whisper API for high-quality results
