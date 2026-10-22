variable "gcp_project_id" {
  description = "GCP project that owns the API VM."
  type        = string
}

variable "gcp_region" {
  description = "GCP region. e2-micro free tier: us-central1, us-west1, us-east1."
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP zone for the VM."
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  description = "Compute Engine instance name."
  type        = string
  default     = "beacon-check-in-api"
}

variable "machine_type" {
  description = "Compute Engine machine type."
  type        = string
  default     = "e2-micro"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB. 30 is the e2-micro free-tier limit."
  type        = number
  default     = 30
}

variable "image_family" {
  description = "Ubuntu image family."
  type        = string
  default     = "ubuntu-2404-lts-amd64"
}

variable "ssh_user" {
  description = "Linux user created for SSH access and deployments."
  type        = string
  default     = "deploy"
}

variable "ssh_public_key" {
  description = "Public key for the deploy user (ssh-ed25519 ...)."
  type        = string
  sensitive   = true
}

variable "admin_cidr" {
  description = "CIDR allowed to reach SSH (port 22), e.g. 203.0.113.10/32."
  type        = string
}

variable "domain" {
  description = "Public API hostname."
  type        = string
  default     = "beacon-check-in-api.playground.my.id"
}

variable "cloudflare_zone_name" {
  description = "Cloudflare zone that contains the API hostname."
  type        = string
  default     = "playground.my.id"
}

variable "cloudflare_proxied" {
  description = "Whether the Cloudflare A record is proxied (orange cloud)."
  type        = bool
  default     = true
}

variable "labels" {
  description = "Labels applied to GCP resources."
  type        = map(string)
  default = {
    app     = "beacon-check-in"
    env     = "production"
    managed = "opentofu"
  }
}
