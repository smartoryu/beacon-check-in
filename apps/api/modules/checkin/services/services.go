package services

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"math"
	"sort"
	"time"

	"api/modules/checkin/models"
	"api/modules/checkin/repository"
	event_models "api/modules/event/models"
	event_repo "api/modules/event/repository"
	"api/pkg/apputils"

	"github.com/gofrs/uuid/v5"
)

var (
	ErrEventNotFound    = errors.New("event not found")
	ErrAlreadyCheckedIn = errors.New("already checked in")
	ErrDuplicate        = errors.New("duplicate check-in")
)

type CheckinService struct {
	logger        *slog.Logger
	repo          repository.CheckinRepository
	eventRepo     event_repo.EventRepository
	maxOfflineAge time.Duration
	maxClockSkew  time.Duration
}

type CheckinServiceOpts struct {
	Logger        *slog.Logger
	Repo          repository.CheckinRepository
	EventRepo     event_repo.EventRepository
	MaxOfflineAge time.Duration
	MaxClockSkew  time.Duration
}

func NewCheckinService(opts CheckinServiceOpts) *CheckinService {
	if opts.MaxOfflineAge <= 0 {
		opts.MaxOfflineAge = 24 * time.Hour
	}
	if opts.MaxClockSkew <= 0 {
		opts.MaxClockSkew = 5 * time.Minute
	}
	return &CheckinService{
		logger:        opts.Logger,
		repo:          opts.Repo,
		eventRepo:     opts.EventRepo,
		maxOfflineAge: opts.MaxOfflineAge,
		maxClockSkew:  opts.MaxClockSkew,
	}
}

// Submit validates an offline-first check-in attempt and persists it.
func (s *CheckinService) Submit(ctx context.Context, eventID, userID uuid.UUID, req *models.SubmitCheckinRequest) (*models.SubmitCheckinResponse, error) {
	clientID, err := uuid.FromString(req.ClientCheckinID)
	if err != nil {
		return nil, fmt.Errorf("invalid client_checkin_id: %w", err)
	}

	if existing, err := s.repo.GetByClientID(ctx, clientID); err == nil && existing != nil {
		return &models.SubmitCheckinResponse{Checkin: existing, Duplicate: true}, nil
	} else if err != nil && !errors.Is(err, repository.ErrNotFound) {
		return nil, err
	}

	event, err := s.eventRepo.Get(ctx, eventID)
	if err != nil {
		if errors.Is(err, event_repo.ErrNotFound) {
			return nil, ErrEventNotFound
		}
		return nil, err
	}

	now := time.Now().UTC()
	recordedAt := req.RecordedAt.UTC()

	switch {
	case recordedAt.After(now.Add(s.maxClockSkew)):
		return s.reject(ctx, req, clientID, eventID, userID, recordedAt, now, "invalid_recorded_at", event)
	case now.Sub(recordedAt) > s.maxOfflineAge:
		return s.reject(ctx, req, clientID, eventID, userID, recordedAt, now, "checkin_expired", event)
	case recordedAt.Before(event.StartsAt):
		return s.reject(ctx, req, clientID, eventID, userID, recordedAt, now, "event_not_started", event)
	case recordedAt.After(event.EndsAt):
		return s.reject(ctx, req, clientID, eventID, userID, recordedAt, now, "event_ended", event)
	}

	if accepted, err := s.repo.ExistsAccepted(ctx, eventID, userID); err != nil {
		return nil, err
	} else if accepted {
		return s.reject(ctx, req, clientID, eventID, userID, recordedAt, now, "already_checked_in", event)
	}

	readings, anchors, observed, aboveThreshold := s.evaluateReadings(req.Readings, event)
	if aboveThreshold < event.MinBeacons {
		return s.rejectWithReadings(ctx, req, clientID, eventID, userID, recordedAt, now, "not_enough_beacons", event, readings, observed)
	}

	var estX, estY, accuracy *float64
	if len(anchors) >= 3 {
		x, y, acc, ok := apputils.Trilaterate(anchors)
		if ok {
			estX, estY, accuracy = &x, &y, &acc
			if event.CoverageRadiusM != nil {
				centerX := event.FloorWidthM / 2
				centerY := event.FloorHeightM / 2
				if distance(centerX, centerY, x, y) > *event.CoverageRadiusM {
					return s.rejectWithReadings(ctx, req, clientID, eventID, userID, recordedAt, now, "outside_coverage", event, readings, observed)
				}
			}
		}
	} else if len(anchors) > 0 {
		x, y, acc, ok := apputils.WeightedCentroid(anchors)
		if ok {
			estX, estY, accuracy = &x, &y, &acc
		}
	}

	checkin := &models.Checkin{
		ClientCheckinID: clientID,
		EventID:         eventID,
		UserID:          userID,
		Status:          "accepted",
		RecordedAt:      recordedAt,
		ReceivedAt:      now,
		IsOffline:       now.Sub(recordedAt) > 2*time.Minute,
		EstimatedX:      estX,
		EstimatedY:      estY,
		AccuracyM:       accuracy,
		UsedBeaconCount: aboveThreshold,
		Readings:        readings,
		DeviceInfo:      req.DeviceInfo,
	}
	if err := s.repo.Create(ctx, checkin); err != nil {
		if errors.Is(err, repository.ErrAlreadyCheckedIn) {
			return nil, ErrAlreadyCheckedIn
		}
		if errors.Is(err, repository.ErrDuplicate) {
			if existing, getErr := s.repo.GetByClientID(ctx, clientID); getErr == nil {
				return &models.SubmitCheckinResponse{Checkin: existing, Duplicate: true}, nil
			}
		}
		return nil, err
	}
	return &models.SubmitCheckinResponse{Checkin: checkin, Observed: observed}, nil
}

