package apputils

import (
	"math"
	"testing"
)

func TestDistanceFromRSSI(t *testing.T) {
	tests := []struct {
		name      string
		txPower   int
		rssi      int
		pathLoss  float64
		want      float64
		tolerance float64
	}{
		{"one metre", -59, -59, 2, 1, 0.001},
		{"ten metres", -59, -79, 2, 10, 0.001},
		{"custom path loss", -59, -79, 3, math.Pow(10, 20.0/30.0), 0.001},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got, ok := DistanceFromRSSI(test.txPower, test.rssi, test.pathLoss)
			if !ok {
				t.Fatal("expected a valid distance")
			}
			if math.Abs(got-test.want) > test.tolerance {
				t.Fatalf("distance = %v, want %v", got, test.want)
			}
		})
	}
}

func TestTrilaterate(t *testing.T) {
	// Point (3, 4) is 5m from (0,0), sqrt(65) from (10,0), sqrt(58) from (0,10).
	anchors := []Anchor{
		{X: 0, Y: 0, DistanceM: 5},
		{X: 10, Y: 0, DistanceM: math.Sqrt(65)},
		{X: 0, Y: 10, DistanceM: math.Sqrt(45)},
	}
	x, y, accuracy, ok := Trilaterate(anchors)
	if !ok {
		t.Fatal("expected trilateration to succeed")
	}
	if math.Abs(x-3) > 0.01 || math.Abs(y-4) > 0.01 {
		t.Fatalf("position = (%v, %v), want (3, 4)", x, y)
	}
	if accuracy > 0.01 {
		t.Fatalf("accuracy = %v, want near zero", accuracy)
	}
}

func TestTrilaterateFallsBackForDegenerateGeometry(t *testing.T) {
	anchors := []Anchor{
		{X: 0, Y: 0, DistanceM: 1},
		{X: 1, Y: 1, DistanceM: 1},
		{X: 2, Y: 2, DistanceM: 1},
	}
	_, _, _, ok := Trilaterate(anchors)
	if !ok {
		t.Fatal("expected a weighted centroid fallback")
	}
}

func TestWeightedCentroid(t *testing.T) {
	x, y, _, ok := WeightedCentroid([]Anchor{
		{X: 0, Y: 0, DistanceM: 1},
		{X: 10, Y: 10, DistanceM: 10},
	})
	if !ok {
		t.Fatal("expected centroid")
	}
	if x <= 0 || x >= 10 || y <= 0 || y >= 10 {
		t.Fatalf("centroid = (%v, %v), expected between the anchors", x, y)
	}
}
