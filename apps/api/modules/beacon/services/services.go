package services

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"sort"
	"strings"
	"time"

	"api/modules/beacon/models"
	"api/modules/beacon/repository"
	user_models "api/modules/user/models"

	"github.com/gofrs/uuid/v5"
)

var (
	ErrBeaconExists         = errors.New("beacon already registered")
	ErrBeaconNotFound       = errors.New("beacon not found")
	ErrBeaconInActiveEvent  = errors.New("beacon is attached to an ongoing or upcoming event")
	ErrBeaconNotDeleted     = errors.New("beacon is not deleted")
	ErrBeaconAlreadyDeleted = errors.New("beacon is already deleted")
	ErrPendingRequest       = errors.New("a pending request already exists for this beacon and action")
	ErrRequestNotFound      = errors.New("change request not found")
	ErrRequestNotPending    = errors.New("change request is not pending")
)

type BeaconService struct {
	logger *slog.Logger
	repo   repository.BeaconRepository
}

type BeaconServiceOpts struct {
	Logger *slog.Logger
	Repo   repository.BeaconRepository
}

func NewBeaconService(opts BeaconServiceOpts) *BeaconService {
	return &BeaconService{logger: opts.Logger, repo: opts.Repo}
}

func (s *BeaconService) Register(ctx context.Context, req *models.RegisterBeaconRequest, actorID uuid.UUID) (*models.Beacon, error) {
	proximity, err := uuid.FromString(strings.ToLower(strings.TrimSpace(req.ProximityUUID)))
	if err != nil {
		return nil, fmt.Errorf("invalid proximity uuid: %w", err)
	}
	identityKey := fmt.Sprintf("%s:%d:%d", proximity.String(), req.Major, req.Minor)

	if existing, err := s.repo.GetByIdentity(ctx, identityKey); err == nil && existing != nil {
		return nil, ErrBeaconExists
	} else if err != nil && !errors.Is(err, repository.ErrNotFound) {
		return nil, err
	}

	metadata := req.Metadata
	if metadata == nil {
		metadata = map[string]any{}
	}
	if len(req.RSSISamples) > 0 {
		metadata["registration_rssi_samples"] = req.RSSISamples
		metadata["registration_rssi_median"] = median(req.RSSISamples)
	}
	now := time.Now().UTC()

	beacon := &models.Beacon{
		IdentityKey:       identityKey,
		ProximityUUID:     proximity,
		Major:             req.Major,
		Minor:             req.Minor,
		Label:             strings.TrimSpace(req.Label),
		LocalName:         req.LocalName,
		PlatformDeviceID:  req.PlatformDeviceID,
		DeviceAddressType: req.DeviceAddressType,
		TxPower:           req.TxPower,
		Metadata:          metadata,
		GattInfo:          req.GattInfo,
		GattReadAt:        nil,
		RegisteredBy:      &actorID,
		RegisteredAt:      now,
		LastSeenAt:        &now,
	}
	if len(req.GattInfo) > 0 {
		beacon.GattReadAt = &now
	}
	if err := s.repo.Create(ctx, beacon); err != nil {
		if errors.Is(err, repository.ErrBeaconExists) {
			return nil, ErrBeaconExists
		}
		return nil, err
	}
	return beacon, nil
}

func (s *BeaconService) Lookup(ctx context.Context, identities []string) ([]models.LookupItem, error) {
	normalized := make([]string, 0, len(identities))
	for _, identity := range identities {
		normalized = append(normalized, strings.ToLower(strings.TrimSpace(identity)))
	}
	beacons, err := s.repo.Lookup(ctx, normalized)
	if err != nil {
		return nil, err
	}
	found := make(map[string]*models.Beacon, len(beacons))
	for _, beacon := range beacons {
		found[beacon.IdentityKey] = beacon
	}
	items := make([]models.LookupItem, 0, len(normalized))
	for _, identity := range normalized {
		item := models.LookupItem{IdentityKey: identity, Status: "unknown"}
		if beacon, ok := found[identity]; ok {
			item.Beacon = beacon
			if beacon.DeletedAt != nil {
				item.Status = "deleted"
			} else {
				item.Status = "registered"
			}
		}
		items = append(items, item)
	}
	return items, nil
}

func (s *BeaconService) List(ctx context.Context, filter *models.BeaconFilter) ([]*models.Beacon, error) {
	return s.repo.List(ctx, filter)
}

func (s *BeaconService) Get(ctx context.Context, id uuid.UUID) (*models.Beacon, error) {
	beacon, err := s.repo.GetByID(ctx, id)
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrBeaconNotFound
		}
		return nil, err
	}
	return beacon, nil
}

func (s *BeaconService) UpdateLabel(ctx context.Context, id uuid.UUID, label string) (*models.Beacon, error) {
	beacon, err := s.repo.UpdateLabel(ctx, id, strings.TrimSpace(label))
	if err != nil {
		if errors.Is(err, repository.ErrNotFound) {
			return nil, ErrBeaconNotFound
		}
		return nil, err
	}
	return beacon, nil
}

func (s *BeaconService) Usage(ctx context.Context, id uuid.UUID) ([]models.BeaconUsage, error) {
	if _, err := s.Get(ctx, id); err != nil {
		return nil, err
	}
	return s.repo.Usage(ctx, id)
}

