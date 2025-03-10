use anyhow::Result;
use log::{debug, info};
use std::path::{Path, PathBuf};
use std::fs;

use crate::config::Config;
use crate::transcription::TranscriptionService;
use crate::utils;

/// Processor for local media files
pub struct LocalFileProcessor<'a> {
    /// Configuration for the processor
    config: &'a Config,
}

impl<'a> LocalFileProcessor<'a> {
    /// Create a new local file processor
    pub fn new(config: &'a Config) -> Self {
        Self { config }
    }
    
    /// Process a local media file
    /// 
    /// This function:
    /// 1. Validates the file exists and is a supported format
    /// 2. Creates an output directory for the transcription
    /// 3. Transcribes the file using the Whisper API
    /// 4. Saves the transcript to the output directory
    pub async fn process(&self, file_path: &str) -> Result<()> {
        // Convert string path to PathBuf
        let file_path = PathBuf::from(file_path);
        
        // Validate file exists
        if !file_path.exists() {
            return Err(anyhow::anyhow!("File does not exist: {:?}", file_path));
        }
        
        // Validate file is a supported format
        let extension = file_path.extension()
            .and_then(|ext| ext.to_str())
            .unwrap_or("");
            
        // Check if file is an MP3
        if extension.to_lowercase() != "mp3" {
            return Err(anyhow::anyhow!("Unsupported file format: {}", extension));
        }
        
        // Get file name for output directory
        let file_stem = file_path.file_stem()
            .and_then(|stem| stem.to_str())
            .unwrap_or("unknown");
            
        // Sanitize filename for directory name
        let sanitized_name = utils::sanitize_filename(file_stem);
        
        // Create output directory
        let output_dir = self.config.output_dir.join("local_files").join(&sanitized_name);
        fs::create_dir_all(&output_dir)?;
        
        // Save file info
        let file_info = format!(
            "File: {}\nSize: {} bytes\nTranscribed: {}",
            file_path.display(),
            fs::metadata(&file_path)?.len(),
            chrono::Local::now().to_rfc3339()
        );
        fs::write(output_dir.join("file_info.txt"), file_info)?;
        
        // Create transcript output path
        let transcript_path = output_dir.join("transcript.txt");
        
        // Create transcription service
        let transcription_service = TranscriptionService::new(self.config);
        
        // Transcribe the file
        info!("Transcribing local file: {:?}", file_path);
        transcription_service.transcribe_file(&file_path, &transcript_path).await?;
        
        info!("Transcription complete: {:?}", transcript_path);
        Ok(())
    }
    
    /// Check if a path is a local file path rather than a URL
    pub fn is_local_file_path(path: &str) -> bool {
        // Check if path starts with http:// or https://
        if path.starts_with("http://") || path.starts_with("https://") {
            return false;
        }
        
        // Check if path exists as a local file
        let path_buf = PathBuf::from(path);
        path_buf.exists() && path_buf.is_file()
    }
}
