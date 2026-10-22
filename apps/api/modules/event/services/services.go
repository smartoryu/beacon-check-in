package services

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"

	"api/modules/event/models"
	"api/modules/event/repository"

	"github.com/gofrs/uuid/v5"
)

var (
	ErrEventNotFound     = errors.New("event not found")
	ErrInvalidEvent      = errors.New("invalid event")
	ErrNoBeacons         = errors.New("an event must have at least one beacon")
	ErrBeaconUnavailable = errors.New("one or more beacons are not available")
)

type EventService struct {
	logger *slog.Logger
	repo   repository.EventRepository
}

type EventServiceOpts struct {
	Logger *slog.Logger
	Repo   repository.EventRepository
}

func NewEventService(opts EventServiceOpts) *EventService {
	return &EventService{logger: opts.Logger, repo: opts.Repo}
}

func (s *EventService) Create(ctx context.Context, req *models.CreateEventRequest, actorID uuid.UUID) (*models.Event, error) {
	event, beaconIDs, err := s.buildEvent(req)
	if err != nil {
		return nil, err
	}
	event.CreatedBy = &actorID
	if err := s.repo.EnsureActiveBeacons(ctx, beaconIDs); err != nil {
		return nil, ErrBeaconUnavailable
	}
	if err := s.repo.Create(ctx, event); err != nil {
		return nil, err
	}
	return s.Get(ctx, event.ID)
}

func (s *EventService) Update(ctx context.Context, id uuid.UUID, req *models.UpdateEventRequest) (*models.Event, error) {
	existing, err := s.repo.Get(ctx, id)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrEventNotFound
		}
		return nil, err
	}

	updated, beaconIDs, err := s.buildEvent(req)
	if err != nil {
		return nil, err
	}
	if err := s.repo.EnsureActiveBeacons(ctx, beaconIDs); err != nil {
		return nil, ErrBeaconUnavailable
	}
	updated.ID = existing.ID
	updated.CreatedBy = existing.CreatedBy
	updated.CreatedAt = existing.CreatedAt
	if err := s.repo.Update(ctx, updated); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrEventNotFound
		}
		return nil, err
	}
	return s.Get(ctx, id)
}

func (s *EventService) Get(ctx context.Context, id uuid.UUID) (*models.Event, error) {
	event, err := s.repo.Get(ctx, id)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrEventNotFound
		}
		return nil, err
	}
	return event, nil
}

func (s *EventService) List(ctx context.Context, filter *models.EventFilter) ([]*models.Event, error) {
	return s.repo.List(ctx, filter)
}

func (s *EventService) Active(ctx context.Context) ([]*models.Event, error) {
	return s.repo.Active(ctx)
}

func (s *EventService) Delete(ctx context.Context, id uuid.UUID) error {
	if err := s.repo.SoftDelete(ctx, id); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return ErrEventNotFound
		}
		return err
	}
	return nil
}

func (s *EventService) SetBeacons(ctx context.Context, id uuid.UUID, req *models.SetEventBeaconsRequest) (*models.Event, error) {
	event, err := s.repo.Get(ctx, id)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrEventNotFound
		}
		return nil, err
	}
	if len(req.Beacons) == 0 {
		return nil, ErrNoBeacons
	}
	beaconIDs, err := s.validateBeaconInputs(req.Beacons, event.FloorWidthM, event.FloorHeightM)
	if err != nil {
		return nil, err
	}
	if err := s.repo.EnsureActiveBeacons(ctx, beaconIDs); err != nil {
		return nil, ErrBeaconUnavailable
	}
	if err := s.repo.SetBeacons(ctx, id, req.Beacons); err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrEventNotFound
		}
		return nil, err
	}
	return s.Get(ctx, id)
}

