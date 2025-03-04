# Podscript Example Scripts

This directory contains example scripts that demonstrate how to use Podscript for various transcription scenarios.

## Basic Examples

- `whisper_example.sh`: Transcribe a local audio file using OpenAI Whisper
- `whisper_url_example.sh`: Download and transcribe audio from a URL

## Advanced Examples

### Handling Large Files

OpenAI's Whisper API has a 25MB file size limit. We provide several scripts to help you work with larger files:

1. **`transcribe_large_file.sh`**: Automatically splits large files into smaller chunks and transcribes them
   ```bash
   ./transcribe_large_file.sh https://example.com/large-podcast.mp3 --language en --prompt "Podcast about technology"
   ```

2. **`compress_audio.sh`**: Compresses audio files to reduce their size while maintaining reasonable quality
   ```bash
   ./compress_audio.sh large_podcast.mp3 64
   ```

3. **`download_and_transcribe.sh`**: Downloads audio from a URL and transcribes it
   ```bash
   ./download_and_transcribe.sh https://example.com/podcast.mp3 --language en --prompt "Podcast about science"
   ```

### Podcast Processing

4. **`podcast_transcriber.sh`**: Downloads and transcribes all episodes from a podcast RSS feed
   ```bash
   ./podcast_transcriber.sh https://example.com/podcast.rss --language en --prompt "Tech podcast" --limit 5
   ```
   
   This script:
   - Parses a podcast RSS feed to extract episode information
   - Downloads and transcribes each episode using `transcribe_large_file.sh`
   - Organizes transcripts in the `podcast-transcripts` directory
   - Creates metadata files with podcast information

### Configuration Examples

- **`transcribe_with_config.sh`**: Explicitly loads the OpenAI API key from the configuration file
   ```bash
   ./transcribe_with_config.sh https://example.com/podcast.mp3 --language en --prompt "Podcast about history"
   ```

## Usage Tips

1. Make scripts executable before running them:
   ```bash
   chmod +x script_name.sh
   ```

2. All scripts support optional language and prompt parameters using named arguments:
   ```bash
   ./script_name.sh input_file.mp3 --language en --prompt "Context for better transcription"
   ```

3. For URL-based scripts, the audio will be downloaded to a temporary location and cleaned up automatically

4. Transcripts are saved to the current working directory by default

## Dependencies

Some scripts require additional tools:

- **ffmpeg**: Required for `transcribe_large_file.sh` and `compress_audio.sh`
  ```bash
  # Install on macOS
  brew install ffmpeg
  
  # Install on Ubuntu
  sudo apt-get install ffmpeg
  ```

## Troubleshooting

If you encounter issues:

1. Check that your OpenAI API key is correctly configured
2. Ensure all dependencies are installed
3. Verify that the audio file is in a supported format
4. For large files, try using `compress_audio.sh` first before attempting to transcribe

## Additional Resources

For more information, see the documentation:

- `docs/openai_whisper.md`: General usage of OpenAI Whisper with Podscript
- `docs/handling_large_files.md`: Detailed guide on working with large audio files
