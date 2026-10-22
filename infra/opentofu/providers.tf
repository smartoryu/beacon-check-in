provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  zone    = var.gcp_zone
}

# Token comes from terraform.tfvars (var.cloudflare_api_token), which takes
# precedence over the CLOUDFLARE_API_TOKEN environment variable.
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
