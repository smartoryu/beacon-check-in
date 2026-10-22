package handler

import (
	"errors"
	"net/http"

	"api/internal/middleware"
	"api/modules/beacon/models"
	"api/modules/beacon/services"
	"api/pkg/apputils"

	"github.com/go-playground/validator/v10"
	"github.com/gofrs/uuid/v5"
	"github.com/labstack/echo/v4"
	"log/slog"
)

type Handler struct {
	logger    *slog.Logger
	service   *services.BeaconService
	validator *validator.Validate
}

type HandlerOpts struct {
	Logger  *slog.Logger
	Service *services.BeaconService
}

func NewHandler(opts *HandlerOpts) *Handler {
	return &Handler{logger: opts.Logger, service: opts.Service, validator: validator.New()}
}

// @Summary      List beacons
// @Description  Lists registered beacons with optional search/status filters.
// @Tags         Beacon Management
// @Security     BearerAuth
// @Produce      json
// @Success      200  {array}  models.Beacon
// @Router       /api/v1/beacons [get]
func (h *Handler) List(c echo.Context) error {
	var filter models.BeaconFilter
	if err := c.Bind(&filter); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid filter parameters"})
	}
	beacons, err := h.service.List(c.Request().Context(), &filter)
	if err != nil {
		return h.fail(c, err)
	}
	if beacons == nil {
		beacons = []*models.Beacon{}
	}
	return c.JSON(http.StatusOK, beacons)
}

// @Summary      Look up beacon identities
// @Description  Batch-checks which scanned identity keys are registered, deleted or unknown.
// @Tags         Beacon Management
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        body  body      models.LookupRequest  true  "Identities"
// @Success      200   {object}  models.LookupResponse
// @Router       /api/v1/beacons/lookup [post]
func (h *Handler) Lookup(c echo.Context) error {
	var req models.LookupRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid request payload"})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]any{"error": "Validation failed", "details": apputils.ValidationErrorsToMap(err, req)})
	}
	items, err := h.service.Lookup(c.Request().Context(), req.Identities)
	if err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusOK, models.LookupResponse{Items: items})
}

// @Summary      Register a beacon
// @Description  Registers a scanned iBeacon with its advertisement metadata and optional GATT info.
// @Tags         Beacon Management
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        body  body      models.RegisterBeaconRequest  true  "Beacon payload"
// @Success      201   {object}  models.Beacon
// @Failure      409   {object}  map[string]string
// @Router       /api/v1/beacons [post]
func (h *Handler) Register(c echo.Context) error {
	var req models.RegisterBeaconRequest
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
	beacon, err := h.service.Register(c.Request().Context(), &req, actorID)
	if err != nil {
		if errors.Is(err, services.ErrBeaconExists) {
			return c.JSON(http.StatusConflict, map[string]string{"error": err.Error()})
		}
		return h.fail(c, err)
	}
	return c.JSON(http.StatusCreated, beacon)
}

// @Summary      Get a beacon
// @Description  Returns a beacon by id.
// @Tags         Beacon Management
// @Security     BearerAuth
// @Produce      json
// @Param        id  path      string  true  "Beacon ID"
// @Success      200  {object}  models.Beacon
// @Router       /api/v1/beacons/{id} [get]
func (h *Handler) Get(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid beacon ID"})
	}
	beacon, err := h.service.Get(c.Request().Context(), id)
	if err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusOK, beacon)
}

// @Summary      Rename a beacon
// @Description  Updates only the beacon label.
// @Tags         Beacon Management
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        id    path      string                     true  "Beacon ID"
// @Param        body  body      models.UpdateBeaconRequest  true  "Label"
// @Success      200   {object}  models.Beacon
// @Router       /api/v1/beacons/{id} [patch]
func (h *Handler) UpdateLabel(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid beacon ID"})
	}
	var req models.UpdateBeaconRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid request payload"})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]any{"error": "Validation failed", "details": apputils.ValidationErrorsToMap(err, req)})
	}
	beacon, err := h.service.UpdateLabel(c.Request().Context(), id, req.Label)
	if err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusOK, beacon)
}

// @Summary      Beacon usage
// @Description  Lists events that use this beacon.
// @Tags         Beacon Management
// @Security     BearerAuth
// @Produce      json
// @Param        id  path      string  true  "Beacon ID"
// @Success      200  {array}   models.BeaconUsage
// @Router       /api/v1/beacons/{id}/usage [get]
func (h *Handler) Usage(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid beacon ID"})
	}
	usage, err := h.service.Usage(c.Request().Context(), id)
	if err != nil {
		return h.fail(c, err)
	}
	if usage == nil {
		usage = []models.BeaconUsage{}
	}
	return c.JSON(http.StatusOK, usage)
}

