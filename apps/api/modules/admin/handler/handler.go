package handler

import (
	"errors"
	"net/http"

	"api/modules/admin/models"
	"api/modules/admin/services"
	"api/pkg/apputils"

	"github.com/go-playground/validator/v10"
	"github.com/gofrs/uuid/v5"
	"github.com/labstack/echo/v4"
	"log/slog"
)

type Handler struct {
	logger    *slog.Logger
	service   *services.AdminService
	validator *validator.Validate
}

type HandlerOpts struct {
	Logger  *slog.Logger
	Service *services.AdminService
}

func NewHandler(opts *HandlerOpts) *Handler {
	return &Handler{
		logger:    opts.Logger,
		service:   opts.Service,
		validator: validator.New(),
	}
}

// @Summary      List admins
// @Description  Lists admin and super admin accounts, including soft-deleted when requested.
// @Tags         Admin Management
// @Security     BearerAuth
// @Produce      json
// @Success      200  {array}   map[string]interface{}
// @Router       /api/v1/admins [get]
func (h *Handler) ListAdmins(c echo.Context) error {
	var filter models.AdminFilter
	if err := c.Bind(&filter); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid filter parameters"})
	}
	admins, err := h.service.ListAdmins(c.Request().Context(), &filter)
	if err != nil {
		h.logger.Error("failed to list admins", "error", err.Error())
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Failed to retrieve admins"})
	}
	return c.JSON(http.StatusOK, admins)
}

// @Summary      Create an admin
// @Description  Creates an admin account and returns a one-time temporary password.
// @Tags         Admin Management
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        body  body      models.CreateAdminRequest  true  "Admin payload"
// @Success      201   {object}  models.TemporaryPasswordResponse
// @Failure      409   {object}  map[string]string
// @Router       /api/v1/admins [post]
func (h *Handler) CreateAdmin(c echo.Context) error {
	var req models.CreateAdminRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid request payload"})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]any{
			"error":   "Validation failed",
			"details": apputils.ValidationErrorsToMap(err, req),
		})
	}

	user, tempPassword, err := h.service.CreateAdmin(c.Request().Context(), req.Name, req.Email)
	if err != nil {
		if errors.Is(err, services.ErrAdminEmailExists) {
			return c.JSON(http.StatusConflict, map[string]string{"error": err.Error()})
		}
		h.logger.Error("failed to create admin", "error", err.Error())
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Failed to create admin"})
	}

	return c.JSON(http.StatusCreated, models.TemporaryPasswordResponse{
		User:              user,
		TemporaryPassword: tempPassword,
	})
}

// @Summary      Get an admin
// @Description  Returns an admin or super admin by id.
// @Tags         Admin Management
// @Security     BearerAuth
// @Produce      json
// @Param        id  path      string  true  "Admin ID"
// @Success      200  {object}  map[string]interface{}
// @Router       /api/v1/admins/{id} [get]
func (h *Handler) GetAdmin(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid admin ID"})
	}
	user, err := h.service.GetAdmin(c.Request().Context(), id)
	if err != nil {
		return h.adminError(c, err)
	}
	return c.JSON(http.StatusOK, user)
}

// @Summary      Update an admin
// @Description  Updates an admin's name and email. Roles are immutable.
// @Tags         Admin Management
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        id    path      string                     true  "Admin ID"
// @Param        body  body      models.UpdateAdminRequest  true  "Admin payload"
// @Success      200   {object}  map[string]interface{}
// @Router       /api/v1/admins/{id} [put]
func (h *Handler) UpdateAdmin(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid admin ID"})
	}
	var req models.UpdateAdminRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid request payload"})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]any{
			"error":   "Validation failed",
			"details": apputils.ValidationErrorsToMap(err, req),
		})
	}
	user, err := h.service.UpdateAdmin(c.Request().Context(), id, req.Name, req.Email)
	if err != nil {
		return h.adminError(c, err)
	}
	return c.JSON(http.StatusOK, user)
}

// @Summary      Delete an admin
// @Description  Soft-deletes an admin and revokes their sessions.
// @Tags         Admin Management
// @Security     BearerAuth
// @Produce      json
// @Param        id  path      string  true  "Admin ID"
// @Success      200  {object}  map[string]string
// @Router       /api/v1/admins/{id} [delete]
func (h *Handler) DeleteAdmin(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid admin ID"})
	}
	actorID, err := currentUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Unauthorized"})
	}
	if err := h.service.DeleteAdmin(c.Request().Context(), id, actorID); err != nil {
		return h.adminError(c, err)
	}
	return c.JSON(http.StatusOK, map[string]string{"message": "Admin deleted"})
}

// @Summary      Reset an admin password
// @Description  Generates a new one-time temporary password and forces a change on next sign-in.
// @Tags         Admin Management
// @Security     BearerAuth
// @Produce      json
// @Param        id  path      string  true  "Admin ID"
// @Success      200  {object}  map[string]string
// @Router       /api/v1/admins/{id}/reset-password [post]
func (h *Handler) ResetPassword(c echo.Context) error {
	id, err := parseID(c.Param("id"))
	if err != nil {
		return c.JSON(http.StatusBadRequest, map[string]string{"error": "Invalid admin ID"})
	}
	actorID, err := currentUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]string{"error": "Unauthorized"})
	}
	tempPassword, err := h.service.ResetPassword(c.Request().Context(), id, actorID)
	if err != nil {
		return h.adminError(c, err)
	}
	return c.JSON(http.StatusOK, map[string]string{"temporary_password": tempPassword})
}

func (h *Handler) adminError(c echo.Context, err error) error {
	switch {
	case errors.Is(err, services.ErrAdminNotFound):
		return c.JSON(http.StatusNotFound, map[string]string{"error": err.Error()})
	case errors.Is(err, services.ErrCannotModifySuper), errors.Is(err, services.ErrCannotDeleteSelf), errors.Is(err, services.ErrInvalidRole):
		return c.JSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	case errors.Is(err, services.ErrAdminEmailExists):
		return c.JSON(http.StatusConflict, map[string]string{"error": err.Error()})
	default:
		h.logger.Error("admin operation failed", "error", err.Error())
		return c.JSON(http.StatusInternalServerError, map[string]string{"error": "Admin operation failed"})
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
