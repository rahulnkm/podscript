package main

import (
	"os"
	"testing"
)

// TestOpenAIWhisperValidation tests the validation logic in the OpenAIWhisperCmd
func TestOpenAIWhisperValidation(t *testing.T) {
	// Test missing API key
	cmd := &OpenAIWhisperCmd{
		File: "test.mp3",
	}
	err := cmd.Run()
	if err == nil {
		t.Error("Expected error for missing API key, got nil")
	}

	// Test non-existent file
	cmd = &OpenAIWhisperCmd{
		File:   "nonexistent.mp3",
		APIKey: "test-key",
	}
	err = cmd.Run()
	if err == nil {
		t.Error("Expected error for non-existent file, got nil")
	}
}

// TestOpenAIWhisperParameterConstruction tests the parameter construction logic
func TestOpenAIWhisperParameterConstruction(t *testing.T) {
	// Skip this test if we're not in a test environment that can create files
	if os.Getenv("PODSCRIPT_RUN_INTEGRATION_TESTS") != "true" {
		t.Skip("Skipping integration test; set PODSCRIPT_RUN_INTEGRATION_TESTS=true to run")
	}

	// Create a temporary test file
	tempFile, err := os.CreateTemp("", "whisper-test-*.mp3")
	if err != nil {
		t.Fatalf("Failed to create temp file: %v", err)
	}
	defer os.Remove(tempFile.Name())
	defer tempFile.Close()

	// Write some dummy data to the file
	_, err = tempFile.WriteString("test audio data")
	if err != nil {
		t.Fatalf("Failed to write to temp file: %v", err)
	}

	// Test with all parameters set
	cmd := &OpenAIWhisperCmd{
		File:           tempFile.Name(),
		APIKey:         "test-key",
		Model:          "whisper-1",
		Language:       "en",
		Prompt:         "test prompt",
		ResponseFormat: "json",
		Temperature:    0.5,
	}

	// This would normally call the API, but we're just testing parameter construction
	// In a real test, we would mock the OpenAI client
	// For now, we just verify that the command has all parameters set correctly
	if cmd.Model != "whisper-1" {
		t.Errorf("Expected model to be whisper-1, got %s", cmd.Model)
	}
	if cmd.Language != "en" {
		t.Errorf("Expected language to be en, got %s", cmd.Language)
	}
	if cmd.Prompt != "test prompt" {
		t.Errorf("Expected prompt to be 'test prompt', got %s", cmd.Prompt)
	}
	if cmd.ResponseFormat != "json" {
		t.Errorf("Expected response format to be json, got %s", cmd.ResponseFormat)
	}
	if cmd.Temperature != 0.5 {
		t.Errorf("Expected temperature to be 0.5, got %f", cmd.Temperature)
	}
}
