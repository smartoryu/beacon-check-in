package beacon

import (
	"log/slog"
	"os"

	"api/modules/beacon/handler"
	"api/modules/beacon/repository"
	"api/modules/beacon/services"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/labstack/echo/v4"
)

type Options struct {
	PgPool *pgxpool.Pool
	Logger *slog.Logger
}

type BeaconModule struct {
	logger      *slog.Logger
	middlewares []echo.MiddlewareFunc
	handler     *handler.Handler
}

func NewModule(opts *Options) *BeaconModule {
	logger := opts.Logger
	if logger == nil {
		logger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{}))
	}
	repo := repository.NewBeaconRepository(opts.PgPool, logger)
	service := services.NewBeaconService(services.BeaconServiceOpts{Logger: logger, Repo: repo})
	return &BeaconModule{
		logger:  logger,
		handler: handler.NewHandler(&handler.HandlerOpts{Logger: logger, Service: service}),
	}
}

func (m *BeaconModule) Use(mw ...echo.MiddlewareFunc) {
	m.middlewares = append(m.middlewares, mw...)
}

func (m *BeaconModule) RegisterRoutes(e *echo.Group) {
	g := e.Group("/beacons", m.middlewares...)
	g.GET("", m.handler.List)
	g.POST("/lookup", m.handler.Lookup)
	g.POST("", m.handler.Register)
	g.GET("/:id", m.handler.Get)
	g.PATCH("/:id", m.handler.UpdateLabel)
	g.GET("/:id/usage", m.handler.Usage)
	g.DELETE("/:id", m.handler.Delete)
	g.POST("/:id/restore", m.handler.Restore)

	r := e.Group("/beacon-requests", m.middlewares...)
	r.GET("", m.handler.ListRequests)
	r.POST("", m.handler.CreateRequest)
	r.POST("/:id/approve", m.handler.Approve)
	r.POST("/:id/reject", m.handler.Reject)
}
