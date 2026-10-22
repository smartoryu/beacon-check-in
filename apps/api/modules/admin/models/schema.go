// Package models contains HTTP and domain models for admin account management.
package models

import (
	user_models "api/modules/user/models"
)

type CreateAdminRequest struct {
	Name  string `json:"name" validate:"required,min=2,max=120" example:"Jane Admin"`
	Email string `json:"email" validate:"required,email" example:"jane@example.com"`
}

type UpdateAdminRequest struct {
	Name  string `json:"name" validate:"required,min=2,max=120" example:"Jane Admin"`
	Email string `json:"email" validate:"required,email" example:"jane@example.com"`
}

type TemporaryPasswordResponse struct {
	User              *user_models.User `json:"user"`
	TemporaryPassword string            `json:"temporary_password"`
}

type AdminFilter struct {
	Search         string `json:"search,omitempty" query:"search"`
	IncludeDeleted bool   `json:"include_deleted,omitempty" query:"include_deleted"`
}
