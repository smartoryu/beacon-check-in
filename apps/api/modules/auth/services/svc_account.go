package services

import (
	"context"
	"errors"
	"time"

	"api/modules/auth/models"
	user_models "api/modules/user/models"
	user_repo "api/modules/user/repository"

	"github.com/gofrs/uuid/v5"
)

// ErrEmailAlreadyExists is returned when a signup uses an existing email.
var ErrEmailAlreadyExists = errors.New("email already exists")

// SignUp creates a self-registered user account and returns a signed-in session.
// The role is always "user"; admin accounts are created by a super admin.
func (s *AuthService) SignUp(ctx context.Context, name, email, password string) (*models.AuthenticatedUser, error) {
	existing, err := s.userService.GetUserByEmail(ctx, email)
	if err != nil && !errors.Is(err, user_repo.ErrNotFound) {
		return nil, err
	}
	if existing != nil {
		return nil, ErrEmailAlreadyExists
	}

	now := time.Now().UTC()
	user := &user_models.User{
		DisplayName:     name,
		Email:           email,
		Role:            user_models.RoleUser,
		EmailVerifiedAt: &now,
	}
	if err := s.userService.CreateUser(ctx, user); err != nil {
		return nil, err
	}
	if err := s.SetUserPassword(ctx, &models.UserPassword{
		UserID:       user.ID,
		PasswordHash: password,
	}); err != nil {
		return nil, err
	}

	return s.SignInWithEmail(ctx, email, password)
}

// ChangePassword updates the current user's password and clears the
// must_change_password flag.
func (s *AuthService) ChangePassword(ctx context.Context, userID uuid.UUID, currentPassword, newPassword string) error {
	if err := s.UpdateUserPassword(ctx, userID, currentPassword, newPassword); err != nil {
		return err
	}
	user, err := s.userService.GetUserByID(ctx, userID)
	if err != nil {
		return err
	}
	user.MustChangePassword = false
	return s.userService.UpdateUser(ctx, user)
}

// GetMe returns the authenticated user.
func (s *AuthService) GetMe(ctx context.Context, userID uuid.UUID) (*user_models.User, error) {
	return s.userService.GetUserByID(ctx, userID)
}
