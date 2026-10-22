package services

import (
	"testing"

	"api/modules/checkin/models"
	event_models "api/modules/event/models"

	"github.com/gofrs/uuid/v5"
)

func TestEvaluateReadings(t *testing.T) {
	txPower := -59
	event := &event_models.Event{
		RSSIThresholdDBM: -75,
		PathLossExponent: 2,
		Beacons: []event_models.EventBeacon{
			{
				BeaconID:    uuid.Must(uuid.FromString("00000000-0000-4000-8000-000000000001")),
				IdentityKey: "uuid:1:1",
				X:           0,
				Y:           0,
				TxPower:     &txPower,
			},
			{
				BeaconID:    uuid.Must(uuid.FromString("00000000-0000-4000-8000-000000000002")),
				IdentityKey: "uuid:1:2",
				X:           10,
				Y:           0,
				TxPower:     &txPower,
			},
			{
				BeaconID:    uuid.Must(uuid.FromString("00000000-0000-4000-8000-000000000003")),
				IdentityKey: "uuid:1:3",
				X:           0,
				Y:           10,
				TxPower:     &txPower,
			},
		},
	}

	service := &CheckinService{}
	readings, anchors, observed, aboveThreshold := service.evaluateReadings([]models.CheckinReadingInput{
		{IdentityKey: "uuid:1:1", RSSISamples: []int{-59, -60, -61}},
		{IdentityKey: "uuid:1:2", RSSISamples: []int{-85}},
		{IdentityKey: "unknown:9:9", RSSISamples: []int{-50}},
	}, event)

	if aboveThreshold != 1 {
		t.Fatalf("aboveThreshold = %d, want 1", aboveThreshold)
	}
	if len(readings) != 3 {
		t.Fatalf("readings = %d, want 3", len(readings))
	}
	if !readings[0].Matched || readings[0].MedianRSSI != -60 {
		t.Fatalf("unexpected first reading: %+v", readings[0])
	}
	if readings[0].DistanceM == nil || *readings[0].DistanceM <= 0 {
		t.Fatalf("expected a distance for the first reading")
	}
	if readings[2].Matched {
		t.Fatalf("unknown identity should not be matched")
	}
	if len(anchors) != 1 {
		t.Fatalf("anchors = %d, want 1", len(anchors))
	}
	if len(observed) != 3 {
		t.Fatalf("observed = %d, want 3", len(observed))
	}
}

func TestMedianRSSI(t *testing.T) {
	tests := []struct {
		values []int
		want   int
	}{
		{[]int{-80, -60, -70}, -70},
		{[]int{-80, -60}, -70},
		{[]int{-42}, -42},
		{nil, 0},
	}
	for _, test := range tests {
		if got := medianRSSI(test.values); got != test.want {
			t.Fatalf("medianRSSI(%v) = %d, want %d", test.values, got, test.want)
		}
	}
}
