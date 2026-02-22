package capture

import (
	"image"
	"image/color"
	"testing"

	"screen-memory-assistant/internal/config"
)

func TestCapturer_compress(t *testing.T) {
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

	// JPEG data should start with 0xFF 0xD8
	if data[0] != 0xFF || data[1] != 0xD8 {
		t.Error("compressed data is not valid JPEG")
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
