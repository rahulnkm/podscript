package main

import (
	"fmt"
	"os"

	"github.com/alecthomas/kong"
)

var cli struct {
	Configure    ConfigureCmd    `cmd:"" help:"Configure podscript with API keys"`
	YTT          YTTCmd          `cmd:"" help:"Transcribe YouTube videos from autogenerated captions"`
	Deepgram     DeepgramCmd     `cmd:"" help:"Transcribe audio using Deepgram API"`
	AssemblyAI   AssemblyAICmd   `cmd:"" help:"Transcribe audio using AssemblyAI"`
	Groq         GroqCmd         `cmd:"" help:"Transcribe audio using Groq's Whisper API"`
	OpenAIWhisper OpenAIWhisperCmd `cmd:"" help:"Transcribe audio using OpenAI's Whisper API"`
	Web          WebCmd          `cmd:"" help:"Run web based UI server locally"`
}

func main() {
	ctx := kong.Parse(&cli, kong.Configuration(ConfLoader, "~/.podscript.toml"))
	err := ctx.Run()
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s\n", err)
		os.Exit(1)
	}
}
