package services

import (
	"context"
	"errors"
	"log/slog"
	"strings"
	"time"

	"api/modules/admin/models"
	auth_models "api/modules/auth/models"
	auth_services "api/modules/auth/services"
	user_models "api/modules/user/models"
	user_repo "api/modules/user/repository"
	user_services "api/modules/user/services"
	"api/pkg/apputils"

	"github.com/gofrs/uuid/v5"
)

var (
	ErrAdminNotFound     = errors.New("admin not found")
	ErrAdminEmailExists  = errors.New("email already registered")
	ErrCannotModifySuper = errors.New("the seeded super admin cannot be modified")
	ErrCannotDeleteSelf  = errors.New("you cannot delete your own account")
	ErrInvalidRole       = errors.New("account is not an admin")
)

type AdminService struct {
	logger      *slog.Logger
	userService user_services.UserServiceInterface
	authService auth_services.AuthServiceInterface
}

type AdminServiceOpts struct {
	Logger      *slog.Logger
	UserService user_services.UserServiceInterface
	AuthService auth_services.AuthServiceInterface
}

func NewAdminService(opts AdminServiceOpts) *AdminService {
	return &AdminService{
		logger:      opts.Logger,
		userService: opts.UserService,
		authService: opts.AuthService,
	}
}

// CreateAdmin creates an admin with a one-time temporary password.
func (s *AdminService) CreateAdmin(ctx context.Context, name, email string) (*user_models.User, string, error) {
	existing, err := s.userService.GetUserByEmail(ctx, email)
	if err != nil && !errors.Is(err, user_repo.ErrNotFound) {
		return nil, "", err
	}
	if existing != nil {
		return nil, "", ErrAdminEmailExists
	}

	now := time.Now().UTC()
	user := &user_models.User{
		DisplayName:        name,
		Email:              email,
		Role:               user_models.RoleAdmin,
		EmailVerifiedAt:    &now,
		MustChangePassword: true,
	}
	if err := s.userService.CreateUser(ctx, user); err != nil {
		if strings.Contains(strings.ToLower(err.Error()), "duplicate") {
			return nil, "", ErrAdminEmailExists
		}
		return nil, "", err
	}

	tempPassword, err := apputils.GenerateTemporaryPassword()
	if err != nil {
		return nil, "", err
	}
	if err := s.authService.SetUserPassword(ctx, &auth_models.UserPassword{
		UserID:       user.ID,
		PasswordHash: tempPassword,
	}); err != nil {
		return nil, "", err
	}

	return user, tempPassword, nil
}

// ListAdmins returns admins (including soft-deleted, for the management table).
func (s *AdminService) ListAdmins(ctx context.Context, filter *models.AdminFilter) ([]*user_models.User, error) {
	search := filter.Search
	users, err := s.userService.ListUsers(ctx, &user_models.FilterUser{
		Search:         &search,
		IncludeDeleted: filter.IncludeDeleted,
	})
	if err != nil {
		return nil, err
	}

	admins := make([]*user_models.User, 0, len(users))
	for _, user := range users {
		if user.Role == user_models.RoleAdmin || user.Role == user_models.RoleSuperAdmin {
			admins = append(admins, user)
		}
	}
	return admins, nil
}

// GetAdmin returns an admin or super admin by id.
func (s *AdminService) GetAdmin(ctx context.Context, id uuid.UUID) (*user_models.User, error) {
	user, err := s.userService.GetUserByID(ctx, id)
	if err != nil {
		if errors.Is(err, user_repo.ErrNotFound) {
			return nil, ErrAdminNotFound
		}
		return nil, err
	}
	if user.Role != user_models.RoleAdmin && user.Role != user_models.RoleSuperAdmin {
		return nil, ErrInvalidRole
	}
	return user, nil
}

// UpdateAdmin updates an admin's display name and email. The role is immutable.
func (s *AdminService) UpdateAdmin(ctx context.Context, id uuid.UUID, name, email string) (*user_models.User, error) {
	user, err := s.GetAdmin(ctx, id)
	if err != nil {
		return nil, err
	}
	user.DisplayName = name
	user.Email = email
	if err := s.userService.UpdateUser(ctx, user); err != nil {
		return nil, err
	}
	return user, nil
}

// DeleteAdmin soft-deletes an admin and revokes their sessions.
func (s *AdminService) DeleteAdmin(ctx context.Context, id, actorID uuid.UUID) error {
	if id == actorID {
		return ErrCannotDeleteSelf
	}
	user, err := s.GetAdmin(ctx, id)
	if err != nil {
		return err
	}
	if user.Role == user_models.RoleSuperAdmin {
		return ErrCannotModifySuper
	}
	if err := s.userService.DeleteUser(ctx, id); err != nil {
		return err
	}
	if err := s.authService.RevokeAllUserSessions(ctx, id, &actorID); err != nil {
		s.logger.Warn("failed to revoke sessions for deleted admin", "admin_id", id.String(), "error", err.Error())
	}
	return nil
}

// ResetPassword generates a new one-time password for an admin.
func (s *AdminService) ResetPassword(ctx context.Context, id, actorID uuid.UUID) (string, error) {
	user, err := s.GetAdmin(ctx, id)
	if err != nil {
		return "", err
	}
	tempPassword, err := apputils.GenerateTemporaryPassword()
	if err != nil {
		return "", err
	}
	if err := s.authService.SetUserPassword(ctx, &auth_models.UserPassword{
		UserID:       user.ID,
		PasswordHash: tempPassword,
	}); err != nil {
		return "", err
	}
	user.MustChangePassword = true
	if err := s.userService.UpdateUser(ctx, user); err != nil {
		return "", err
	}
	if err := s.authService.RevokeAllUserSessions(ctx, id, &actorID); err != nil {
		s.logger.Warn("failed to revoke sessions for admin password reset", "admin_id", id.String(), "error", err.Error())
	}
	return tempPassword, nil
}
