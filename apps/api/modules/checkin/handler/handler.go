package handler

import (
	"errors"
	"net/http"

	"api/modules/checkin/models"
	"api/modules/checkin/services"
	"api/pkg/apputils"

	"github.com/go-playground/validator/v10"
	"github.com/gofrs/uuid/v5"
	"github.com/labstack/echo/v4"
	"log/slog"
)

type Handler struct {
	logger    *slog.Logger
	service   *services.CheckinService
	validator *validator.Validate
}

type HandlerOpts struct {
	Logger  *slog.Logger
	Service *services.CheckinService
}

func NewHandler(opts *HandlerOpts) *Handler {
	return &Handler{logger: opts.Logger, service: opts.Service, validator: validator.New()}
}

// @Summary      Submit a check-in
// @Description  Idempotent offline-first check-in. The event window is validated against recorded_at.
// @Tags         Check-in
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        id    path      string                       true  "Event ID"
// @Param        body  body      models.SubmitCheckinRequest   true  "Check-in payload"
// @Success      201   {object}  models.SubmitCheckinResponse
// @Success      200   {object}  models.SubmitCheckinResponse
// @Failure      409   {object}  map[string]string
// @Router       /api/v1/events/{id}/checkins [post]
func (h *Handler) Submit(c echo.Context) error {
	eventID, err := uuid.FromString(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid event ID"})
	}
	userID, err := currentUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Unauthorized"})
	}

	var req models.SubmitCheckinRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid request payload"})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]any{"error": "Validation failed", "details": apputils.ValidationErrorsToMap(err, req)})
	}

	result, err := h.service.Submit(c.Request().Context(), eventID, userID, &req)
	if err != nil {
		switch {
		case errors.Is(err, services.ErrEventNotFound):
			return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
		case errors.Is(err, services.ErrAlreadyCheckedIn):
			return c.JSON(http.StatusConflict, map[string]string{"error": err.Error()})
		default:
			h.logger.Error("check-in failed", "error", err.Error())
			return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Check-in failed"})
		}
	}
	status := http.StatusCreated
	if result.Checkin != nil && result.Checkin.Status == "rejected" {
		status = http.StatusOK
	}
	if result.Duplicate {
		status = http.StatusOK
	}
	return c.JSON(status, result)
}

// @Summary      List event check-ins
// @Description  Lists accepted and rejected attempts for an event (admin).
// @Tags         Check-in
// @Security     BearerAuth
// @Produce      json
// @Param        id      path   string  true   "Event ID"
// @Param        status  query  string  false  "accepted|rejected|all"
// @Success      200     {array}  models.Checkin
// @Router       /api/v1/events/{id}/checkins [get]
func (h *Handler) ListByEvent(c echo.Context) error {
	eventID, err := uuid.FromString(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid event ID"})
	}
	var filter models.CheckinFilter
	_ = c.Bind(&filter)
	items, err := h.service.ListByEvent(c.Request().Context(), eventID, &filter)
	if err != nil {
		h.logger.Error("failed to list event check-ins", "error", err.Error())
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Failed to list check-ins"})
	}
	if items == nil {
		items = []*models.Checkin{}
	}
	return c.JSON(http.StatusOK, items)
}

// @Summary      List my check-ins
// @Description  Lists the authenticated user's local/server check-in history.
// @Tags         Check-in
// @Security     BearerAuth
// @Produce      json
// @Param        status  query  string  false  "accepted|rejected|all"
// @Success      200     {array}  models.Checkin
// @Router       /api/v1/me/checkins [get]
func (h *Handler) ListMine(c echo.Context) error {
	userID, err := currentUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Unauthorized"})
	}
	var filter models.CheckinFilter
	_ = c.Bind(&filter)
	items, err := h.service.ListByUser(c.Request().Context(), userID, &filter)
	if err != nil {
		h.logger.Error("failed to list my check-ins", "error", err.Error())
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Failed to list check-ins"})
	}
	if items == nil {
		items = []*models.Checkin{}
	}
	return c.JSON(http.StatusOK, items)
}

func currentUserID(c echo.Context) (uuid.UUID, error) {
	raw, ok := c.Get("user_id").(string)
	if !ok || raw == "" {
		return uuid.Nil, errors.New("missing user id")
	}
	return uuid.FromString(raw)
}
