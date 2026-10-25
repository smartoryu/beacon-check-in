package apputils

import (
	"strconv"
	"strings"
	"testing"
)

func TestGenerateTemporaryPassword(t *testing.T) {
	seen := make(map[string]struct{})
	for attempt := 0; attempt < 200; attempt++ {
		password, err := GenerateTemporaryPassword()
		if err != nil {
			t.Fatalf("GenerateTemporaryPassword() error = %v", err)
		}
		seen[password] = struct{}{}

		if len(password) < 8 || len(password) > 10 {
			t.Fatalf("password %q has length %d, want 8-10 characters", password, len(password))
		}

		parts := strings.Split(password, "-")
		if len(parts) != 2 {
			t.Fatalf("password %q has %d parts, want one word and one number", password, len(parts))
		}
		if len(parts[0]) < 5 || len(parts[0]) > 7 {
			t.Fatalf("word %q has length %d, want 5-7 characters", parts[0], len(parts[0]))
		}
		found := false
		for _, candidate := range passphraseWords {
			if parts[0] == candidate {
				found = true
				break
			}
		}
		if !found {
			t.Fatalf("word %q is not in the password word list", parts[0])
		}

		suffix, err := strconv.Atoi(parts[1])
		if err != nil || suffix < 0 || suffix > 99 {
			t.Fatalf("suffix %q is not a 0-99 number", parts[1])
		}
		if len(parts[1]) != 2 {
			t.Fatalf("suffix %q should be zero-padded to two digits", parts[1])
		}
	}
	if len(seen) < 2 {
		t.Fatal("expected more than one unique password across 200 attempts")
	}
}
