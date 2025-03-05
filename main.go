package main

import (
	"fmt"
	"os"

	"github.com/alecthomas/kong"
)

// CLI struct - simplified to only include OpenAI Whisper functionality
// This streamlined version focuses solely on media transcription using OpenAI Whisper
var cli struct {
	Configure    ConfigureCmd    `cmd:"" help:"Configure podscript with API keys"`
	OpenAIWhisper OpenAIWhisperCmd `cmd:"" help:"Transcribe audio using OpenAI's Whisper API"`
	YTT          YTTCmd          `cmd:"" help:"Transcribe YouTube videos using OpenAI Whisper"`
}

func main() {
	ctx := kong.Parse(&cli, kong.Configuration(ConfLoader, "~/.podscript.toml"))
	err := ctx.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", err)
		os.Exit(1)
	}
}
