package server

import (
	"api/internal/adapter"
	"api/internal/config"
	"api/internal/middleware"
	"api/internal/notification"

	"github.com/labstack/echo/v4"

	modAdmin "api/modules/admin"
	modAuth "api/modules/auth"
	modBeacon "api/modules/beacon"
	modCheckin "api/modules/checkin"
	modDashboard "api/modules/dashboard"
	modEvent "api/modules/event"
	modUser "api/modules/user"
)

// registerModules registers application modules, injects middleware and attaches routes.
// Keeps Start() concise and centralizes module wiring for easier testing/refactor.
func (s *HTTPServer) registerModules(cfg *config.Config, pg *adapter.PostgresDB, mailer *notification.Mailer, e *echo.Echo) error {
	// Register primary HTTP server routes
	serverHandler := NewServerHandler(pg.Pool, s.logger)
	serverHandler.RegisterRoutes(e)

	// Register global middleware for API
	e.Use(middleware.CORSMiddleware(cfg))
	e.Use(middleware.RateLimitMiddleware(
		cfg.App.RateLimitRequests, cfg.App.RateLimitBurstSize,
	))
	e.Use(middleware.CompressionMiddleware())

	// Create API v1 route group
	apiV1Route := e.Group("/api/v1")

	// Load user module (no auth middleware yet)
	userModule := modUser.NewModule(&modUser.Options{PgPool: pg.Pool, Logger: s.logger})

	// Load auth module (requires user service)
	authModule := modAuth.NewModule(&modAuth.Options{
		PgPool:       pg.Pool,
		Logger:       s.logger,
		UserService:  userModule.GetUserService(),
		JWTSecretKey: []byte(cfg.App.JWTSecretKey),
		BaseURL:      cfg.GetAppBaseURL(),
		Mailer:       mailer,
	})

	// Inject auth middleware into user module so protected user routes use same JWT config
	userModule.Use(authModule.JWTMiddleware(), middleware.RequireRole("super_admin", "admin"))

	// Admin account management is restricted to the super admin.
	adminModule := modAdmin.NewModule(&modAdmin.Options{
		Logger:      s.logger,
		UserService: userModule.GetUserService(),
		AuthService: authModule.GetAuthService(),
	})
	adminModule.Use(authModule.JWTMiddleware(), middleware.RequireRole("super_admin"))

	// Beacons are managed by admins and super admins.
	beaconModule := modBeacon.NewModule(&modBeacon.Options{PgPool: pg.Pool, Logger: s.logger})
	beaconModule.Use(authModule.JWTMiddleware(), middleware.RequireRole("super_admin", "admin"))

	// Events expose an active feed to every authenticated role.
	eventModule := modEvent.NewModule(&modEvent.Options{PgPool: pg.Pool, Logger: s.logger})
	eventModule.Use(authModule.JWTMiddleware())

	// Check-ins are submitted by users and read by admins.
	checkinModule := modCheckin.NewModule(&modCheckin.Options{
		PgPool:        pg.Pool,
		Logger:        s.logger,
		MaxOfflineAge: cfg.GetMaxOfflineAge(),
		MaxClockSkew:  cfg.GetMaxClockSkew(),
	})
	checkinModule.Use(authModule.JWTMiddleware())

	dashboardModule := modDashboard.NewModule(&modDashboard.Options{PgPool: pg.Pool, Logger: s.logger})
	dashboardModule.Use(authModule.JWTMiddleware())

	// Register the module routes after injecting middleware
	userModule.RegisterRoutes(apiV1Route)
	adminModule.RegisterRoutes(apiV1Route)
	beaconModule.RegisterRoutes(apiV1Route)
	eventModule.RegisterRoutes(apiV1Route)
	checkinModule.RegisterRoutes(apiV1Route)
	dashboardModule.RegisterRoutes(apiV1Route)
	authModule.RegisterRoutes(apiV1Route)

	return nil
}
