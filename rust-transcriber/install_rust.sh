#!/bin/bash

# Script to install Rust and build the media transcriber

# ANSI color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Rust Media Transcriber Setup ===${NC}"
echo

# Check if Rust is already installed
if command -v rustc >/dev/null 2>&1; then
    echo -e "${GREEN}Rust is already installed!${NC}"
    rustc --version
else
    echo -e "${YELLOW}Rust is not installed. Installing Rust...${NC}"
    echo "This will download and run the official Rust installer from https://sh.rustup.rs"
    echo
    
    # Ask for confirmation
    read -p "Continue with installation? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Installation cancelled.${NC}"
        exit 1
    fi
    
    # Install Rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    
    # Source the environment
    source "$HOME/.cargo/env"
    
    echo -e "${GREEN}Rust installed successfully!${NC}"
    rustc --version
fi

echo
echo -e "${BLUE}=== Installing Dependencies ===${NC}"

# Check for ffmpeg
if ! command -v ffmpeg >/dev/null 2>&1; then
    echo -e "${YELLOW}ffmpeg is not installed. Installing ffmpeg...${NC}"
    
    # Check if Homebrew is installed
    if command -v brew >/dev/null 2>&1; then
        brew install ffmpeg
    else
        echo -e "${RED}Homebrew is not installed. Please install ffmpeg manually:${NC}"
        echo "  1. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo "  2. Install ffmpeg: brew install ffmpeg"
        exit 1
    fi
else
    echo -e "${GREEN}ffmpeg is already installed!${NC}"
fi

# Check for yt-dlp
if ! command -v yt-dlp >/dev/null 2>&1; then
    echo -e "${YELLOW}yt-dlp is not installed. Installing yt-dlp...${NC}"
    
    # Check if Homebrew is installed
    if command -v brew >/dev/null 2>&1; then
        brew install yt-dlp
    else
        echo -e "${RED}Homebrew is not installed. Please install yt-dlp manually:${NC}"
        echo "  1. Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo "  2. Install yt-dlp: brew install yt-dlp"
        exit 1
    fi
else
    echo -e "${GREEN}yt-dlp is already installed!${NC}"
fi

echo
echo -e "${BLUE}=== Building Media Transcriber ===${NC}"

# Navigate to the rust-transcriber directory
cd "$(dirname "$0")" || exit 1

# Build the project
echo "Building the project..."
cargo build --release

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Build successful!${NC}"
    echo
    echo -e "${BLUE}=== Next Steps ===${NC}"
    echo "1. Make sure you have an OpenAI API key"
    echo "2. Run the media transcriber with:"
    echo "   ./target/release/media-transcriber --source URL"
    echo
    echo "For more options, run:"
    echo "   ./target/release/media-transcriber --help"
else
    echo -e "${RED}Build failed. Please check the error messages above.${NC}"
fi
