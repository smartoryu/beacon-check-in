package middleware

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
)

func TestRequireRole(t *testing.T) {
	e := echo.New()

	tests := []struct {
		name       string
		role       string
		wantStatus int
	}{
		{"allowed", "admin", http.StatusNoContent},
		{"super admin allowed", "super_admin", http.StatusNoContent},
		{"forbidden", "user", http.StatusForbidden},
		{"missing", "", http.StatusUnauthorized},
	}

	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			req := httptest.NewRequest(http.MethodGet, "/", nil)
			rec := httptest.NewRecorder()
			c := e.NewContext(req, rec)
			if test.role != "" {
				c.Set("role", test.role)
			}

			handler := RequireRole("super_admin", "admin")(func(c echo.Context) error {
				return c.NoContent(http.StatusNoContent)
			})
			err := handler(c)
			if err == nil {
				if rec.Code != test.wantStatus {
					t.Fatalf("status = %d, want %d", rec.Code, test.wantStatus)
				}
				return
			}
			httpErr, ok := err.(*echo.HTTPError)
			if !ok {
				t.Fatalf("expected HTTPError, got %T", err)
			}
			if httpErr.Code != test.wantStatus {
				t.Fatalf("status = %d, want %d", httpErr.Code, test.wantStatus)
			}
		})
	}
}
