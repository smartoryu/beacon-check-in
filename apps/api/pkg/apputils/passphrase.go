package apputils

import (
	"crypto/rand"
	"fmt"
	"math/big"
)

// passphraseWords is a deliberately small, easy-to-type word list for one-time
// admin passwords. Temporary passwords use one word plus a two-digit number so
// they stay at or below 10 characters.
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

// GenerateTemporaryPassword returns a short, readable one-time password such as
// "cobalt-42". The word is 5–7 characters and the suffix is a zero-padded
// 0–99 number, so the result is always 8–10 characters long.
func GenerateTemporaryPassword() (string, error) {
	// Keep the hyphen plus the two-digit number inside the 10-character limit.
	candidates := make([]string, 0, len(passphraseWords))
	for _, word := range passphraseWords {
		if len(word) >= 5 && len(word) <= 7 {
			candidates = append(candidates, word)
		}
	}

	index, err := randomInt(len(candidates))
	if err != nil {
		return "", err
	}
	number, err := randomInt(100)
	if err != nil {
		return "", err
	}

	return fmt.Sprintf("%s-%02d", candidates[index], number), nil
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
