package main

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log"
	"os"
	"net/http"
	"bytes"
	"mime/multipart"
	"path/filepath"

	"github.com/openai/openai-go"
	"github.com/openai/openai-go/option"
)

// OpenAIWhisperCmd defines the command structure for using OpenAI's Whisper model
// for speech-to-text transcription. It supports transcribing audio files and
// provides options for output destination and model selection.
type OpenAIWhisperCmd struct {
	File          string `arg:"" help:"Audio file to transcribe"`
	Output        string `help:"Path to output transcript file (default: stdout)" short:"o"`
	APIKey        string `env:"OPENAI_API_KEY" default:"" hidden:""`
	Model         string `help:"Whisper model to use (default: whisper-1)" default:"whisper-1"`
	Language      string `help:"Language of the audio (optional, e.g., 'en', 'fr')" short:"l"`
	Prompt        string `help:"Optional text to guide the model's transcription" short:"p"`
	ResponseFormat string `help:"Output format: json, text, srt, verbose_json, vtt (default: text)" default:"text"`
	Temperature   float64 `help:"Sampling temperature between 0 and 1 (default: 0)" default:"0"`
}

// Run executes the OpenAI Whisper transcription command
func (w *OpenAIWhisperCmd) Run() error {
	log.Println("Starting OpenAI Whisper transcription process")
	
	// Validate API key
	if w.APIKey == "" {
		log.Println("ERROR: API key not found")
		return errors.New("API key not found. Please run 'podscript configure' or set the OPENAI_API_KEY environment variable")
	}
	log.Println("API key validation successful")

	// Validate file exists
	if _, err := os.Stat(w.File); os.IsNotExist(err) {
		log.Printf("ERROR: File does not exist: %s", w.File)
		return fmt.Errorf("file does not exist: %s", w.File)
	}
	
	// Open the audio file
	log.Printf("Opening audio file: %s", w.File)
	file, err := os.Open(w.File)
	if err != nil {
		log.Printf("ERROR: Failed to open file: %v", err)
		return fmt.Errorf("error opening file: %w", err)
	}
	defer func() {
		log.Println("Closing audio file")
		file.Close()
	}()
	log.Println("Audio file opened successfully")

	// Create OpenAI client
	log.Println("Initializing OpenAI client")
	client := openai.NewClient(option.WithAPIKey(w.APIKey))

	// Prepare transcription parameters
	log.Printf("Preparing transcription request with model: %s", w.Model)
	params := openai.AudioTranscriptionNewParams{
		Model: openai.F(w.Model),
		File:  openai.F[io.Reader](file),
	}
	
	// Add optional parameters if provided
	if w.Language != "" {
		log.Printf("Setting language: %s", w.Language)
		params.Language = openai.F(w.Language)
	}
	
	if w.Prompt != "" {
		log.Printf("Setting prompt: %s", w.Prompt)
		params.Prompt = openai.F(w.Prompt)
	}
	
	if w.ResponseFormat != "" {
		log.Printf("Setting response format: %s", w.ResponseFormat)
		// Convert string to the appropriate type for ResponseFormat
		switch w.ResponseFormat {
		case "json":
			params.ResponseFormat = openai.F(openai.AudioResponseFormatJSON)
		case "text":
			params.ResponseFormat = openai.F(openai.AudioResponseFormatText)
		case "srt":
			params.ResponseFormat = openai.F(openai.AudioResponseFormatSRT)
		case "verbose_json":
			params.ResponseFormat = openai.F(openai.AudioResponseFormatVerboseJSON)
		case "vtt":
			params.ResponseFormat = openai.F(openai.AudioResponseFormatVTT)
		default:
			log.Printf("WARNING: Unrecognized response format: %s, using default", w.ResponseFormat)
		}
	}
	
	if w.Temperature >= 0 && w.Temperature <= 1 {
		log.Printf("Setting temperature: %f", w.Temperature)
		params.Temperature = openai.F(w.Temperature)
	}

	// For non-JSON formats, we need to use a direct HTTP request approach
	// because the OpenAI Go SDK doesn't handle non-JSON responses well
	log.Println("Sending transcription request to OpenAI API")
	var transcriptionText string
	
	if w.ResponseFormat != "json" && w.ResponseFormat != "verbose_json" {
		log.Printf("Using direct HTTP request for format: %s", w.ResponseFormat)
		
		// Create a buffer to store our request body
		var requestBody bytes.Buffer
		
		// Create a multipart writer
		multipartWriter := multipart.NewWriter(&requestBody)
		
		// Add the file
		fileWriter, err := multipartWriter.CreateFormFile("file", filepath.Base(w.File))
		if err != nil {
			log.Printf("ERROR: Failed to create form file: %v", err)
			return fmt.Errorf("failed to create form file: %w", err)
		}
		
		// Reset file pointer to beginning
		if _, err := file.Seek(0, 0); err != nil {
			log.Printf("ERROR: Failed to reset file pointer: %v", err)
			return fmt.Errorf("failed to reset file pointer: %w", err)
		}
		
		// Copy the file content to the form
		if _, err = io.Copy(fileWriter, file); err != nil {
			log.Printf("ERROR: Failed to copy file content: %v", err)
			return fmt.Errorf("failed to copy file content: %w", err)
		}
		
		// Add other form fields
		if err = multipartWriter.WriteField("model", w.Model); err != nil {
			log.Printf("ERROR: Failed to add model field: %v", err)
			return fmt.Errorf("failed to add model field: %w", err)
		}
		
		if w.Language != "" {
			if err = multipartWriter.WriteField("language", w.Language); err != nil {
				log.Printf("ERROR: Failed to add language field: %v", err)
				return fmt.Errorf("failed to add language field: %w", err)
			}
		}
		
		if w.Prompt != "" {
			if err = multipartWriter.WriteField("prompt", w.Prompt); err != nil {
				log.Printf("ERROR: Failed to add prompt field: %v", err)
				return fmt.Errorf("failed to add prompt field: %w", err)
			}
		}
		
		if err = multipartWriter.WriteField("response_format", w.ResponseFormat); err != nil {
			log.Printf("ERROR: Failed to add response_format field: %v", err)
			return fmt.Errorf("failed to add response_format field: %w", err)
		}
		
		if w.Temperature >= 0 && w.Temperature <= 1 {
			if err = multipartWriter.WriteField("temperature", fmt.Sprintf("%f", w.Temperature)); err != nil {
				log.Printf("ERROR: Failed to add temperature field: %v", err)
				return fmt.Errorf("failed to add temperature field: %w", err)
			}
		}
		
		// Close the multipart writer
		if err = multipartWriter.Close(); err != nil {
			log.Printf("ERROR: Failed to close multipart writer: %v", err)
			return fmt.Errorf("failed to close multipart writer: %w", err)
		}
		
		// Create the HTTP request
		req, err := http.NewRequest("POST", "https://api.openai.com/v1/audio/transcriptions", &requestBody)
		if err != nil {
			log.Printf("ERROR: Failed to create HTTP request: %v", err)
			return fmt.Errorf("failed to create HTTP request: %w", err)
		}
		
		// Set headers
		req.Header.Set("Content-Type", multipartWriter.FormDataContentType())
		req.Header.Set("Authorization", "Bearer "+w.APIKey)
		
		// Send the request
		client := &http.Client{}
		resp, err := client.Do(req)
		if err != nil {
			log.Printf("ERROR: Failed to send HTTP request: %v", err)
			return fmt.Errorf("failed to send HTTP request: %w", err)
		}
		defer resp.Body.Close()
		
		// Check the response status
		if resp.StatusCode != http.StatusOK {
			respBody, _ := io.ReadAll(resp.Body)
			log.Printf("ERROR: API returned non-200 status code: %d - %s", resp.StatusCode, string(respBody))
			return fmt.Errorf("API returned status code %d: %s", resp.StatusCode, string(respBody))
		}
		
		// Read the response body
		respBody, err := io.ReadAll(resp.Body)
		if err != nil {
			log.Printf("ERROR: Failed to read response body: %v", err)
			return fmt.Errorf("failed to read response body: %w", err)
		}
		
		transcriptionText = string(respBody)
		log.Println("Successfully received transcription response")
	} else {
		// For JSON formats, use the structured response from the SDK
		log.Printf("Using OpenAI SDK for format: %s", w.ResponseFormat)
		transcription, err := client.Audio.Transcriptions.New(context.Background(), params)
		if err != nil {
			log.Printf("ERROR: Transcription failed: %v", err)
			return fmt.Errorf("transcription failed: %w", err)
		}
		transcriptionText = transcription.Text
	}
	
	log.Println("Transcription completed successfully")

	// Output the transcription
	if w.Output != "" {
		log.Printf("Writing transcription to file: %s", w.Output)
		if err = os.WriteFile(w.Output, []byte(transcriptionText), 0644); err != nil {
			log.Printf("ERROR: Failed to write transcript to file: %v", err)
			return fmt.Errorf("failed to write transcript: %w", err)
		}
		log.Printf("Transcription successfully written to: %s", w.Output)
	} else {
		log.Println("Printing transcription to stdout")
		fmt.Println(transcriptionText)
	}

	log.Println("OpenAI Whisper transcription process completed")
	return nil
}
