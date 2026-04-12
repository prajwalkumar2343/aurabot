package capture

import (
	"bytes"
	"fmt"
	"image"
	"image/jpeg"

	"github.com/chai2010/webp"
)

// CompressionFormat represents the image compression format type
type CompressionFormat string

const (
	FormatJPEG CompressionFormat = "jpeg"
	FormatWebP CompressionFormat = "webp"
)

// CompressOptions holds compression configuration
type CompressOptions struct {
	Format  CompressionFormat
	Quality int
}

// compress compresses an image to the specified format with quality settings
func compress(img image.Image, opts CompressOptions) ([]byte, error) {
	quality := opts.Quality
	if quality <= 0 || quality > 100 {
		quality = 60
	}

	switch opts.Format {
	case FormatWebP:
		// WebP encoding with quality (1-100)
		data, err := webp.EncodeRGB(img, float32(quality))
		if err != nil {
			// Fallback to JPEG if WebP fails
			return compressJPEG(img, quality)
		}
		return data, nil
	case FormatJPEG:
		return compressJPEG(img, quality)
	default:
		// Default to WebP for better compression
		data, err := webp.EncodeRGB(img, float32(quality))
		if err != nil {
			return compressJPEG(img, quality)
		}
		return data, nil
	}
}

// compressJPEG compresses image using JPEG format
func compressJPEG(img image.Image, quality int) ([]byte, error) {
	var buf bytes.Buffer
	opts := &jpeg.Options{Quality: quality}
	if err := jpeg.Encode(&buf, img, opts); err != nil {
		return nil, fmt.Errorf("jpeg encode: %w", err)
	}
	return buf.Bytes(), nil
}

// GetContentType returns the appropriate MIME type for the compression format
func GetContentType(format CompressionFormat) string {
	switch format {
	case FormatWebP:
		return "image/webp"
	case FormatJPEG:
		return "image/jpeg"
	default:
		return "image/webp"
	}
}
