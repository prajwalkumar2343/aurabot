package config

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

const (
	keyFileName = "secrets.key"
	keyLength   = 32 // 256 bits for AES-256
)

var encryptionKey []byte

func getKeyPath() string {
	execPath, _ := os.Executable()
	dir := filepath.Dir(execPath)
	if dir == "." {
		dir, _ = os.Getwd()
	}
	return filepath.Join(dir, keyFileName)
}

func loadOrGenerateKey() ([]byte, error) {
	keyPath := getKeyPath()

	// Try to load existing key
	if data, err := os.ReadFile(keyPath); err == nil {
		key := make([]byte, keyLength)
		n, err := base64.StdEncoding.Decode(key, data)
		if err != nil {
			return nil, fmt.Errorf("invalid key file: %w", err)
		}
		if n != keyLength {
			return nil, errors.New("key file has invalid length")
		}
		return key, nil
	}

	// Generate new key
	key := make([]byte, keyLength)
	if _, err := io.ReadFull(rand.Reader, key); err != nil {
		return nil, fmt.Errorf("failed to generate key: %w", err)
	}

	// Save key (base64 encoded)
	encoded := make([]byte, base64.StdEncoding.EncodedLen(keyLength))
	base64.StdEncoding.Encode(encoded, key)
	if err := os.WriteFile(keyPath, encoded, 0600); err != nil {
		return nil, fmt.Errorf("failed to save key: %w", err)
	}

	return key, nil
}

func init() {
	var err error
	encryptionKey, err = loadOrGenerateKey()
	if err != nil {
		fmt.Printf("Warning: Failed to initialize encryption: %v\n", err)
	}
}

func Encrypt(plaintext string) (string, error) {
	if encryptionKey == nil {
		return "", errors.New("encryption not initialized")
	}

	if plaintext == "" {
		return "", nil
	}

	block, err := aes.NewCipher(encryptionKey)
	if err != nil {
		return "", fmt.Errorf("failed to create cipher: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", fmt.Errorf("failed to create GCM: %w", err)
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return "", fmt.Errorf("failed to generate nonce: %w", err)
	}

	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(ciphertext), nil
}

func Decrypt(encrypted string) (string, error) {
	if encryptionKey == nil {
		return "", errors.New("encryption not initialized")
	}

	if encrypted == "" {
		return "", nil
	}

	data, err := base64.StdEncoding.DecodeString(encrypted)
	if err != nil {
		return "", fmt.Errorf("failed to decode: %w", err)
	}

	block, err := aes.NewCipher(encryptionKey)
	if err != nil {
		return "", fmt.Errorf("failed to create cipher: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", fmt.Errorf("failed to create GCM: %w", err)
	}

	nonceSize := gcm.NonceSize()
	if len(data) < nonceSize {
		return "", errors.New("ciphertext too short")
	}

	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", fmt.Errorf("failed to decrypt: %w", err)
	}

	return string(plaintext), nil
}
