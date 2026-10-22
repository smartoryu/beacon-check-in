package seeders

import (
	"context"
	"encoding/json"
	"log/slog"
	"time"

	"api/pkg/apputils"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserSeed struct {
	DisplayName     string
	Email           string
	Username        string
	Password        string
	Role            string
	Metadata        map[string]string
	EmailVerifiedAt *time.Time
}

func UserFactory(ctx context.Context, pool *pgxpool.Pool) error {
	slog.Info("Seeding default users...")

	now := time.Now().UTC()

	users := []UserSeed{
		{
			DisplayName:     "Super Admin",
			Email:           "superadmin@beacon.local",
			Username:        "superadmin",
			Password:        "SuperAdmin123!",
			Role:            "super_admin",
			Metadata:        map[string]string{"timezone": "Asia/Jakarta"},
			EmailVerifiedAt: &now,
		},
		{
			DisplayName:     "Admin One",
			Email:           "admin1@beacon.local",
			Username:        "admin",
			Password:        "Admin123!",
			Role:            "admin",
			Metadata:        map[string]string{"timezone": "Asia/Jakarta"},
			EmailVerifiedAt: &now,
		},
		{
			DisplayName:     "Admin Two",
			Email:           "admin2@beacon.local",
			Username:        "admin2",
			Password:        "Admin123!",
			Role:            "admin",
			Metadata:        map[string]string{"timezone": "Asia/Jakarta"},
			EmailVerifiedAt: &now,
		},
		{
			DisplayName:     "User One",
			Email:           "user1@beacon.local",
			Username:        "johndoe",
			Password:        "User123!",
			Role:            "user",
			Metadata:        map[string]string{"timezone": "Asia/Jakarta"},
			EmailVerifiedAt: &now,
		},
		{
			DisplayName:     "User Two",
			Email:           "user2@beacon.local",
			Username:        "user2",
			Password:        "User123!",
			Role:            "user",
			Metadata:        map[string]string{"timezone": "Asia/Jakarta"},
			EmailVerifiedAt: &now,
		},
	}

	insertUserQuery := `
        INSERT INTO public.users (username, display_name, email, role, metadata, email_verified_at, must_change_password)
        VALUES ($1, $2, $3, $4, $5, $6, FALSE)
        ON CONFLICT (username) DO UPDATE
        SET
            display_name = EXCLUDED.display_name,
            email = EXCLUDED.email,
            role = EXCLUDED.role,
            metadata = EXCLUDED.metadata,
            email_verified_at = EXCLUDED.email_verified_at,
            must_change_password = FALSE
        RETURNING id
    `

	insertPasswordQuery := `
        INSERT INTO public.user_passwords (user_id, password_hash) VALUES ($1, $2)
        ON CONFLICT (user_id) DO UPDATE SET password_hash = EXCLUDED.password_hash
    `

	tx, err := pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		slog.Error("Failed to begin transaction", "err", err)
		return err
	}
	defer func() {
		if err := tx.Rollback(ctx); err != nil && err != pgx.ErrTxClosed {
			slog.Warn("Failed to rollback transaction", "err", err)
		}
	}()

	passwd := apputils.NewPasswordHasher()

	for _, u := range users {
		metadataJSON, err := json.Marshal(u.Metadata)
		if err != nil {
			slog.Error("Failed to marshal metadata", "username", u.Username, "err", err)
			return err
		}

		var userID string
		err = tx.QueryRow(ctx, insertUserQuery, u.Username, u.DisplayName, u.Email, u.Role, metadataJSON, u.EmailVerifiedAt).Scan(&userID)
		if err != nil {
			slog.Error("Failed to seed user", "username", u.Username, "err", err)
			return err
		}

		passwordHash, err := passwd.Hash(u.Password)
		if err != nil {
			slog.Error("Failed to hash password", "username", u.Username, "err", err)
			return err
		}

		_, err = tx.Exec(ctx, insertPasswordQuery, userID, passwordHash)
		if err != nil {
			slog.Error("Failed to seed user password", "username", u.Username, "err", err)
			return err
		}

		slog.Info("Seeded user", "username", u.Username, "role", u.Role)
	}

	if err := tx.Commit(ctx); err != nil {
		slog.Error("Failed to commit transaction", "err", err)
		return err
	}

	return nil
}
