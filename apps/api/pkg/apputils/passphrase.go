package apputils

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"strings"
)

// passphraseWords is a deliberately small, easy-to-type word list for one-time
// admin passwords. Four words plus two digits keeps the phrase readable while
// still giving enough entropy for a short-lived credential that must be changed
// on first sign-in.
var passphraseWords = []string{
	"amber", "anchor", "apple", "april", "arrow", "atlas", "autumn", "bamboo",
	"beacon", "berry", "birch", "bison", "bloom", "blue", "bolt", "breeze",
	"bridge", "bronze", "brook", "cabin", "cactus", "candle", "canyon", "cedar",
	"cherry", "cinder", "citrus", "clover", "cobalt", "comet", "copper", "coral",
	"cosmos", "cove", "crane", "crimson", "crystal", "dawn", "delta", "denim",
	"desert", "dolphin", "dragon", "dune", "eagle", "echo", "ember", "emerald",
	"falcon", "feather", "fern", "field", "finch", "flame", "flint", "forest",
	"frost", "garden", "ginger", "glacier", "gold", "granite", "grape", "harbor",
	"hazel", "honey", "horizon", "indigo", "island", "ivory", "jade", "jasper",
	"jungle", "kite", "lagoon", "lake", "lantern", "lava", "leaf", "lemon",
	"lilac", "linen", "lunar", "maple", "marble", "meadow", "meteor", "mint",
	"mist", "moon", "moss", "mountain", "nectar", "night", "north", "oak",
	"ocean", "olive", "onyx", "opal", "orange", "orchid", "otter", "panda",
	"pearl", "pebble", "pepper", "pine", "planet", "plum", "prairie", "quartz",
	"rain", "raven", "reef", "river", "robin", "rose", "ruby", "saffron",
	"sage", "sail", "sand", "scarlet", "shadow", "silver", "sky", "snow",
	"sparrow", "spruce", "star", "stone", "storm", "summit", "sunset", "tiger",
	"timber", "topaz", "tulip", "turtle", "valley", "velvet", "violet", "willow",
	"wind", "winter", "wolf", "zephyr",
}

// GeneratePassphrase returns a human-readable phrase like
// "cobalt-lunar-pepper-tiger-42". The words are unique within one phrase and
// the suffix is a zero-padded 0–99 number.
func GeneratePassphrase(wordCount int) (string, error) {
	if wordCount < 3 || wordCount > 6 {
		return "", fmt.Errorf("passphrase word count must be between 3 and 6")
	}

	used := make(map[int]struct{}, wordCount)
	words := make([]string, 0, wordCount)
	for len(words) < wordCount {
		index, err := randomInt(len(passphraseWords))
		if err != nil {
			return "", err
		}
		if _, exists := used[index]; exists {
			continue
		}
		used[index] = struct{}{}
		words = append(words, passphraseWords[index])
	}

	number, err := randomInt(100)
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("%s-%02d", strings.Join(words, "-"), number), nil
}

func randomInt(limit int) (int, error) {
	if limit <= 0 {
		return 0, fmt.Errorf("limit must be positive")
	}
	value, err := rand.Int(rand.Reader, big.NewInt(int64(limit)))
	if err != nil {
		return 0, err
	}
	return int(value.Int64()), nil
}
