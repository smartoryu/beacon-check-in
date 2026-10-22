//go:build prod || debug
// +build prod debug

package commands

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"regexp"
	"strings"
	"time"

	"api/internal/config"
	"api/pkg/apputils"

	"github.com/gofrs/uuid/v5"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/spf13/cobra"
)

var bootstrapAdminCmd = &cobra.Command{
	Use:   "bootstrap:admin",
	Short: "Create the first super admin from SUPER_ADMIN_* environment variables",
	Run: func(cmd *cobra.Command, args []string) {
		if err := bootstrapAdmin(cmd.Context()); err != nil {
			log.Fatalf("Failed to bootstrap super admin: %v", err)
		}
	},
}

func init() {
	RootCmd.AddCommand(bootstrapAdminCmd)
}

func bootstrapAdmin(ctx context.Context) error {
	cfg := config.Get()

	name := strings.TrimSpace(os.Getenv("SUPER_ADMIN_NAME"))
	if name == "" {
		name = "Super Admin"
	}
	email := strings.TrimSpace(os.Getenv("SUPER_ADMIN_EMAIL"))
	password := os.Getenv("SUPER_ADMIN_PASSWORD")
	if email == "" {
		return fmt.Errorf("SUPER_ADMIN_EMAIL is required")
	}
	if len(password) < 8 {
		return fmt.Errorf("SUPER_ADMIN_PASSWORD must be at least 8 characters")
	}

	pool, err := pgxpool.New(ctx, cfg.GetDatabaseURL())
	if err != nil {
		return err
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		return err
	}

	var existingID uuid.UUID
	err = pool.QueryRow(ctx, `SELECT id FROM public.users WHERE LOWER(email) = LOWER($1) LIMIT 1`, email).Scan(&existingID)
	if err == nil {
		log.Printf("Super admin %s already exists (%s); no changes made", email, existingID)
		return nil
	}
	if err != pgx.ErrNoRows {
		return err
	}

	username, err := availableUsername(ctx, pool, usernameFromEmail(email))
	if err != nil {
		return err
	}

	hashedPassword, err := apputils.NewPasswordHasher().Hash(password)
	if err != nil {
		return err
	}

	now := time.Now().UTC()
	userID := uuid.Must(uuid.NewV7())
	metadata, err := json.Marshal(map[string]string{"timezone": "Asia/Jakarta"})
	if err != nil {
		return err
	}

	tx, err := pool.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	if _, err := tx.Exec(ctx, `
		INSERT INTO public.users (
			id, display_name, email, username, role, metadata,
			created_at, email_verified_at, must_change_password
		) VALUES ($1, $2, $3, $4, 'super_admin', $5, $6, $6, FALSE)
	`, userID, name, email, username, metadata, now); err != nil {
		return err
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO public.user_passwords (user_id, password_hash, created_at)
		VALUES ($1, $2, $3)
	`, userID, hashedPassword, now); err != nil {
		return err
	}

	if err := tx.Commit(ctx); err != nil {
		return err
	}

	log.Printf("Created super admin %s (%s) with username %s", email, userID, username)
	return nil
}

func usernameFromEmail(email string) string {
	base := strings.ToLower(strings.SplitN(email, "@", 2)[0])
	base = regexp.MustCompile(`[^a-z0-9_]+`).ReplaceAllString(base, "")
	if base == "" {
		base = "superadmin"
	}
	if len(base) < 3 {
		base = base + "_admin"
	}
	if len(base) > 24 {
		base = base[:24]
	}
	return base
}

func availableUsername(ctx context.Context, pool *pgxpool.Pool, base string) (string, error) {
	candidate := base
	for suffix := 1; suffix < 100; suffix++ {
		var exists bool
		if err := pool.QueryRow(ctx, `SELECT EXISTS (SELECT 1 FROM public.users WHERE LOWER(username) = LOWER($1))`, candidate).Scan(&exists); err != nil {
			return "", err
		}
		if !exists {
			return candidate, nil
		}
		candidate = fmt.Sprintf("%s_%d", base, suffix)
	}
	return "", fmt.Errorf("could not find an available username for %q", base)
}
