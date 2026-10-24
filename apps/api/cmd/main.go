package main

import (
	"fmt"
	"os"

	"api/cmd/commands"
)

// @title           Beacon Check-In API
// @description     REST API for Beacon Check-In, an iBeacon attendance system. Admins register and place beacons on event floor plans; users check in from the Flutter app using nearby beacon readings. Interactive documentation is available at /api-docs and the raw OpenAPI document at /api/openapi.json.
// @version         1.0
// @BasePath        /

// @securityDefinitions.apikey BearerAuth
// @in              header
// @name            Authorization
// @description     Bearer JWT access token. Format: "Bearer <access_token>".
func main() {
	if err := commands.RootCmd.Execute(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}
