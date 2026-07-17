resource "random_string" "random" {
  length  = 6
  upper   = false
  special = false
  lower   = true
  numeric = true
}

resource "google_container_cluster" "cluster" {
  name        = "${var.cluster_name}-${random_string.random.id}"
  description = "My Cluster"
  location    = var.zone

  release_channel {
    channel = "REGULAR"
  }
  gke_auto_upgrade_config {
    patch_mode = "ACCELERATED"
  }

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.cluster_subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = google_compute_subnetwork.cluster_subnet.secondary_ip_range[0].range_name
    services_secondary_range_name = google_compute_subnetwork.cluster_subnet.secondary_ip_range[1].range_name
  }

  node_config {
    service_account = var.np_sa
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    spot = true
  }

  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = ""
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
  }


  logging_config {
    enable_components = ["SYSTEM_COMPONENTS"]
  }
  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS"]
    managed_prometheus {
      enabled = false
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false

  depends_on = [google_compute_subnetwork.cluster_subnet]
}
