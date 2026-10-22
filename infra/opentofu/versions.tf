terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 6.0, < 7.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 4.40, < 5.0"
    }
  }

  # Partial GCS backend. Provide the bucket at init time:
  #   tofu init \
  #     -backend-config="bucket=$TF_STATE_BUCKET" \
  #     -backend-config="prefix=beacon-check-in/infra"
  backend "gcs" {}
}
