data "cloudflare_zone" "api" {
  name = var.cloudflare_zone_name
}

data "cloudflare_ip_ranges" "cloudflare" {}

resource "google_compute_address" "api" {
  name   = "${var.instance_name}-ip"
  region = var.gcp_region

  labels = var.labels
}

resource "google_compute_firewall" "ssh" {
  name    = "${var.instance_name}-ssh"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [var.admin_cidr]
  target_tags   = ["beacon-check-in-ssh"]
}

resource "google_compute_firewall" "web" {
  name    = "${var.instance_name}-web"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  # With Cloudflare proxying enabled, only Cloudflare edge IPs need to reach
  # the origin. With DNS-only, the origin is public.
  source_ranges = var.cloudflare_proxied ? data.cloudflare_ip_ranges.cloudflare.ipv4_cidr_blocks : ["0.0.0.0/0"]
  target_tags   = ["beacon-check-in-web"]
}

resource "google_compute_instance" "api" {
  name         = var.instance_name
  machine_type = var.machine_type
  zone         = var.gcp_zone

  tags = ["beacon-check-in-ssh", "beacon-check-in-web"]

  labels = var.labels

  boot_disk {
    initialize_params {
      image = "projects/ubuntu-os-cloud/global/images/family/${var.image_family}"
      size  = var.disk_size_gb
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.api.address
    }
  }

  metadata = {
    ssh-keys = "${var.ssh_user}:${var.ssh_public_key}"
  }

  metadata_startup_script = file("${path.module}/startup.sh")

  allow_stopping_for_update = true
  deletion_protection       = false
}

resource "cloudflare_record" "api" {
  zone_id = data.cloudflare_zone.api.id
  name    = var.domain
  type    = "A"
  content = google_compute_address.api.address
  proxied = var.cloudflare_proxied
  ttl     = var.cloudflare_proxied ? 1 : 300
  comment = "Beacon Check-In API"
}
