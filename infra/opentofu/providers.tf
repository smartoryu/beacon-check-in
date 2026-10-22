provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# The Cloudflare provider reads CLOUDFLARE_API_TOKEN from the environment.
provider "cloudflare" {}
