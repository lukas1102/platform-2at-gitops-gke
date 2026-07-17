resource "google_dns_managed_zone" "this" {
  project     = var.project_id
  name        = var.name
  dns_name    = var.dns_name
  description = var.description
  visibility  = "public"
  labels      = var.labels

  dnssec_config {
    state = var.dnssec_enabled ? "on" : "off"
  }
}
