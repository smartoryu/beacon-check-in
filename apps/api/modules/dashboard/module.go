package dashboard

import (
	"log/slog"
	"os"

	"api/internal/middleware"
	"api/modules/dashboard/handler"
	"api/modules/dashboard/repository"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/labstack/echo/v4"
)

type Options struct {
	PgPool *pgxpool.Pool
	Logger *slog.Logger
}

type DashboardModule struct {
	middlewares []echo.MiddlewareFunc
	handler     *handler.Handler
}

func NewModule(opts *Options) *DashboardModule {
	logger := opts.Logger
	if logger == nil {
		logger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{}))
	}
	return &DashboardModule{
		handler: handler.NewHandler(logger, repository.NewDashboardRepository(opts.PgPool)),
	}
}

func (m *DashboardModule) Use(mw ...echo.MiddlewareFunc) {
	m.middlewares = append(m.middlewares, mw...)
}

func (m *DashboardModule) RegisterRoutes(e *echo.Group) {
	g := e.Group("/dashboard", m.middlewares...)
	g.GET("/summary", m.handler.Summary, middleware.RequireRole("super_admin", "admin"))
}
