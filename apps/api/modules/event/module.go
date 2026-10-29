package event

import (
	"log/slog"
	"os"

	"api/internal/middleware"
	"api/modules/event/handler"
	"api/modules/event/repository"
	"api/modules/event/services"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/labstack/echo/v4"
)

type Options struct {
	PgPool *pgxpool.Pool
	Logger *slog.Logger
}

type EventModule struct {
	logger      *slog.Logger
	middlewares []echo.MiddlewareFunc
	handler     *handler.Handler
}

func NewModule(opts *Options) *EventModule {
	logger := opts.Logger
	if logger == nil {
		logger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{}))
	}
	repo := repository.NewEventRepository(opts.PgPool, logger)
	service := services.NewEventService(services.EventServiceOpts{Logger: logger, Repo: repo})
	return &EventModule{logger: logger, handler: handler.NewHandler(&handler.HandlerOpts{Logger: logger, Service: service})}
}

func (m *EventModule) Use(mw ...echo.MiddlewareFunc) {
	m.middlewares = append(m.middlewares, mw...)
}

func (m *EventModule) RegisterRoutes(e *echo.Group) {
	adminOnly := middleware.RequireRole("super_admin", "admin")

	g := e.Group("/events", m.middlewares...)
	g.GET("/active", m.handler.Active)
	g.GET("", m.handler.List, adminOnly)
	g.POST("", m.handler.Create, adminOnly)
	g.GET("/:id", m.handler.Get)
	g.PUT("/:id", m.handler.Update, adminOnly)
	g.DELETE("/:id", m.handler.Delete, adminOnly)
	g.PUT("/:id/beacons", m.handler.SetBeacons, adminOnly)
	g.PUT("/:id/beacons/:beaconId/location", m.handler.ConfirmBeaconLocation, adminOnly)
	g.GET("/:id/beacons/:beaconId/location-history", m.handler.ListBeaconLocationHistory, adminOnly)
}
