package capture

import (
	"bytes"
	"fmt"
	"image"
	"image/jpeg"
	"runtime"
	"time"

	"github.com/kbinani/screenshot"
	"screen-memory-assistant/internal/config"
)

// resizeImage scales down image if it exceeds max dimensions while maintaining aspect ratio
func resizeImage(img image.Image, maxWidth, maxHeight int) image.Image {
	if maxWidth <= 0 || maxHeight <= 0 {
		return img
	}

	bounds := img.Bounds()
	width := bounds.Dx()
	height := bounds.Dy()

	// Check if resizing is needed
	if width <= maxWidth && height <= maxHeight {
		return img
	}

	// Calculate scaling factor to fit within bounds while maintaining aspect ratio
	scaleX := float64(maxWidth) / float64(width)
	scaleY := float64(maxHeight) / float64(height)
	scale := scaleX
	if scaleY < scaleX {
		scale = scaleY
	}

	newWidth := int(float64(width) * scale)
	newHeight := int(float64(height) * scale)

	// Simple nearest-neighbor resize
	resized := image.NewRGBA(image.Rect(0, 0, newWidth, newHeight))
	for y := 0; y < newHeight; y++ {
		for x := 0; x < newWidth; x++ {
			srcX := int(float64(x) / scale)
			srcY := int(float64(y) / scale)
			resized.Set(x, y, img.At(srcX, srcY))
		}
	}
	return resized
}

// Capture represents a screen capture with metadata
type Capture struct {
	Timestamp  time.Time
	Image      image.Image
	Compressed []byte
	DisplayNum int
}

// Capturer handles screen capture operations
type Capturer struct {
	config *config.CaptureConfig
}

// New creates a new screen capturer
func New(cfg *config.CaptureConfig) *Capturer {
	return &Capturer{
		config: cfg,
	}
}

// CaptureScreen captures all displays and returns them
func (c *Capturer) CaptureScreen() ([]*Capture, error) {
	n := screenshot.NumActiveDisplays()
	if n == 0 {
		return nil, fmt.Errorf("no active displays found")
	}

	var captures []*Capture
	now := time.Now()

	for i := 0; i < n; i++ {
		bounds := screenshot.GetDisplayBounds(i)
		img, err := screenshot.CaptureRect(bounds)
		if err != nil {
			return nil, fmt.Errorf("capturing display %d: %w", i, err)
		}

		// Compress full image
		compressed, err := c.compress(img)
		if err != nil {
			return nil, fmt.Errorf("compressing display %d: %w", i, err)
		}

		captures = append(captures, &Capture{
			Timestamp:  now,
			Image:      img,
			Compressed: compressed,
			DisplayNum: i,
		})
	}

	return captures, nil
}

// CapturePrimary captures only the primary display
func (c *Capturer) CapturePrimary() (*Capture, error) {
	n := screenshot.NumActiveDisplays()
	if n == 0 {
		return nil, fmt.Errorf("no active displays found")
	}

	bounds := screenshot.GetDisplayBounds(0)
	img, err := screenshot.CaptureRect(bounds)
	if err != nil {
		return nil, fmt.Errorf("capturing primary display: %w", err)
	}

	// Compress full image
	compressed, err := c.compress(img)
	if err != nil {
		return nil, fmt.Errorf("compressing: %w", err)
	}

	return &Capture{
		Timestamp:  time.Now(),
		Image:      img,
		Compressed: compressed,
		DisplayNum: 0,
	}, nil
}

// compress converts image to JPEG (with optional resize)
func (c *Capturer) compress(img image.Image) ([]byte, error) {
	var buf bytes.Buffer

	// Resize if configured
	if c.config.MaxWidth > 0 || c.config.MaxHeight > 0 {
		img = resizeImage(img, c.config.MaxWidth, c.config.MaxHeight)
	}

	quality := c.config.Quality
	if quality <= 0 || quality > 100 {
		quality = 60
	}

	opts := &jpeg.Options{Quality: quality}
	if err := jpeg.Encode(&buf, img, opts); err != nil {
		return nil, err
	}

	return buf.Bytes(), nil
}

// GetPlatform returns the current platform name
func GetPlatform() string {
	return runtime.GOOS
}
