use anyhow::Result;
use clap::{Parser, Subcommand};
use colored::Colorize;
use log::{error, info};
use std::path::PathBuf;

mod config;
mod podcast;
mod transcription;
mod utils;
mod youtube;

use config::Config;
use podcast::PodcastProcessor;
use youtube::YouTubeProcessor;

/// Media Transcriber - A fast tool for transcribing podcasts and YouTube videos
/// 
/// This application can process:
/// 1. Podcast RSS feeds - extracting all episodes, transcribing them
/// 2. YouTube channels/playlists - extracting videos, transcribing them
/// 3. Individual YouTube videos - transcribing a single video
/// 4. Multiple sources at once - processing a list of feeds/channels
#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,

    /// URL of a podcast RSS feed or YouTube channel/video
    #[arg(short, long, conflicts_with = "file")]
    source: Option<String>,

    /// File containing a list of sources (one URL per line)
    #[arg(short, long, conflicts_with = "source")]
    file: Option<PathBuf>,

    /// Language code (e.g., 'en' for English)
    #[arg(short, long)]
    language: Option<String>,

    /// Context to improve transcription accuracy
    #[arg(short, long)]
    prompt: Option<String>,

    /// Limit the number of episodes/videos to process (newest first)
    #[arg(short, long)]
    limit: Option<usize>,

    /// OpenAI API key for transcription
    #[arg(long, env("OPENAI_API_KEY"))]
    api_key: Option<String>,

    /// Output directory for transcripts (default: podcast-transcripts)
    #[arg(short, long, default_value = "podcast-transcripts")]
    output_dir: PathBuf,

    /// Enable verbose logging
    #[arg(short, long)]
    verbose: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Configure API keys and settings
    Configure,
}

/// Main entry point for the media transcriber application
#[tokio::main]
async fn main() -> Result<()> {
    // Parse command line arguments
    let cli = Cli::parse();
    
    // Initialize logging
    init_logger(cli.verbose);
    
    // Print welcome message
    print_welcome();
    
    // Process commands or default behavior
    match &cli.command {
        Some(Commands::Configure) => {
            configure().await?;
        }
        None => {
            // Validate input - need at least one source
            if cli.source.is_none() && cli.file.is_none() {
                error!("You must specify either --source or --file");
                std::process::exit(1);
            }
            
            // Create configuration
            let config = Config::new(
                cli.api_key,
                cli.language,
                cli.prompt,
                cli.limit,
                &cli.output_dir,
            )?;
            
            // Process sources
            if let Some(source_url) = cli.source {
                process_single_source(&source_url, &config).await?;
            } else if let Some(sources_file) = cli.file {
                process_sources_file(&sources_file, &config).await?;
            }
        }
    }
    
    info!("{}", "Media transcription completed successfully!".green().bold());
    Ok(())
}

/// Initialize the logger with appropriate verbosity
fn init_logger(verbose: bool) {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or(
        if verbose { "debug" } else { "info" },
    ))
    .format_timestamp(None)
    .init();
}

/// Print welcome message
fn print_welcome() {
    println!("{}", "🎙️  Media Transcriber - Rust Edition 🎙️".green().bold());
    println!("{}", "A fast tool for transcribing podcasts and YouTube videos".bright_blue());
    println!();
}

/// Configure API keys and settings
async fn configure() -> Result<()> {
    info!("Configuring API keys and settings...");
    // Implementation will be added later
    Ok(())
}

/// Process a single source (podcast or YouTube)
async fn process_single_source(source_url: &str, config: &Config) -> Result<()> {
    info!("Processing source: {}", source_url);
    
    // Detect source type
    if source_url.contains("youtube.com") || source_url.contains("youtu.be") {
        // Process YouTube source
        let youtube_processor = YouTubeProcessor::new(config);
        youtube_processor.process(source_url).await?;
    } else {
        // Process podcast source
        let podcast_processor = PodcastProcessor::new(config);
        podcast_processor.process(source_url).await?;
    }
    
    Ok(())
}

/// Process a list of sources from a file
async fn process_sources_file(sources_file: &PathBuf, config: &Config) -> Result<()> {
    info!("Processing sources from file: {:?}", sources_file);
    
    // Read sources file
    let content = std::fs::read_to_string(sources_file)?;
    let sources: Vec<_> = content
        .lines()
        .filter(|line| !line.trim().is_empty() && !line.trim().starts_with('#'))
        .collect();
    
    info!("Found {} sources to process", sources.len());
    
    // Process each source
    for (i, source) in sources.iter().enumerate() {
        info!("Processing source {}/{}: {}", i + 1, sources.len(), source);
        if let Err(e) = process_single_source(source, config).await {
            error!("Failed to process source {}: {}", source, e);
        }
    }
    
    Ok(())
}
