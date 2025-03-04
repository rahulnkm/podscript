package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"os"
	"time"

	"github.com/openai/openai-go"
	"github.com/openai/openai-go/option"
)

// This is a standalone example showing how to use OpenAI's Whisper API directly
// without using the podscript command-line interface.
// It demonstrates the core functionality that powers the podscript openai-whisper command.

func main() {
	// Set up logging
	log.SetFlags(log.LstdFlags | log.Lshortfile)
	log.Println("Starting OpenAI Whisper transcription example")

	// Check command line arguments
	if len(os.Args) < 2 {
		log.Fatal("Usage: go run whisper_example.go <audio-file-path>")
	}
	audioFilePath := os.Args[1]
	log.Printf("Audio file: %s", audioFilePath)

	// Get API key from environment
	apiKey := os.Getenv("OPENAI_API_KEY")
	if apiKey == "" {
		log.Fatal("OPENAI_API_KEY environment variable not set")
	}
	log.Println("API key found")

	// Validate file exists
	if _, err := os.Stat(audioFilePath); os.IsNotExist(err) {
		log.Fatalf("File does not exist: %s", audioFilePath)
	}

	// Open audio file
	log.Printf("Opening audio file: %s", audioFilePath)
	file, err := os.Open(audioFilePath)
	if err != nil {
		log.Fatalf("Error opening file: %v", err)
	}
	defer file.Close()

	// Create OpenAI client
	log.Println("Creating OpenAI client")
	client := openai.NewClient(option.WithAPIKey(apiKey))

	// Start timer for performance measurement
	startTime := time.Now()

	// Create transcription request
	log.Println("Sending transcription request")
	transcription, err := client.Audio.Transcriptions.New(context.Background(), openai.AudioTranscriptionNewParams{
		Model:      openai.F("whisper-1"),
		File:       openai.F[io.Reader](file),
		Language:   openai.F("en"), // Optional: specify language
		Prompt:     openai.F(""),   // Optional: provide context
		Temperature: openai.F(0.0),  // Optional: control randomness
	})
	if err != nil {
		log.Fatalf("Transcription failed: %v", err)
	}

	// Calculate elapsed time
	elapsedTime := time.Since(startTime)
	log.Printf("Transcription completed in %v", elapsedTime)

	// Output results
	fmt.Println("\n=== TRANSCRIPTION RESULT ===")
	fmt.Println(transcription.Text)
	fmt.Println("===========================")

	// Save to file
	outputFile := audioFilePath + ".transcript.txt"
	log.Printf("Saving transcription to: %s", outputFile)
	err = os.WriteFile(outputFile, []byte(transcription.Text), 0644)
	if err != nil {
		log.Fatalf("Error saving transcription: %v", err)
	}

	log.Println("Transcription process completed successfully")
}
