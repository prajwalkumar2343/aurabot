package capture

import (
	"image"
	"image/color"
	"testing"

	"screen-memory-assistant/internal/config"
)

func TestCapturer_compress(t *testing.T) {
	// Test WebP compression (default)
	c := New(&config.CaptureConfig{Quality: 85})

	// Create a test image
	img := image.NewRGBA(image.Rect(0, 0, 100, 100))
	// Fill with some color
	for x := 0; x < 100; x++ {
		for y := 0; y < 100; y++ {
			img.Set(x, y, color.RGBA{100, 150, 200, 255})
		}
	}

	data, err := c.compress(img)
	if err != nil {
		t.Fatalf("compress failed: %v", err)
	}

	if len(data) == 0 {
		t.Error("compressed data is empty")
	}

	// WebP data should start with "RIFF" and have "WEBP" at position 8
	isWebP := len(data) >= 12 && string(data[0:4]) == "RIFF" && string(data[8:12]) == "WEBP"
	// JPEG data should start with 0xFF 0xD8
	isJPEG := len(data) >= 2 && data[0] == 0xFF && data[1] == 0xD8

	if !isWebP && !isJPEG {
		t.Errorf("compressed data is not valid WebP or JPEG. Got %v bytes starting with: %x", len(data), data[:min(12, len(data))])
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func TestCompressWebP(t *testing.T) {
	img := image.NewRGBA(image.Rect(0, 0, 100, 100))
	for x := 0; x < 100; x++ {
		for y := 0; y < 100; y++ {
			img.Set(x, y, color.RGBA{100, 150, 200, 255})
		}
	}

	opts := CompressOptions{Format: FormatWebP, Quality: 75}
	data, err := compress(img, opts)
	if err != nil {
		t.Fatalf("WebP compress failed: %v", err)
	}

	if len(data) == 0 {
		t.Error("WebP compressed data is empty")
	}

	// Check WebP magic bytes: RIFF....WEBP
	if len(data) < 12 || string(data[0:4]) != "RIFF" || string(data[8:12]) != "WEBP" {
		t.Error("compressed data is not valid WebP")
	}
}

func TestCompressJPEG(t *testing.T) {
	img := image.NewRGBA(image.Rect(0, 0, 100, 100))
	for x := 0; x < 100; x++ {
		for y := 0; y < 100; y++ {
			img.Set(x, y, color.RGBA{100, 150, 200, 255})
		}
	}

	opts := CompressOptions{Format: FormatJPEG, Quality: 75}
	data, err := compress(img, opts)
	if err != nil {
		t.Fatalf("JPEG compress failed: %v", err)
	}

	if len(data) == 0 {
		t.Error("JPEG compressed data is empty")
	}

	// Check JPEG magic bytes: 0xFF 0xD8
	if len(data) < 2 || data[0] != 0xFF || data[1] != 0xD8 {
		t.Error("compressed data is not valid JPEG")
	}
}

func TestGetContentType(t *testing.T) {
	tests := []struct {
		format  CompressionFormat
		want    string
	}{
		{FormatWebP, "image/webp"},
		{FormatJPEG, "image/jpeg"},
		{"", "image/webp"},
		{"unknown", "image/webp"},
	}

	for _, tt := range tests {
		got := GetContentType(tt.format)
		if got != tt.want {
			t.Errorf("GetContentType(%q) = %q, want %q", tt.format, got, tt.want)
		}
	}
}

func TestGetPlatform(t *testing.T) {
	platform := GetPlatform()
	if platform == "" {
		t.Error("GetPlatform() returned empty string")
	}

	// Should be one of known platforms
	validPlatforms := map[string]bool{
		"darwin":  true,
		"windows": true,
		"linux":   true,
	}

	if !validPlatforms[platform] {
		t.Errorf("GetPlatform() returned unknown platform: %s", platform)
	}
}
