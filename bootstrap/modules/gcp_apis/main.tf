locals {
  apis = [
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
    "dns.googleapis.com",
    "cloudkms.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "sqladmin.googleapis.com",
    "servicenetworking.googleapis.com",
    "secretmanager.googleapis.com",
  ]
}

resource "google_project_service" "services" {
  for_each = toset(local.apis)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
