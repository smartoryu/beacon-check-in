package services

import (
	"errors"
	"testing"
	"time"

	"api/modules/event/models"
)

func validRequest() *models.CreateEventRequest {
	return &models.CreateEventRequest{
		Title:     "Demo",
		PlaceName: "Hall",
		StartsAt:  mustTime("2026-01-01T10:00:00Z"),
		EndsAt:    mustTime("2026-01-01T12:00:00Z"),
		Timezone:  "Asia/Jakarta",
		Beacons: []models.EventBeaconInput{
			{BeaconID: "00000000-0000-4000-8000-000000000001", X: 1, Y: 1},
		},
	}
}

func TestBuildEventAppliesDefaults(t *testing.T) {
	service := NewEventService(EventServiceOpts{})
	event, ids, err := service.buildEvent(validRequest())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(ids) != 1 {
		t.Fatalf("beacon ids = %d, want 1", len(ids))
	}
	if event.FloorWidthM != 20 || event.FloorHeightM != 20 {
		t.Fatalf("floor = %vx%v, want 20x20", event.FloorWidthM, event.FloorHeightM)
	}
	if event.RSSIThresholdDBM != -75 {
		t.Fatalf("rssi threshold = %d, want -75", event.RSSIThresholdDBM)
	}
	if event.MinBeacons != 1 || event.PathLossExponent != 2 {
		t.Fatalf("unexpected defaults: min=%d pathloss=%v", event.MinBeacons, event.PathLossExponent)
	}
}

func TestBuildEventRejectsInvalidInputs(t *testing.T) {
	service := NewEventService(EventServiceOpts{})

	noBeacons := validRequest()
	noBeacons.Beacons = nil
	if _, _, err := service.buildEvent(noBeacons); !errors.Is(err, ErrNoBeacons) {
		t.Fatalf("expected ErrNoBeacons, got %v", err)
	}

	outside := validRequest()
	outside.Beacons[0].X = 21
	if _, _, err := service.buildEvent(outside); !errors.Is(err, ErrInvalidEvent) {
		t.Fatalf("expected ErrInvalidEvent for out-of-bounds position, got %v", err)
	}

	badTime := validRequest()
	badTime.EndsAt = badTime.StartsAt
	if _, _, err := service.buildEvent(badTime); !errors.Is(err, ErrInvalidEvent) {
		t.Fatalf("expected ErrInvalidEvent for bad time range, got %v", err)
	}

	badZone := validRequest()
	badZone.Timezone = "Mars/Olympus"
	if _, _, err := service.buildEvent(badZone); !errors.Is(err, ErrInvalidEvent) {
		t.Fatalf("expected ErrInvalidEvent for bad timezone, got %v", err)
	}

	duplicate := validRequest()
	duplicate.Beacons = append(duplicate.Beacons, duplicate.Beacons[0])
	if _, _, err := service.buildEvent(duplicate); !errors.Is(err, ErrInvalidEvent) {
		t.Fatalf("expected ErrInvalidEvent for duplicate beacon, got %v", err)
	}
}

func mustTime(value string) time.Time {
	parsed, err := time.Parse(time.RFC3339, value)
	if err != nil {
		panic(err)
	}
	return parsed
}