// @Summary      Delete or request deletion of a beacon
// @Description  Super admins delete directly; admins create an approval request.
// @Tags         Beacon Management
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        id    path      string                       true  "Beacon ID"
// @Param        body  body      models.ChangeActionRequest    true  "Reason"
// @Success      200   {object}  models.ChangeActionResult
// @Router       /api/v1/beacons/{id} [delete]
func (h *Handler) Delete(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid beacon ID"})
	}
	var req models.ChangeActionRequest
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
	result, err := h.service.Delete(c.Request().Context(), id, actorID, middleware.GetRole(c), req.Reason)
	if err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusOK, result)
}

// @Summary      Restore or request restoration of a beacon
// @Description  Super admins restore directly; admins create an approval request.
// @Tags         Beacon Management
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        id    path      string                     true  "Beacon ID"
// @Param        body  body      models.ChangeActionRequest  true  "Reason"
// @Success      200   {object}  models.ChangeActionResult
// @Router       /api/v1/beacons/{id}/restore [post]
func (h *Handler) Restore(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid beacon ID"})
	}
	var req models.ChangeActionRequest
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
	result, err := h.service.Restore(c.Request().Context(), id, actorID, middleware.GetRole(c), req.Reason)
	if err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusOK, result)
}

// @Summary      Create a beacon change request
// @Description  Requests a beacon delete or restore. Super admin approval is required.
// @Tags         Beacon Approvals
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        body  body      models.CreateChangeRequest  true  "Request"
// @Success      201   {object}  models.ChangeRequest
// @Router       /api/v1/beacon-requests [post]
func (h *Handler) CreateRequest(c echo.Context) error {
	var req models.CreateChangeRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid request payload"})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]any{"error": "Validation failed", "details": apputils.ValidationErrorsToMap(err, req)})
	}
	beaconID, err := parseID(req.BeaconID)
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid beacon ID"})
	}
	actorID, err := currentUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Unauthorized"})
	}
	request, err := h.service.CreateChangeRequest(c.Request().Context(), beaconID, req.Action, req.Reason, actorID)
	if err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusCreated, request)
}

// @Summary      List beacon change requests
// @Description  Lists pending/approved/rejected beacon requests (super admin).
// @Tags         Beacon Approvals
// @Security     BearerAuth
// @Produce      json
// @Param        status  query     string  false  "pending|approved|rejected"
// @Success      200     {array}   models.ChangeRequest
// @Router       /api/v1/beacon-requests [get]
func (h *Handler) ListRequests(c echo.Context) error {
	if middleware.GetRole(c) != "super_admin" {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "insufficient permissions"})
	}
	requests, err := h.service.ListChangeRequests(c.Request().Context(), c.QueryParam("status"))
	if err != nil {
		return h.fail(c, err)
	}
	if requests == nil {
		requests = []models.ChangeRequest{}
	}
	return c.JSON(http.StatusOK, requests)
}

// @Summary      Approve a beacon change request
// @Description  Applies the requested delete/restore (super admin).
// @Tags         Beacon Approvals
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        id    path      string                     true  "Request ID"
// @Param        body  body      models.ReviewChangeRequest  false  "Review note"
// @Success      200   {object}  models.ChangeRequest
// @Router       /api/v1/beacon-requests/{id}/approve [post]
func (h *Handler) Approve(c echo.Context) error {
	return h.review(c, true)
}

// @Summary      Reject a beacon change request
// @Description  Rejects the request (super admin).
// @Tags         Beacon Approvals
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        id    path      string                     true  "Request ID"
// @Param        body  body      models.ReviewChangeRequest  false  "Review note"
// @Success      200   {object}  models.ChangeRequest
// @Router       /api/v1/beacon-requests/{id}/reject [post]
func (h *Handler) Reject(c echo.Context) error {
	return h.review(c, false)
}

func (h *Handler) review(c echo.Context, approve bool) error {
	if middleware.GetRole(c) != "super_admin" {
		return c.JSON(http.StatusForbidden, map[string]string{"error": "insufficient permissions"})
	}
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid request ID"})
	}
	var req models.ReviewChangeRequest
	_ = c.Bind(&req)
	actorID, err := currentUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Unauthorized"})
	}
	var request *models.ChangeRequest
	if approve {
		request, err = h.service.ApproveChangeRequest(c.Request().Context(), id, actorID, req.Note)
	} else {
		request, err = h.service.RejectChangeRequest(c.Request().Context(), id, actorID, req.Note)
	}
	if err != nil {
		return h.fail(c, err)
	}
	return c.JSON(http.StatusOK, request)
}

func (h *Handler) fail(c echo.Context, err error) error {
	switch {
	case errors.Is(err, services.ErrBeaconNotFound), errors.Is(err, services.ErrRequestNotFound):
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	case errors.Is(err, services.ErrBeaconExists), errors.Is(err, services.ErrPendingRequest):
		return c.JSON(http.StatusConflict, map[string]string{"error": err.Error()})
	case errors.Is(err, services.ErrBeaconInActiveEvent), errors.Is(err, services.ErrBeaconAlreadyDeleted), errors.Is(err, services.ErrBeaconNotDeleted), errors.Is(err, services.ErrRequestNotPending):
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	default:
		h.logger.Error("beacon operation failed", "error", err.Error())
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Beacon operation failed"})
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