func (s *EventService) buildEvent(req *models.CreateEventRequest) (*models.Event, []uuid.UUID, error) {
	timezone := strings.TrimSpace(req.Timezone)
	if timezone == "" {
		timezone = "Asia/Jakarta"
	}
	if _, err := time.LoadLocation(timezone); err != nil {
		return nil, nil, fmt.Errorf("%w: invalid timezone %q", ErrInvalidEvent, timezone)
	}
	if req.StartsAt.IsZero() || req.EndsAt.IsZero() {
		return nil, nil, fmt.Errorf("%w: starts_at and ends_at are required", ErrInvalidEvent)
	}
	if !req.EndsAt.After(req.StartsAt) {
		return nil, nil, fmt.Errorf("%w: ends_at must be after starts_at", ErrInvalidEvent)
	}

	floorWidth := req.FloorWidthM
	if floorWidth <= 0 {
		floorWidth = 20
	}
	floorHeight := req.FloorHeightM
	if floorHeight <= 0 {
		floorHeight = 20
	}
	rssiThreshold := req.RSSIThresholdDBM
	if rssiThreshold == 0 {
		rssiThreshold = -75
	}
	if rssiThreshold < -120 || rssiThreshold > 0 {
		return nil, nil, fmt.Errorf("%w: rssi_threshold_dbm must be between -120 and 0", ErrInvalidEvent)
	}
	minBeacons := req.MinBeacons
	if minBeacons <= 0 {
		minBeacons = 1
	}
	pathLoss := req.PathLossExponent
	if pathLoss <= 0 {
		pathLoss = 2.0
	}
	if req.CoverageRadiusM != nil && *req.CoverageRadiusM <= 0 {
		return nil, nil, fmt.Errorf("%w: coverage_radius_m must be positive", ErrInvalidEvent)
	}
	if len(req.Beacons) == 0 {
		return nil, nil, ErrNoBeacons
	}
	beaconIDs, err := s.validateBeaconInputs(req.Beacons, floorWidth, floorHeight)
	if err != nil {
		return nil, nil, err
	}

	event := &models.Event{
		Title:            strings.TrimSpace(req.Title),
		Description:      req.Description,
		PlaceName:        strings.TrimSpace(req.PlaceName),
		Address:          req.Address,
		Latitude:         req.Latitude,
		Longitude:        req.Longitude,
		StartsAt:         req.StartsAt.UTC(),
		EndsAt:           req.EndsAt.UTC(),
		Timezone:         timezone,
		FloorWidthM:      floorWidth,
		FloorHeightM:     floorHeight,
		RSSIThresholdDBM: rssiThreshold,
		MinBeacons:       minBeacons,
		CoverageRadiusM:  req.CoverageRadiusM,
		PathLossExponent: pathLoss,
		Beacons:          eventBeaconsFromInputs(req.Beacons),
	}
	return event, beaconIDs, nil
}

func (s *EventService) validateBeaconInputs(inputs []models.EventBeaconInput, floorWidth, floorHeight float64) ([]uuid.UUID, error) {
	if len(inputs) == 0 {
		return nil, ErrNoBeacons
	}
	seen := map[uuid.UUID]struct{}{}
	ids := make([]uuid.UUID, 0, len(inputs))
	for _, input := range inputs {
		id, err := uuid.FromString(input.BeaconID)
		if err != nil {
			return nil, fmt.Errorf("%w: invalid beacon id %q", ErrInvalidEvent, input.BeaconID)
		}
		if _, exists := seen[id]; exists {
			return nil, fmt.Errorf("%w: duplicate beacon %s", ErrInvalidEvent, id.String())
		}
		seen[id] = struct{}{}
		if input.X < 0 || input.X > floorWidth || input.Y < 0 || input.Y > floorHeight {
			return nil, fmt.Errorf("%w: beacon %s position is outside the floor grid", ErrInvalidEvent, id.String())
		}
		ids = append(ids, id)
	}
	return ids, nil
}

func eventBeaconsFromInputs(inputs []models.EventBeaconInput) []models.EventBeacon {
	beacons := make([]models.EventBeacon, 0, len(inputs))
	for _, input := range inputs {
		id, _ := uuid.FromString(input.BeaconID)
		beacons = append(beacons, models.EventBeacon{
			BeaconID:        id,
			X:               input.X,
			Y:               input.Y,
			TxPowerOverride: input.TxPowerOverride,
		})
	}
	return beacons
}
