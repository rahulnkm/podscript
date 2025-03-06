use anyhow::Result;
use log::{debug, info};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use tempfile::tempdir;

use crate::config::Config;
use crate::utils;

/// Transcription service for audio files
pub struct TranscriptionService<'a> {
    config: &'a Config,
}

/// Transcription request parameters
#[derive(Debug, Serialize)]
struct TranscriptionRequest {
    file: PathBuf,
    model: String,
    language: Option<String>,
    prompt: Option<String>,
    response_format: String,
    temperature: f32,
}

/// Transcription response
#[derive(Debug, Deserialize)]
struct TranscriptionResponse {
    text: String,
}

impl<'a> TranscriptionService<'a> {
    /// Create a new transcription service
    pub fn new(config: &'a Config) -> Self {
        Self { config }
    }
    
    /// Transcribe an audio file
    pub async fn transcribe_file(&self, audio_file: &Path, output_file: &Path) -> Result<()> {
        info!("Transcribing audio file: {:?}", audio_file);
        
        // Check if file exists
        if !audio_file.exists() {
            return Err(anyhow::anyhow!("Audio file does not exist: {:?}", audio_file));
        }
        
        // Check file size
        let file_size = fs::metadata(audio_file)?.len();
        debug!("Audio file size: {} bytes", file_size);
        
        // OpenAI's limit is 25MB
        const MAX_SIZE: u64 = 25 * 1024 * 1024;
        
        if file_size <= MAX_SIZE {
            // File is small enough, transcribe directly
            self.transcribe_single_file(audio_file, output_file).await?;
        } else {
            // File is too large, split and transcribe in chunks
            self.transcribe_large_file(audio_file, output_file).await?;
        }
        
        Ok(())
    }
    
    /// Transcribe a single audio file (less than 25MB)
    async fn transcribe_single_file(&self, audio_file: &Path, output_file: &Path) -> Result<()> {
        info!("Direct transcription of file: {:?}", audio_file);
        
        // Create output directory if it doesn't exist
        if let Some(parent) = output_file.parent() {
            fs::create_dir_all(parent)?;
        }
        
        // Use podscript command for transcription
        let mut args = vec![
            "open-ai-whisper",
            audio_file.to_str().unwrap(),
            "--output", output_file.to_str().unwrap(),
        ];
        
        // Add language if provided
        if let Some(lang) = &self.config.language {
            args.extend_from_slice(&["--language", lang]);
        }
        
        // Add prompt if provided
        if let Some(prompt) = &self.config.prompt {
            args.extend_from_slice(&["--prompt", prompt]);
        }
        
        // Set environment variable for API key
        // Use the podscript binary from the parent directory
        let mut command = Command::new("../podscript");
        command.args(&args)
               .env("OPENAI_API_KEY", &self.config.api_key);
        
        let output = command.output()?;
        
        if !output.status.success() {
            return Err(anyhow::anyhow!(
                "Transcription failed: {}",
                String::from_utf8_lossy(&output.stderr)
            ));
        }
        
        info!("Transcription completed successfully: {:?}", output_file);
        Ok(())
    }
    
    /// Transcribe a large audio file by splitting it into chunks
    async fn transcribe_large_file(&self, audio_file: &Path, output_file: &Path) -> Result<()> {
        info!("Splitting and transcribing large file: {:?}", audio_file);
        
        // Create temporary directory for chunks
        let temp_dir = tempdir()?;
        let chunks_dir = temp_dir.path().join("chunks");
        let transcripts_dir = temp_dir.path().join("transcripts");
        
        fs::create_dir_all(&chunks_dir)?;
        fs::create_dir_all(&transcripts_dir)?;
        
        // Split audio file into chunks (20MB each)
        let chunk_files = utils::split_audio_file(audio_file, &chunks_dir, 1000)?;
        
        // Transcribe each chunk
        let mut all_transcripts = String::new();
        
        for (i, chunk_file) in chunk_files.iter().enumerate() {
            let transcript_file = transcripts_dir.join(format!("transcript_{}.txt", i + 1));
            
            info!("Transcribing chunk {}/{}", i + 1, chunk_files.len());
            self.transcribe_single_file(chunk_file, &transcript_file).await?;
            
            // Read transcript and append to combined transcript
            let transcript = fs::read_to_string(&transcript_file)?;
            all_transcripts.push_str(&transcript);
            all_transcripts.push_str("\n\n");
        }
        
        // Write combined transcript to output file
        if let Some(parent) = output_file.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(output_file, all_transcripts.trim())?;
        
        info!("Combined transcript saved to: {:?}", output_file);
        Ok(())
    }
}
