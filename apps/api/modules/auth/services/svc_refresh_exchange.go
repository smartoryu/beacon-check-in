package services

import (
	"context"
	"errors"
	"time"

	"api/modules/auth/models"
	"api/pkg/apputils"

	"github.com/gofrs/uuid/v5"
)

var (
	ErrInvalidRefreshToken = errors.New("invalid refresh token")
	ErrRefreshTokenRevoked = errors.New("refresh token revoked or expired")
)

// Refresh exchanges a valid refresh JWT for a new access token.
func (s *AuthService) Refresh(ctx context.Context, refreshToken string) (*models.AuthenticatedUser, error) {
	jwtGen := apputils.NewJWTGenerator(apputils.JWTConfig{
		SecretKey:          s.secretKey,
		AccessTokenExpiry:  s.accessTokenExpiry,
		RefreshTokenExpiry: s.refreshTokenExpiry,
		SigningAlg:         s.signingAlg,
		Issuer:             s.baseURL,
	})
	claims, err := jwtGen.ParseAndValidate(ctx, refreshToken)
	if err != nil {
		return nil, ErrInvalidRefreshToken
	}
	if typ, _ := claims["typ"].(string); typ != "refresh" {
		return nil, ErrInvalidRefreshToken
	}
	sub, _ := claims["sub"].(string)
	userID, err := uuid.FromString(sub)
	if err != nil {
		return nil, ErrInvalidRefreshToken
	}
	jti, _ := claims["jti"].(string)
	refreshID, err := uuid.FromString(jti)
	if err != nil {
		return nil, ErrInvalidRefreshToken
	}

	stored, err := s.authRepo.GetRefreshToken(ctx, refreshID)
	if err != nil {
		return nil, ErrInvalidRefreshToken
	}
	if string(stored.TokenHash) != jwtGen.GetHash(refreshToken) {
		return nil, ErrInvalidRefreshToken
	}
	if stored.RevokedAt != nil || time.Now().After(stored.ExpiresAt) {
		return nil, ErrRefreshTokenRevoked
	}

	user, err := s.userService.GetUserByID(ctx, userID)
	if err != nil || user == nil || user.DeletedAt != nil {
		return nil, ErrInvalidRefreshToken
	}

	sessionID := uuid.Nil
	if stored.SessionID != nil {
		sessionID = *stored.SessionID
	}
	accessToken, err := jwtGen.Sign(ctx, models.AccessTokenPayload{
		UserID: user.ID.String(),
		Email:  user.Email,
		Role:   user.Role,
		SID:    sessionID.String(),
	}, user.ID.String())
	if err != nil {
		return nil, err
	}

	return &models.AuthenticatedUser{
		UserWithCredentials: models.UserWithCredentials{
			User:         *user,
			AccessToken:  accessToken,
			RefreshToken: refreshToken,
		},
		SessionID:   &sessionID,
		TokenExpiry: time.Now().Add(s.accessTokenExpiry),
	}, nil
}
