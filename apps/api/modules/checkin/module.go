package checkin

import (
	"log/slog"
	"os"
	"time"

	"api/internal/middleware"
	checkin_handler "api/modules/checkin/handler"
	checkin_repo "api/modules/checkin/repository"
	checkin_services "api/modules/checkin/services"
	event_repo "api/modules/event/repository"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/labstack/echo/v4"
)

type Options struct {
	PgPool        *pgxpool.Pool
	Logger        *slog.Logger
	MaxOfflineAge time.Duration
	MaxClockSkew  time.Duration
}

type CheckinModule struct {
	logger      *slog.Logger
	middlewares []echo.MiddlewareFunc
	handler     *checkin_handler.Handler
}

func NewModule(opts *Options) *CheckinModule {
	logger := opts.Logger
	if logger == nil {
		logger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{}))
	}
	repo := checkin_repo.NewCheckinRepository(opts.PgPool, logger)
	service := checkin_services.NewCheckinService(checkin_services.CheckinServiceOpts{
		Logger:        logger,
		Repo:          repo,
		EventRepo:     event_repo.NewEventRepository(opts.PgPool, logger),
		MaxOfflineAge: opts.MaxOfflineAge,
		MaxClockSkew:  opts.MaxClockSkew,
	})
	return &CheckinModule{logger: logger, handler: checkin_handler.NewHandler(&checkin_handler.HandlerOpts{Logger: logger, Service: service})}
}

func (m *CheckinModule) Use(mw ...echo.MiddlewareFunc) {
	m.middlewares = append(m.middlewares, mw...)
}

func (m *CheckinModule) RegisterRoutes(e *echo.Group) {
	g := e.Group("/events", m.middlewares...)
	g.POST("/:id/checkins", m.handler.Submit, middleware.RequireRole("user"))
	g.GET("/:id/checkins", m.handler.ListByEvent, middleware.RequireRole("super_admin", "admin"))

	me := e.Group("/me", m.middlewares...)
	me.GET("/checkins", m.handler.ListMine)
}