func (s *CheckinService) evaluateReadings(inputs []models.CheckinReadingInput, event *event_models.Event) ([]models.CheckinReading, []apputils.Anchor, []string, int) {
	byIdentity := make(map[string]event_models.EventBeacon, len(event.Beacons))
	for _, beacon := range event.Beacons {
		byIdentity[beacon.IdentityKey] = beacon
	}

	readings := make([]models.CheckinReading, 0, len(inputs))
	anchors := make([]apputils.Anchor, 0, len(inputs))
	observed := make([]string, 0, len(inputs))
	aboveThreshold := 0

	for _, input := range inputs {
		median := medianRSSI(input.RSSISamples)
		reading := models.CheckinReading{
			IdentityKey:      input.IdentityKey,
			Matched:          false,
			MedianRSSI:       median,
			Samples:          input.RSSISamples,
			PlatformDeviceID: input.PlatformDeviceID,
			TxPower:          input.TxPower,
		}
		observed = append(observed, input.IdentityKey)

		beacon, ok := byIdentity[input.IdentityKey]
		if !ok {
			readings = append(readings, reading)
			continue
		}
		reading.Matched = true
		beaconID := beacon.BeaconID
		reading.BeaconID = &beaconID

		txPower := input.TxPower
		if beacon.TxPowerOverride != nil {
			txPower = beacon.TxPowerOverride
		} else if beacon.TxPower != nil {
			txPower = beacon.TxPower
		}
		reading.TxPower = txPower

		if median >= event.RSSIThresholdDBM {
			aboveThreshold++
		}
		if txPower != nil && median >= event.RSSIThresholdDBM {
			if distance, ok := apputils.DistanceFromRSSI(*txPower, median, event.PathLossExponent); ok {
				distance = apputils.ClampDistance(distance, 50)
				reading.DistanceM = &distance
				anchors = append(anchors, apputils.Anchor{
					X:         beacon.X,
					Y:         beacon.Y,
					DistanceM: distance,
					Weight:    1 / (distance*distance + 1),
				})
			}
		}
		readings = append(readings, reading)
	}
	return readings, anchors, observed, aboveThreshold
}

func (s *CheckinService) reject(ctx context.Context, req *models.SubmitCheckinRequest, clientID uuid.UUID, eventID, userID uuid.UUID, recordedAt, now time.Time, reason string, event *event_models.Event) (*models.SubmitCheckinResponse, error) {
	return s.rejectWithReadings(ctx, req, clientID, eventID, userID, recordedAt, now, reason, event, nil, nil)
}

func (s *CheckinService) rejectWithReadings(ctx context.Context, req *models.SubmitCheckinRequest, clientID uuid.UUID, eventID, userID uuid.UUID, recordedAt, now time.Time, reason string, event *event_models.Event, readings []models.CheckinReading, observed []string) (*models.SubmitCheckinResponse, error) {
	aboveThreshold := 0
	if readings == nil {
		readings, _, observed, aboveThreshold = s.evaluateReadings(req.Readings, event)
	}
	checkin := &models.Checkin{
		ClientCheckinID: clientID,
		EventID:         eventID,
		UserID:          userID,
		Status:          "rejected",
		RejectReason:    &reason,
		RecordedAt:      recordedAt,
		ReceivedAt:      now,
		IsOffline:       now.Sub(recordedAt) > 2*time.Minute,
		UsedBeaconCount: aboveThreshold,
		Readings:        readings,
		DeviceInfo:      req.DeviceInfo,
	}
	if err := s.repo.Create(ctx, checkin); err != nil {
		if errors.Is(err, repository.ErrAlreadyCheckedIn) {
			return nil, ErrAlreadyCheckedIn
		}
		return nil, err
	}
	return &models.SubmitCheckinResponse{Checkin: checkin, Reason: reason, Observed: observed}, nil
}

func (s *CheckinService) ListByEvent(ctx context.Context, eventID uuid.UUID, filter *models.CheckinFilter) ([]*models.Checkin, error) {
	return s.repo.ListByEvent(ctx, eventID, filter)
}

func (s *CheckinService) ListByUser(ctx context.Context, userID uuid.UUID, filter *models.CheckinFilter) ([]*models.Checkin, error) {
	return s.repo.ListByUser(ctx, userID, filter)
}

func medianRSSI(values []int) int {
	if len(values) == 0 {
		return 0
	}
	sorted := append([]int(nil), values...)
	sort.Ints(sorted)
	mid := len(sorted) / 2
	if len(sorted)%2 == 1 {
		return sorted[mid]
	}
	return (sorted[mid-1] + sorted[mid]) / 2
}

func distance(x1, y1, x2, y2 float64) float64 {
	return math.Hypot(x1-x2, y1-y2)
}
