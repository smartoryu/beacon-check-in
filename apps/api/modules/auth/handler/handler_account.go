package handler

import (
	"errors"
	"net/http"

	"api/modules/auth/models"
	"api/modules/auth/services"
	"api/pkg/apputils"

	"github.com/gofrs/uuid/v5"
	"github.com/labstack/echo/v4"
)

// @Summary      Register a user account
// @Description  Creates a self-registered user account and returns an authenticated session.
// @Tags         Auth - Authentication
// @Accept       json
// @Produce      json
// @Param        body  body      models.SignUpRequest  true  "Sign up payload"
// @Success      201   {object}  models.SignInResponse
// @Failure      400   {object}  map[string]interface{}
// @Failure      409   {object}  map[string]interface{}
// @Router       /api/v1/auth/signup [post]
func (h *Handler) SignUp(c echo.Context) error {
	var req models.SignUpRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":   "Invalid request payload",
			"details": err.Error(),
		})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":   "Validation failed",
			"details": apputils.ValidationErrorsToMap(err, req),
		})
	}

	authedUser, err := h.authService.SignUp(c.Request().Context(), req.Name, req.Email, req.Password)
	if err != nil {
		if errors.Is(err, services.ErrEmailAlreadyExists) {
			return c.JSON(http.StatusConflict, map[string]interface{}{
				"error":   "Email already registered",
				"details": "An account with this email already exists.",
			})
		}
		h.logger.Error("signup failed", "error", err.Error())
		return c.JSON(http.StatusInternalServerError, map[string]interface{}{
			"error":   "Internal server error",
			"details": err.Error(),
		})
	}

	return c.JSON(http.StatusCreated, authedUser)
}

// @Summary      Refresh an access token
// @Description  Exchanges a valid refresh JWT for a new access token.
// @Tags         Auth - Authentication
// @Accept       json
// @Produce      json
// @Param        body  body      models.RefreshRequest  true  "Refresh token"
// @Success      200   {object}  models.SignInResponse
// @Failure      401   {object}  map[string]interface{}
// @Router       /api/v1/auth/refresh [post]
func (h *Handler) Refresh(c echo.Context) error {
	var req models.RefreshRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{"error": "Invalid request payload"})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":   "Validation failed",
			"details": apputils.ValidationErrorsToMap(err, req),
		})
	}
	authedUser, err := h.authService.Refresh(c.Request().Context(), req.RefreshToken)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{
			"error":   "Invalid refresh token",
			"details": err.Error(),
		})
	}
	return c.JSON(http.StatusOK, authedUser)
}

// @Summary      Change the current user's password
// @Description  Updates the authenticated user's password and clears the forced-change flag.
// @Tags         Auth - Account
// @Security     BearerAuth
// @Accept       json
// @Produce      json
// @Param        body  body      models.UpdatePasswordRequest  true  "Password payload"
// @Success      200   {object}  map[string]interface{}
// @Failure      400   {object}  map[string]interface{}
// @Router       /api/v1/auth/change-password [post]
func (h *Handler) ChangePassword(c echo.Context) error {
	userID, err := currentUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{"error": "Unauthorized"})
	}

	var req models.UpdatePasswordRequest
	if err := c.Bind(&req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":   "Invalid request payload",
			"details": err.Error(),
		})
	}
	if err := h.validator.Struct(req); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":   "Validation failed",
			"details": apputils.ValidationErrorsToMap(err, req),
		})
	}

	if err := h.authService.ChangePassword(c.Request().Context(), userID, req.CurrentPassword, req.NewPassword); err != nil {
		return c.JSON(http.StatusBadRequest, map[string]interface{}{
			"error":   "Failed to change password",
			"details": err.Error(),
		})
	}

	return c.JSON(http.StatusOK, map[string]interface{}{
		"message": "Password changed successfully",
	})
}

// @Summary      Get the current user
// @Description  Returns the authenticated user's profile, role and onboarding flags.
// @Tags         Auth - Account
// @Security     BearerAuth
// @Produce      json
// @Success      200  {object}  map[string]interface{}
// @Failure      401  {object}  map[string]interface{}
// @Router       /api/v1/auth/me [get]
func (h *Handler) Me(c echo.Context) error {
	userID, err := currentUserID(c)
	if err != nil {
		return c.JSON(http.StatusUnauthorized, map[string]interface{}{"error": "Unauthorized"})
	}

	user, err := h.authService.GetMe(c.Request().Context(), userID)
	if err != nil {
		h.logger.Error("failed to get current user", "error", err.Error())
		return c.JSON(http.StatusNotFound, map[string]interface{}{"error": "User not found"})
	}

	return c.JSON(http.StatusOK, user)
}

func currentUserID(c echo.Context) (uuid.UUID, error) {
	raw, ok := c.Get("user_id").(string)
	if !ok || raw == "" {
		return uuid.Nil, errors.New("missing user id")
	}
	return uuid.FromString(raw)
}
