package handler

import (
	"errors"
	"net/http"

	"api/modules/event/models"
	"api/modules/event/services"
	"api/pkg/apputils"

	"github.com/go-playground/validator/v10"
	"github.com/gofrs/uuid/v5"
	"github.com/labstack/echo/v4"
	"log/slog"
)

type Handler struct {
	logger    *slog.Logger
	service   *services.EventService
	validator *validator.Validate
}

type HandlerOpts struct {
	Logger  *slog.Logger
	Service *services.EventService
}

func NewHandler(opts *HandlerOpts) *Handler {
	return &Handler{logger: opts.Logger, service: opts.Service, validator: validator.New()}
}

// @Summary      List events
// @Description  Lists events with optional status/search filters.
// @Tags         Event Management
// @Security     BearerAuth
// @Produce      json
// @Success      200  {array}  models.Event
// @Router       /api/v1/events [get]
func (h *Handler) List(c echo.Context) error {
	var filter models.EventFilter
	if err := c.Bind(&filter); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid filter parameters"})
	}
	events, err := h.service.List(c.Request().Context(), &filter)
	if err != nil {
		return h.fail(c, err)
	}
	if events == nil {
		events = []*models.Event{}
	}
	return c.JSON(http.StatusOK, events)
}

// @Summary      Create an event
// @Description  Creates an event with at least one positioned beacon.
// @Tags         Event Management
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        body  body      models.CreateEventRequest  true  "Event payload"
// @Success      201   {object}  models.Event
// @Router       /api/v1/events [post]
func (h *Handler) Create(c echo.Context) error {
	var req models.CreateEventRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid request payload"})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]any{"error": "Validation failed", "details": apputils.ValidationErrorsToMap(err, req)})
	}
	actorID, err := currentUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Unauthorized"})
	}
	event, err := h.service.Create(c.Request().Context(), &req, actorID)
	if err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusCreated, event)
}

// @Summary      Get an event
// @Description  Returns an event with its beacons and check-in count.
// @Tags         Event Management
// @Security     BearerAuth
// @Produce      json
// @Param        id  path      string  true  "Event ID"
// @Success      200  {object}  models.Event
// @Router       /api/v1/events/{id} [get]
func (h *Handler) Get(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid event ID"})
	}
	event, err := h.service.Get(c.Request().Context(), id)
	if err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusOK, event)
}

// @Summary      Update an event
// @Description  Updates an event and replaces its beacon placements.
// @Tags         Event Management
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        id    path      string                     true  "Event ID"
// @Param        body  body      models.UpdateEventRequest   true  "Event payload"
// @Success      200   {object}  models.Event
// @Router       /api/v1/events/{id} [put]
func (h *Handler) Update(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid event ID"})
	}
	var req models.UpdateEventRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid request payload"})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]any{"error": "Validation failed", "details": apputils.ValidationErrorsToMap(err, req)})
	}
	event, err := h.service.Update(c.Request().Context(), id, &req)
	if err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusOK, event)
}

// @Summary      Delete an event
// @Description  Soft-deletes an event; past check-ins are preserved.
// @Tags         Event Management
// @Security     BearerAuth
// @Produce      json
// @Param        id  path      string  true  "Event ID"
// @Success      200  {object}  map[string]string
// @Router       /api/v1/events/{id} [delete]
func (h *Handler) Delete(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid event ID"})
	}
	if err := h.service.Delete(c.Request().Context(), id); err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusOK, map[string]string{"message": "Event deleted"})
}

// @Summary      Replace event beacons
// @Description  Replaces the event's beacon set and floor positions.
// @Tags         Event Management
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        id    path      string                          true  "Event ID"
// @Param        body  body      models.SetEventBeaconsRequest    true  "Beacon placements"
// @Success      200   {object}  models.Event
// @Router       /api/v1/events/{id}/beacons [put]
func (h *Handler) SetBeacons(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid event ID"})
	}
	var req models.SetEventBeaconsRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid request payload"})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]any{"error": "Validation failed", "details": apputils.ValidationErrorsToMap(err, req)})
	}
	event, err := h.service.SetBeacons(c.Request().Context(), id, &req)
	if err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusOK, event)
}

// @Summary      Active and upcoming events
// @Description  Returns non-deleted events that have not ended, with beacon identities for mobile check-in.
// @Tags         Event Management
// @Security     BearerAuth
// @Produce      json
// @Success      200  {array}  models.Event
// @Router       /api/v1/events/active [get]
func (h *Handler) Active(c echo.Context) error {
	events, err := h.service.Active(c.Request().Context())
	if err != nil {
		return h.fail(c, err)
	}
	if events == nil {
		events = []*models.Event{}
	}
	return c.JSON(http.StatusOK, events)
}

func (h *Handler) fail(c echo.Context, err error) error {
	switch {
	case errors.Is(err, services.ErrEventNotFound):
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	case errors.Is(err, services.ErrNoBeacons), errors.Is(err, services.ErrBeaconUnavailable), errors.Is(err, services.ErrInvalidEvent):
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	default:
		h.logger.Error("event operation failed", "error", err.Error())
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Event operation failed"})
	}
}

func parseID(raw string) (uuid.UUID, error) {
	return uuid.FromString(raw)
}

func currentUserID(c echo.Context) (uuid.UUID, error) {
	raw, ok := c.Get("user_id").(string)
	if !ok || raw == "" {
		return uuid.Nil, errors.New("missing user id")
	}
	return uuid.FromString(raw)
}