// Delete applies a super-admin delete directly, or creates an approval request for an admin.
func (s *BeaconService) Delete(ctx context.Context, id, actorID uuid.UUID, role, reason string) (*models.ChangeActionResult, error) {
	beacon, err := s.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if beacon.DeletedAt != nil {
		return nil, ErrBeaconAlreadyDeleted
	}
	if active, err := s.repo.HasActiveEvents(ctx, id); err != nil {
		return nil, err
	} else if active {
		return nil, ErrBeaconInActiveEvent
	}

	if role == user_models.RoleSuperAdmin {
		if err := s.repo.SoftDelete(ctx, id, actorID); err != nil {
			return nil, err
		}
		updated, _ := s.repo.GetByID(ctx, id)
		return &models.ChangeActionResult{Mode: "deleted", Beacon: updated, Message: "Beacon deleted"}, nil
	}

	request, err := s.createRequest(ctx, id, "delete", reason, actorID)
	if err != nil {
		return nil, err
	}
	return &models.ChangeActionResult{Mode: "requested", Request: request, Message: "Delete request submitted for super admin approval"}, nil
}

// Restore applies a super-admin restore directly, or creates an approval request for an admin.
func (s *BeaconService) Restore(ctx context.Context, id, actorID uuid.UUID, role, reason string) (*models.ChangeActionResult, error) {
	beacon, err := s.Get(ctx, id)
	if err != nil {
		return nil, err
	}
	if beacon.DeletedAt == nil {
		return nil, ErrBeaconNotDeleted
	}

	if role == user_models.RoleSuperAdmin {
		if err := s.repo.Restore(ctx, id); err != nil {
			return nil, err
		}
		updated, _ := s.repo.GetByID(ctx, id)
		return &models.ChangeActionResult{Mode: "restored", Beacon: updated, Message: "Beacon restored"}, nil
	}

	request, err := s.createRequest(ctx, id, "restore", reason, actorID)
	if err != nil {
		return nil, err
	}
	return &models.ChangeActionResult{Mode: "requested", Request: request, Message: "Restore request submitted for super admin approval"}, nil
}

func (s *BeaconService) CreateChangeRequest(ctx context.Context, beaconID uuid.UUID, action, reason string, actorID uuid.UUID) (*models.ChangeRequest, error) {
	if action != "delete" && action != "restore" {
		return nil, errors.New("invalid action")
	}
	beacon, err := s.Get(ctx, beaconID)
	if err != nil {
		return nil, err
	}
	if action == "delete" {
		if beacon.DeletedAt != nil {
			return nil, ErrBeaconAlreadyDeleted
		}
		if active, err := s.repo.HasActiveEvents(ctx, beaconID); err != nil {
			return nil, err
		} else if active {
			return nil, ErrBeaconInActiveEvent
		}
	}
	if action == "restore" && beacon.DeletedAt == nil {
		return nil, ErrBeaconNotDeleted
	}
	return s.createRequest(ctx, beaconID, action, reason, actorID)
}

func (s *BeaconService) createRequest(ctx context.Context, beaconID uuid.UUID, action, reason string, actorID uuid.UUID) (*models.ChangeRequest, error) {
	if pending, err := s.repo.HasPendingRequest(ctx, beaconID, action); err != nil {
		return nil, err
	} else if pending {
		return nil, ErrPendingRequest
	}
	req := &models.ChangeRequest{
		BeaconID:    beaconID,
		Action:      action,
		Reason:      strings.TrimSpace(reason),
		Status:      "pending",
		RequestedBy: &actorID,
	}
	if err := s.repo.CreateChangeRequest(ctx, req); err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "pending request") {
			return nil, ErrPendingRequest
		}
		return nil, err
	}
	return s.repo.GetChangeRequest(ctx, req.ID)
}

func (s *BeaconService) ListChangeRequests(ctx context.Context, status string) ([]models.ChangeRequest, error) {
	return s.repo.ListChangeRequests(ctx, status)
}

func (s *BeaconService) ApproveChangeRequest(ctx context.Context, id, reviewerID uuid.UUID, note string) (*models.ChangeRequest, error) {
	if err := s.repo.ApproveChangeRequest(ctx, id, reviewerID, note); err != nil {
		switch {
		case errors.Is(err, repository.ErrNotFound):
			return nil, ErrRequestNotFound
		case errors.Is(err, repository.ErrRequestNotPending):
			return nil, ErrRequestNotPending
		case errors.Is(err, repository.ErrBeaconInActiveEvent):
			return nil, ErrBeaconInActiveEvent
		default:
			return nil, err
		}
	}
	return s.repo.GetChangeRequest(ctx, id)
}

func (s *BeaconService) RejectChangeRequest(ctx context.Context, id, reviewerID uuid.UUID, note string) (*models.ChangeRequest, error) {
	if err := s.repo.RejectChangeRequest(ctx, id, reviewerID, note); err != nil {
		if errors.Is(err, repository.ErrRequestNotPending) {
			return nil, ErrRequestNotPending
		}
		return nil, err
	}
	return s.repo.GetChangeRequest(ctx, id)
}

func median(values []int) int {
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
