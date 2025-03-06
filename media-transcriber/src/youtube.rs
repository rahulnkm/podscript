use anyhow::{Context, Result};
use log::{debug, error, info};
use regex::Regex;
use serde::Deserialize;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;
use tempfile::tempdir;

use crate::config::Config;
use crate::transcription::TranscriptionService;
use crate::utils;

/// YouTube processor for downloading and transcribing videos
pub struct YouTubeProcessor<'a> {
    config: &'a Config,
}

/// YouTube video metadata
#[derive(Debug, Deserialize)]
struct VideoInfo {
    id: String,
    title: String,
    upload_date: Option<String>,
    channel: Option<String>,
    description: Option<String>,
    duration: Option<f64>,
}

impl<'a> YouTubeProcessor<'a> {
    /// Create a new YouTube processor
    pub fn new(config: &'a Config) -> Self {
        Self { config }
    }
    
    /// Process a YouTube URL (video, channel, or playlist)
    pub async fn process(&self, url: &str) -> Result<()> {
        info!("Processing YouTube URL: {}", url);
        
        // Check if yt-dlp is installed
        if !utils::check_command("yt-dlp") {
            return Err(anyhow::anyhow!(
                "yt-dlp is not installed. Please install it with 'brew install yt-dlp' or visit https://github.com/yt-dlp/yt-dlp"
            ));
        }
        
        // Determine if this is a single video or a channel/playlist
        if self.is_single_video(url) {
            self.process_single_video(url).await?;
        } else {
            self.process_channel_or_playlist(url).await?;
        }
        
        Ok(())
    }
    
    /// Check if URL is a single video
    fn is_single_video(&self, url: &str) -> bool {
        // YouTube video URL patterns
        let patterns = [
            r"youtube\.com/watch\?v=[\w-]+",
            r"youtu\.be/[\w-]+",
            r"youtube\.com/v/[\w-]+",
            r"youtube\.com/embed/[\w-]+",
        ];
        
        for pattern in patterns {
            if Regex::new(pattern).unwrap().is_match(url) {
                return true;
            }
        }
        
        false
    }
    
    /// Process a single YouTube video
    async fn process_single_video(&self, url: &str) -> Result<()> {
        info!("Processing single YouTube video: {}", url);
        
        // Get video info
        let video_info = self.get_video_info(url)?;
        
        // Create video directory
        let video_dir = self.create_video_directory(&video_info)?;
        
        // Save video info
        self.save_video_info(&video_info, url, &video_dir)?;
        
        // Download and transcribe video
        self.download_and_transcribe_video(url, &video_dir).await?;
        
        Ok(())
    }
    
    /// Process a YouTube channel or playlist
    async fn process_channel_or_playlist(&self, url: &str) -> Result<()> {
        info!("Processing YouTube channel or playlist: {}", url);
        
        // Get channel/playlist info
        let channel_info = self.get_channel_info(url)?;
        
        // Create channel directory
        let channel_dir = self.create_channel_directory(&channel_info)?;
        
        // Save channel info
        self.save_channel_info(&channel_info, url, &channel_dir)?;
        
        // Get video URLs
        let video_urls = self.get_video_urls(url)?;
        
        // Apply limit if specified
        let videos_to_process = if let Some(limit) = self.config.limit {
            if video_urls.len() > limit {
                info!("Limiting to {} videos (out of {})", limit, video_urls.len());
                video_urls[0..limit].to_vec()
            } else {
                video_urls
            }
        } else {
            video_urls
        };
        
        // Process each video
        for (i, video_url) in videos_to_process.iter().enumerate() {
            info!("Processing video {}/{}: {}", i + 1, videos_to_process.len(), video_url);
            
            // Get video info
            match self.get_video_info(video_url) {
                Ok(video_info) => {
                    // Create video directory
                    let video_dir = channel_dir.join(utils::sanitize_filename(&video_info.title));
                    fs::create_dir_all(&video_dir)?;
                    
                    // Save video info
                    self.save_video_info(&video_info, video_url, &video_dir)?;
                    
                    // Download and transcribe video
                    if let Err(e) = self.download_and_transcribe_video(video_url, &video_dir).await {
                        error!("Failed to process video: {}", e);
                    }
                }
                Err(e) => {
                    error!("Failed to get video info: {}", e);
                }
            }
        }
        
        Ok(())
    }
    
    /// Get video information using yt-dlp
    fn get_video_info(&self, url: &str) -> Result<VideoInfo> {
        debug!("Getting video info for: {}", url);
        
        let output = Command::new("yt-dlp")
            .args(&[
                "--dump-json",
                "--no-playlist",
                url,
            ])
            .output()?;
        
        if !output.status.success() {
            return Err(anyhow::anyhow!(
                "Failed to get video info: {}",
                String::from_utf8_lossy(&output.stderr)
            ));
        }
        
        let json = String::from_utf8(output.stdout)?;
        let video_info: VideoInfo = serde_json::from_str(&json)?;
        
        debug!("Video info: {:?}", video_info);
        Ok(video_info)
    }
    
