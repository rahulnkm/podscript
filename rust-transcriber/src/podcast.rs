use anyhow::Result;
use chrono::{DateTime, FixedOffset};
use log::{debug, error, info, warn};
use rss::{Channel, Item};
use std::fs;
use std::path::{Path, PathBuf};
use tempfile::tempdir;

use crate::config::Config;
use crate::transcription::TranscriptionService;
use crate::utils;

/// Podcast processor for downloading and transcribing podcast episodes
pub struct PodcastProcessor<'a> {
    config: &'a Config,
}

/// Podcast episode metadata
struct PodcastEpisode {
    title: String,
    audio_url: String,
    pub_date: Option<DateTime<FixedOffset>>,
}

impl<'a> PodcastProcessor<'a> {
    /// Create a new podcast processor
    pub fn new(config: &'a Config) -> Self {
        Self { config }
    }
    
    /// Process a podcast RSS feed
    pub async fn process(&self, feed_url: &str) -> Result<()> {
        info!("Processing podcast feed: {}", feed_url);
        
        // Download and parse RSS feed
        let channel = self.download_feed(feed_url).await?;
        
        // Create podcast directory
        let podcast_dir = self.create_podcast_directory(&channel.title)?;
        
        // Save podcast info
        self.save_podcast_info(&channel, feed_url, &podcast_dir)?;
        
        // Extract episodes
        let mut episodes = self.extract_episodes(&channel)?;
        
        // Sort episodes by publication date (newest first)
        episodes.sort_by(|a, b| {
            b.pub_date.unwrap_or_default().cmp(&a.pub_date.unwrap_or_default())
        });
        
        // Apply limit if specified
        if let Some(limit) = self.config.limit {
            if episodes.len() > limit {
                info!("Limiting to {} episodes (out of {})", limit, episodes.len());
                episodes.truncate(limit);
            }
        }
        
        // Process each episode
        let transcription_service = TranscriptionService::new(self.config);
        
        for (i, episode) in episodes.iter().enumerate() {
            info!("Processing episode {}/{}: {}", i + 1, episodes.len(), episode.title);
            
            // Create episode directory
            let episode_dir = podcast_dir.join(utils::sanitize_filename(&episode.title));
            fs::create_dir_all(&episode_dir)?;
            
            // Download audio file
            let temp_dir = tempdir()?;
            let audio_file = temp_dir.path().join("episode.mp3");
            
            match utils::download_file(&episode.audio_url, &audio_file).await {
                Ok(_) => {
                    // Transcribe audio file
                    let transcript_file = episode_dir.join("transcript.txt");
                    
                    if let Err(e) = transcription_service.transcribe_file(&audio_file, &transcript_file).await {
                        error!("Failed to transcribe episode: {}", e);
                        continue;
                    }
                    
                    info!("Successfully transcribed episode: {}", episode.title);
                }
                Err(e) => {
                    error!("Failed to download episode audio: {}", e);
                    continue;
                }
            }
        }
        
        Ok(())
    }
    
    /// Download and parse RSS feed
    async fn download_feed(&self, feed_url: &str) -> Result<Channel> {
        debug!("Downloading RSS feed: {}", feed_url);
        
        // Download feed
        let response = reqwest::get(feed_url).await?;
        let content = response.bytes().await?;
        
        // Parse feed
        let channel = Channel::read_from(&content[..])?;
        debug!("Found podcast: {} with {} items", channel.title, channel.items.len());
        
        Ok(channel)
    }
    
    /// Create podcast directory
    fn create_podcast_directory(&self, podcast_title: &str) -> Result<PathBuf> {
        let sanitized_title = utils::sanitize_filename(podcast_title);
        let podcast_dir = self.config.output_dir.join(&sanitized_title);
        
        debug!("Creating podcast directory: {:?}", podcast_dir);
        fs::create_dir_all(&podcast_dir)?;
        
        Ok(podcast_dir)
    }
    
    /// Save podcast information
    fn save_podcast_info(&self, channel: &Channel, feed_url: &str, podcast_dir: &Path) -> Result<()> {
        let info_file = podcast_dir.join("podcast_info.txt");
        
        let mut info = format!("Title: {}\n", channel.title);
        info.push_str(&format!("Feed URL: {}\n", feed_url));
        
        // Description is already a String, not an Option<String>
        info.push_str(&format!("Description: {}\n", channel.description));
        
        if let Some(language) = &channel.language {
            info.push_str(&format!("Language: {}\n", language));
        }
        
        if let Some(author) = &channel.itunes_ext.as_ref().and_then(|ext| ext.author.clone()) {
            info.push_str(&format!("Author: {}\n", author));
        }
        
        // Use a reference to info_file to avoid moving it
        fs::write(&info_file, info)?;
        debug!("Saved podcast info to: {:?}", info_file);
        
        Ok(())
    }
    
    /// Extract episodes from RSS feed
    fn extract_episodes(&self, channel: &Channel) -> Result<Vec<PodcastEpisode>> {
        let mut episodes = Vec::new();
        
        for item in &channel.items {
            if let Some(episode) = self.extract_episode(item) {
                episodes.push(episode);
            }
        }
        
        info!("Extracted {} episodes", episodes.len());
        Ok(episodes)
    }
    
    /// Extract episode information from RSS item
    fn extract_episode(&self, item: &Item) -> Option<PodcastEpisode> {
        // Get episode title
        let title = item.title.clone().unwrap_or_else(|| "Unknown Title".to_string());
        
        // Get audio URL
        let audio_url = item.enclosure.as_ref().and_then(|enc| {
            if enc.mime_type.starts_with("audio/") {
                Some(enc.url.clone())
            } else {
                None
            }
        });
        
        // Get publication date
        let pub_date = item.pub_date.as_ref().and_then(|date_str| {
            DateTime::parse_from_rfc2822(date_str).ok()
        });
        
        if let Some(url) = audio_url {
            Some(PodcastEpisode {
                title,
                audio_url: url,
                pub_date,
            })
        } else {
            warn!("Skipping episode without audio enclosure: {}", title);
            None
        }
    }
}
