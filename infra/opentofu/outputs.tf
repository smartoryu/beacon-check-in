output "instance_name" {
  description = "Compute Engine instance name."
  value       = google_compute_instance.api.name
}

output "static_ip" {
  description = "Static external IP of the API VM."
  value       = google_compute_address.api.address
}

output "api_url" {
  description = "Public API base URL."
  value       = "https://${var.domain}"
}

output "web_url" {
  description = "Public web app URL."
  value       = "https://${var.web_domain}"
}

output "ssh_command" {
  description = "SSH command for the deploy user."
  value       = "ssh ${var.ssh_user}@${google_compute_address.api.address}"
}

output "cloudflare_record" {
  description = "Cloudflare DNS record created for the API."
  value       = cloudflare_record.api.name
}

output "cloudflare_web_record" {
  description = "Cloudflare DNS record created for the web app."
  value       = cloudflare_record.web.name
}