    /// Get channel information using yt-dlp
    fn get_channel_info(&self, url: &str) -> Result<VideoInfo> {
        debug!("Getting channel info for: {}", url);
        
        let output = Command::new("yt-dlp")
            .args(&[
                "--dump-json",
                "--playlist-items", "1",
                url,
            ])
            .output()?;
        
        if !output.status.success() {
            return Err(anyhow::anyhow!(
                "Failed to get channel info: {}",
                String::from_utf8_lossy(&output.stderr)
            ));
        }
        
        let json = String::from_utf8(output.stdout)?;
        let video_info: VideoInfo = serde_json::from_str(&json)?;
        
        debug!("Channel info: {:?}", video_info);
        Ok(video_info)
    }
    
    /// Get list of video URLs from a channel or playlist
    fn get_video_urls(&self, url: &str) -> Result<Vec<String>> {
        debug!("Getting video URLs from: {}", url);
        
        let output = Command::new("yt-dlp")
            .args(&[
                "--get-id",
                "--flat-playlist",
                url,
            ])
            .output()?;
        
        if !output.status.success() {
            return Err(anyhow::anyhow!(
                "Failed to get video URLs: {}",
                String::from_utf8_lossy(&output.stderr)
            ));
        }
        
        let ids = String::from_utf8(output.stdout)?;
        let video_urls: Vec<String> = ids
            .lines()
            .filter(|line| !line.trim().is_empty())
            .map(|id| format!("https://www.youtube.com/watch?v={}", id.trim()))
            .collect();
        
        info!("Found {} videos", video_urls.len());
        Ok(video_urls)
    }
    
    /// Create video directory
    fn create_video_directory(&self, video_info: &VideoInfo) -> Result<PathBuf> {
        let channel_name = video_info.channel.as_deref().unwrap_or("Unknown_Channel");
        let sanitized_channel = utils::sanitize_filename(channel_name);
        
        let sanitized_title = utils::sanitize_filename(&video_info.title);
        let video_dir = self.config.output_dir.join(&sanitized_channel).join(&sanitized_title);
        
        debug!("Creating video directory: {:?}", video_dir);
        fs::create_dir_all(&video_dir)?;
        
        Ok(video_dir)
    }
    
    /// Create channel directory
    fn create_channel_directory(&self, channel_info: &VideoInfo) -> Result<PathBuf> {
        let channel_name = channel_info.channel.as_deref().unwrap_or("Unknown_Channel");
        let sanitized_channel = utils::sanitize_filename(channel_name);
        
        let channel_dir = self.config.output_dir.join(&sanitized_channel);
        
        debug!("Creating channel directory: {:?}", channel_dir);
        fs::create_dir_all(&channel_dir)?;
        
        Ok(channel_dir)
    }
    
    /// Save video information
    fn save_video_info(&self, video_info: &VideoInfo, url: &str, video_dir: &Path) -> Result<()> {
        let info_file = video_dir.join("video_info.txt");
        
        let mut info = format!("Title: {}\n", video_info.title);
        info.push_str(&format!("Video URL: {}\n", url));
        info.push_str(&format!("Video ID: {}\n", video_info.id));
        
        if let Some(channel) = &video_info.channel {
            info.push_str(&format!("Channel: {}\n", channel));
        }
        
        if let Some(upload_date) = &video_info.upload_date {
            info.push_str(&format!("Upload Date: {}\n", upload_date));
        }
        
        if let Some(duration) = video_info.duration {
            info.push_str(&format!("Duration: {} seconds\n", duration));
        }
        
        if let Some(description) = &video_info.description {
            info.push_str(&format!("Description: {}\n", description));
        }
        
        let info_file_path = info_file.clone();
        fs::write(info_file, info)?;
        debug!("Saved video info to: {:?}", info_file_path);
        
        Ok(())
    }
    
    /// Save channel information
    fn save_channel_info(&self, channel_info: &VideoInfo, url: &str, channel_dir: &Path) -> Result<()> {
        let info_file = channel_dir.join("channel_info.txt");
        
        let channel_name = channel_info.channel.as_deref().unwrap_or("Unknown Channel");
        
        let mut info = format!("Channel: {}\n", channel_name);
        info.push_str(&format!("Channel URL: {}\n", url));
        
        if let Some(description) = &channel_info.description {
            info.push_str(&format!("Description: {}\n", description));
        }
        
        let info_file_path = info_file.clone();
        fs::write(info_file, info)?;
        debug!("Saved channel info to: {:?}", info_file_path);
        
        Ok(())
    }
    
    /// Download and transcribe a YouTube video
    async fn download_and_transcribe_video(&self, url: &str, video_dir: &Path) -> Result<()> {
        debug!("Downloading and transcribing video: {}", url);
        
        // Create temporary directory
        let temp_dir = tempdir()?;
        let audio_file = temp_dir.path().join("audio.mp3");
        
        // Download audio using yt-dlp
        let output = Command::new("yt-dlp")
            .args(&[
                "-x",
                "--audio-format", "mp3",
                "--audio-quality", "0",
                "-o", audio_file.to_str().unwrap(),
                url,
            ])
            .output()?;
        
        if !output.status.success() {
            return Err(anyhow::anyhow!(
                "Failed to download video audio: {}",
                String::from_utf8_lossy(&output.stderr)
            ));
        }
        
        // Transcribe audio file
        let transcript_file = video_dir.join("transcript.txt");
        let transcription_service = TranscriptionService::new(self.config);
        
        transcription_service.transcribe_file(&audio_file, &transcript_file).await
            .context("Failed to transcribe video audio")?;
        
        info!("Successfully transcribed video: {}", url);
        Ok(())
    }
}
