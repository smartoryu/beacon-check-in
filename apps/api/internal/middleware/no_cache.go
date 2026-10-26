package middleware

import "github.com/labstack/echo/v4"

// NoCacheMiddleware prevents browsers, proxies and mobile HTTP clients from
// serving stale API responses. Mutating requests are unaffected.
func NoCacheMiddleware() echo.MiddlewareFunc {
	return func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			c.Response().Header().Set(echo.HeaderCacheControl, "no-store, no-cache, must-revalidate, max-age=0")
			c.Response().Header().Set("Pragma", "no-cache")
			return next(c)
		}
	}
}
