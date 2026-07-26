locals {
  wi_pool = "${var.project_id}.svc.id.goog"

  components = {
    external_dns = {
      namespace = "external-dns"
      sa_name   = "external-dns"
    }
    cert_manager = {
      namespace = "cert-manager"
      sa_name   = "cert-manager"
    }
    eso = {
      namespace = "external-secrets"
      sa_name   = "external-secrets"
    }
    crossplane = {
      namespace = "crossplane-system"
      sa_name   = "crossplane"
      members   = ["crossplane-gcp", "provider-kubernetes"]
    }
  }
}

# ---------- Google Service Accounts ----------

resource "google_service_account" "external_dns" {
  project      = var.project_id
  account_id   = "${var.prefix}-external-dns-sa"
  display_name = "ExternalDNS Workload Identity SA"
}

resource "google_service_account" "cert_manager" {
  project      = var.project_id
  account_id   = "${var.prefix}-cert-manager-sa"
  display_name = "cert-manager Workload Identity SA"
}

resource "google_service_account" "eso" {
  project      = var.project_id
  account_id   = "${var.prefix}-external-secrets-sa"
  display_name = "External Secrets Operator Workload Identity SA"
}

resource "google_service_account" "crossplane" {
  project      = var.project_id
  account_id   = "${var.prefix}-crossplane-sa"
  display_name = "Crossplane Workload Identity SA"
}

resource "google_service_account" "np_sa" {
  project      = var.project_id
  account_id   = "${var.prefix}-np-sa"
  display_name = "Service Account for the cluster"
}

# ---------- IAM roles ----------
resource "google_project_iam_member" "external_dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.external_dns.email}"
}

resource "google_project_iam_member" "cert_manager_dns_admin" {
  project = var.project_id
  role    = "roles/dns.admin"
  member  = "serviceAccount:${google_service_account.cert_manager.email}"
}

resource "google_project_iam_member" "eso_secretsmanager" {
  project = var.project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${google_service_account.eso.email}"
}

resource "google_project_iam_member" "crossplane" {
  for_each = toset([
    "roles/iam.editor",
    "roles/compute.editor",
    "roles/container.editor",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/secretmanager.admin",
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.crossplane.email}"
}

resource "google_project_iam_member" "np_sa_iam" {
  project = var.project_id
  role    = "roles/container.defaultNodeServiceAccount"
  member  = "serviceAccount:${google_service_account.np_sa.email}"
}


resource "google_project_iam_member" "gke_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "user:${var.gcp_user_email}"
}

# ---------- Workload Identity bindings ----------

resource "google_service_account_iam_member" "external_dns_wi" {
  service_account_id = google_service_account.external_dns.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.wi_pool}[${local.components.external_dns.namespace}/${local.components.external_dns.sa_name}]"
}

resource "google_service_account_iam_member" "cert_manager_wi" {
  service_account_id = google_service_account.cert_manager.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.wi_pool}[${local.components.cert_manager.namespace}/${local.components.cert_manager.sa_name}]"
}

resource "google_service_account_iam_member" "eso_wi" {
  service_account_id = google_service_account.eso.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.wi_pool}[${local.components.eso.namespace}/${local.components.eso.sa_name}]"
}

resource "google_service_account_iam_member" "crossplane_wi" {
  service_account_id = google_service_account.crossplane.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.wi_pool}[${local.components.crossplane.namespace}/${local.components.crossplane.sa_name}]"
}

resource "google_service_account_iam_member" "crossplane_compute_wi" {
  for_each = toset(local.components.crossplane.members)

  service_account_id = google_service_account.crossplane.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${local.wi_pool}[${local.components.crossplane.namespace}/${each.value}]"
}
