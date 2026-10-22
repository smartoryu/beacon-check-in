package handler

import (
	"log/slog"
	"net/http"

	"api/modules/dashboard/repository"

	"github.com/labstack/echo/v4"
)

type Handler struct {
	logger *slog.Logger
	repo   *repository.DashboardRepository
}

func NewHandler(logger *slog.Logger, repo *repository.DashboardRepository) *Handler {
	return &Handler{logger: logger, repo: repo}
}

// @Summary      Dashboard summary
// @Description  Counts users, events, beacons, check-ins and pending approvals plus recent activity.
// @Tags         Dashboard
// @Security     BearerAuth
// @Produce      json
// @Success      200  {object}  models.Summary
// @Router       /api/v1/dashboard/summary [get]
func (h *Handler) Summary(c echo.Context) error {
	summary, err := h.repo.Summary(c.Request().Context())
	if err != nil {
		h.logger.Error("failed to load dashboard summary", "error", err.Error())
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Failed to load dashboard"})
	}
	return c.JSON(http.StatusOK, summary)
}
