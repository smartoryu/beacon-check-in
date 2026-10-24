# Beacon Check-In API

Go/Echo API for Beacon Check-In. It handles authentication, roles, beacons, events, check-in validation, triangulation and dashboards.

- [Complete application guide](../../docs/README.md)
- [API reference](../../docs/API.md)
- [Swagger/OpenAPI guide](../../docs/SWAGGER.md)
- Interactive docs: `http://localhost:8080/api-docs`
- Raw spec: `http://localhost:8080/api/openapi.json`

This template already pre-configured basic auth, take a look at `apps/api/database/seeders/user_factory.go`.

## Common Tasks
```sh
moon api:dev                  # Run development
moon api:run                  # Execute `go run`
moon api:build                # Build the application
moon api:start                # Start application from build
moon api:test                 # Run testing
moon api:coverage             # Run test coverage
moon api:format               # Run code formatting
moon api:tidy                 # Install dependencies
moon api:docker-build         # Build docker image
moon api:docker-run           # Run docker image
moon api:docker-shell         # Execute docker shell
moon api:dump                 # Dump the database
moon api:install-mockery      # Install mockery
moon api:generate-swagger     # Generate Swagger OpenAPI docs
moon api:generate-mock        # Generate Mock
```

## Migration Tasks
```sh
# Initiate or reset migrations and seed
moon api:run -- migrate:reset --up --seed --force

# Common migration commands
moon api:run -- migrate:up
moon api:run -- migrate:status
moon api:run -- migrate:version
moon api:run -- migrate:create [MIGRATION_NAME]
moon api:run -- migrate:down
moon api:run -- migrate:reset
moon api:run -- migrate:seed
```

## Generate Sample Configuration
This command will generate `.env.example` from `apps/api/internal/config/default.go`:

```sh
moon api:run -- generate:config
```

## Scaffold New Module
```sh
mkdir -p apps/api/modules/dummy
mkdir -p apps/api/modules/dummy/handler
mkdir -p apps/api/modules/dummy/models
mkdir -p apps/api/modules/dummy/repository
mkdir -p apps/api/modules/dummy/services
echo 'package handler' > apps/api/modules/dummy/handler/handler.go
echo 'package models' > apps/api/modules/dummy/models/model.go
echo 'package models' > apps/api/modules/dummy/models/schema.go
echo 'package repository' > apps/api/modules/dummy/repository/repository.go
echo 'package services' > apps/api/modules/dummy/services/services.go
echo 'package dummy' > apps/api/modules/dummy/module.go
```

> Replace `dummy` with the module name
