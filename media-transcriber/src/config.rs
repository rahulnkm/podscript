use anyhow::{Context, Result};
use dotenv::dotenv;
use log::{debug, info};
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use thiserror::Error;

/// Configuration errors
#[derive(Error, Debug)]
pub enum ConfigError {
    #[error("API key not found. Please set OPENAI_API_KEY environment variable or use --api-key option")]
    ApiKeyNotFound,
}

/// Configuration for the media transcriber
pub struct Config {
    /// OpenAI API key
    pub api_key: String,
    /// Language code (e.g., 'en' for English)
    pub language: Option<String>,
    /// Context to improve transcription accuracy
    pub prompt: Option<String>,
    /// Limit the number of episodes/videos to process
    pub limit: Option<usize>,
    /// Output directory for transcripts
    pub output_dir: PathBuf,
}

impl Config {
    /// Create a new configuration
    pub fn new(
        api_key: Option<String>,
        language: Option<String>,
        prompt: Option<String>,
        limit: Option<usize>,
        output_dir: &Path,
    ) -> Result<Self> {
        // Try to load API key from various sources
        let api_key = api_key
            .or_else(|| env::var("OPENAI_API_KEY").ok())
            .or_else(|| load_api_key_from_env_file())
            .context("Failed to load API key")?;
        
        // Validate API key
        // Check for either the standard OpenAI key format (sk-...) or the project-based format (sk-proj-...)
        if !api_key.starts_with("sk-") {
            return Err(ConfigError::ApiKeyNotFound.into());
        }
        
        // Create output directory if it doesn't exist
        fs::create_dir_all(output_dir)?;
        
        Ok(Self {
            api_key,
            language,
            prompt,
            limit,
            output_dir: output_dir.to_path_buf(),
        })
    }
}

/// Load API key from .env file
fn load_api_key_from_env_file() -> Option<String> {
    // Try to load from .env file
    if dotenv().is_ok() {
        debug!("Loaded .env file");
        if let Ok(key) = env::var("OPENAI_API_KEY") {
            return Some(key);
        }
    }
    
    // Try to find .env file in various locations
    let env_paths = [
        ".env",
        "./.env",
        "./podscript/.env",
        "../.env",
    ];
    
    for env_path in env_paths {
        if let Ok(content) = fs::read_to_string(env_path) {
            debug!("Found .env file at {}", env_path);
            
            // Parse the file line by line
            for line in content.lines() {
                // Skip comments and empty lines
                if line.trim().starts_with('#') || line.trim().is_empty() {
                    continue;
                }
                
                // Check for OPENAI_API_KEY
                if line.contains("OPENAI_API_KEY") {
                    let parts: Vec<&str> = line.splitn(2, '=').collect();
                    if parts.len() == 2 {
                        let mut value = parts[1].trim();
                        
                        // Remove quotes
                        if (value.starts_with('"') && value.ends_with('"')) || 
                           (value.starts_with('\'') && value.ends_with('\'')) {
                            value = &value[1..value.len() - 1];
                        }
                        
                        // Remove comments
                        if let Some(comment_pos) = value.find('#') {
                            value = &value[0..comment_pos].trim();
                        }
                        
                        if !value.is_empty() {
                            info!("Found API key in {}", env_path);
                            return Some(value.to_string());
                        }
                    }
                }
                
                // Check for lines that look like API keys
                if line.trim().starts_with("sk-") {
                    let value = line.trim().split_whitespace().next().unwrap_or("");
                    if !value.is_empty() {
                        info!("Found potential API key in {}", env_path);
                        return Some(value.to_string());
                    }
                }
            }
        }
    }
    
    None
}
