package middleware

import (
	"fmt"
	"net/http"

	"github.com/labstack/echo/v4"
)

// RequireRole allows the request only when the JWT role claim is one of roles.
// It must run after the auth JWT middleware, which stores the role in context.
func RequireRole(roles ...string) echo.MiddlewareFunc {
	allowed := make(map[string]struct{}, len(roles))
	for _, role := range roles {
		allowed[role] = struct{}{}
	}

	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			role := GetRole(c)
			if role == "" {
				return echo.NewHTTPError(http.StatusUnauthorized, "missing role claim")
			}
			if _, ok := allowed[role]; !ok {
				return echo.NewHTTPError(http.StatusForbidden, "insufficient permissions")
			}
			return next(c)
		}
	}
}

// GetRole returns the role set by the JWT middleware.
func GetRole(c echo.Context) string {
	if role, ok := c.Get("role").(string); ok {
		return role
	}
	if claims, ok := c.Get("jwt_claims").(map[string]any); ok {
		if role, ok := claims["role"]; ok {
			return fmt.Sprint(role)
		}
	}
	return ""
}
