package apputils

import (
	"strconv"
	"strings"
	"testing"
)

func TestGeneratePassphrase(t *testing.T) {
	first, err := GeneratePassphrase(4)
	if err != nil {
		t.Fatalf("GeneratePassphrase() error = %v", err)
	}
	second, err := GeneratePassphrase(4)
	if err != nil {
		t.Fatalf("GeneratePassphrase() second error = %v", err)
	}
	if first == second {
		t.Fatalf("expected two different phrases, got %q twice", first)
	}

	parts := strings.Split(first, "-")
	if len(parts) != 5 {
		t.Fatalf("passphrase %q has %d parts, want 4 words + number", first, len(parts))
	}
	for _, word := range parts[:4] {
		found := false
		for _, candidate := range passphraseWords {
			if word == candidate {
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("word %q is not in the passphrase word list", word)
		}
	}
	suffix, err := strconv.Atoi(parts[4])
	if err != nil || suffix < 0 || suffix > 99 {
		t.Fatalf("suffix %q is not a 0-99 number", parts[4])
	}
	if len(parts[4]) != 2 {
		t.Fatalf("suffix %q should be zero-padded to two digits", parts[4])
	}
}

func TestGeneratePassphraseRejectsShortPhrases(t *testing.T) {
	if _, err := GeneratePassphrase(2); err == nil {
		t.Fatal("expected an error for a two-word phrase")
	}
}
