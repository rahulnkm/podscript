use anyhow::Result;
use log::debug;
use regex::Regex;
use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

/// Sanitize a string for use as a filename or directory name
/// 
/// This function:
/// 1. Removes CDATA tags
/// 2. Keeps only alphanumeric characters and spaces
/// 3. Replaces spaces with underscores
/// 4. Removes trailing underscores
pub fn sanitize_filename(input: &str) -> String {
    // Remove CDATA tags
    let without_cdata = input
        .replace("<![CDATA[", "")
        .replace("]]>", "");
    
    // Keep only alphanumeric characters and spaces
    let re = Regex::new(r"[^a-zA-Z0-9\s]").unwrap();
    let alphanumeric = re.replace_all(&without_cdata, "");
    
    // Replace spaces with underscores and remove trailing underscores
    let with_underscores = alphanumeric.replace(' ', "_");
    let re_trailing = Regex::new(r"_+$").unwrap();
    re_trailing.replace_all(&with_underscores, "").to_string()
}

/// Download a file from a URL
pub async fn download_file(url: &str, output_path: &Path) -> Result<()> {
    debug!("Downloading file from {} to {:?}", url, output_path);
    
    // Create parent directory if it doesn't exist
    if let Some(parent) = output_path.parent() {
        fs::create_dir_all(parent)?;
    }
    
    // Download file using reqwest
    let response = reqwest::get(url).await?;
    let bytes = response.bytes().await?;
    fs::write(output_path, &bytes)?;
    
    Ok(())
}

/// Check if a command is available
pub fn check_command(command: &str) -> bool {
    let output = if cfg!(target_os = "windows") {
        Command::new("where")
            .arg(command)
            .output()
    } else {
        Command::new("which")
            .arg(command)
            .output()
    };
    
    output.map(|o| o.status.success()).unwrap_or(false)
}

/// Run a shell command
pub fn run_command(command: &str, args: &[&str]) -> Result<String> {
    debug!("Running command: {} {:?}", command, args);
    
    let output = Command::new(command)
        .args(args)
        .output()?;
    
    if output.status.success() {
        Ok(String::from_utf8(output.stdout)?)
    } else {
        Err(anyhow::anyhow!(
            "Command failed with exit code {}: {}",
            output.status.code().unwrap_or(-1),
            String::from_utf8_lossy(&output.stderr)
        ))
    }
}

/// Split a large audio file into smaller chunks
pub fn split_audio_file(
    input_file: &Path,
    output_dir: &Path,
    chunk_duration: u64,
) -> Result<Vec<PathBuf>> {
    debug!("Splitting audio file: {:?}", input_file);
    
    // Create output directory
    fs::create_dir_all(output_dir)?;
    
    // Get audio duration using ffprobe
    let duration_output = run_command(
        "ffprobe",
        &[
            "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            input_file.to_str().unwrap(),
        ],
    )?;
    
    let duration: f64 = duration_output.trim().parse()?;
    let chunk_count = (duration / chunk_duration as f64).ceil() as usize;
    
    debug!("Audio duration: {} seconds, splitting into {} chunks", duration, chunk_count);
    
    let mut chunk_files = Vec::with_capacity(chunk_count);
    
    for i in 0..chunk_count {
        let start_time = i as f64 * chunk_duration as f64;
        let chunk_file = output_dir.join(format!("chunk_{}.mp3", i + 1));
        
        // Convert values to strings before using them in args
        let start_time_str = start_time.to_string();
        let chunk_duration_str = chunk_duration.to_string();
        let input_file_str = input_file.to_str().unwrap();
        let chunk_file_str = chunk_file.to_str().unwrap();
        
        let mut args = vec![
            "-nostdin", "-v", "quiet", "-y",
            "-i", input_file_str,
            "-ss", &start_time_str,
        ];
        
        // For all chunks except the last one, set a specific duration
        if i < chunk_count - 1 {
            args.extend_from_slice(&["-t", &chunk_duration_str]);
        }
        
        args.extend_from_slice(&[
            "-acodec", "libmp3lame",
            "-b:a", "128k",
            chunk_file_str,
        ]);
        
        run_command("ffmpeg", &args)?;
        chunk_files.push(chunk_file);
    }
    
    Ok(chunk_files)
}
