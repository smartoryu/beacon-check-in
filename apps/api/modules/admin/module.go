package admin

import (
	"log/slog"
	"os"

	"api/modules/admin/handler"
	"api/modules/admin/services"
	auth_services "api/modules/auth/services"
	user_services "api/modules/user/services"

	"github.com/labstack/echo/v4"
)

type Options struct {
	Logger      *slog.Logger
	UserService user_services.UserServiceInterface
	AuthService auth_services.AuthServiceInterface
}

type AdminModule struct {
	logger      *slog.Logger
	middlewares []echo.MiddlewareFunc
	handler     *handler.Handler
}

func NewModule(opts *Options) *AdminModule {
	logger := opts.Logger
	if logger == nil {
		logger = slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{}))
	}

	service := services.NewAdminService(services.AdminServiceOpts{
		Logger:      logger,
		UserService: opts.UserService,
		AuthService: opts.AuthService,
	})

	return &AdminModule{
		logger:  logger,
		handler: handler.NewHandler(&handler.HandlerOpts{Logger: logger, Service: service}),
	}
}

func (m *AdminModule) Use(mw ...echo.MiddlewareFunc) {
	m.middlewares = append(m.middlewares, mw...)
}

func (m *AdminModule) RegisterRoutes(e *echo.Group) {
	g := e.Group("/admins", m.middlewares...)
	g.GET("", m.handler.ListAdmins)
	g.POST("", m.handler.CreateAdmin)
	g.GET("/:id", m.handler.GetAdmin)
	g.PUT("/:id", m.handler.UpdateAdmin)
	g.DELETE("/:id", m.handler.DeleteAdmin)
	g.POST("/:id/reset-password", m.handler.ResetPassword)
}
