data "google_container_engine_versions" "versions" {}

resource "google_container_node_pool" "node_pool" {
  name_prefix    = "${var.name_prefix}-np"
  cluster        = google_container_cluster.cluster.name
  location       = var.zone
  node_locations = [var.zone]

  version            = data.google_container_engine_versions.versions.release_channel_default_version["STABLE"]
  initial_node_count = var.min_node_count
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  network_config {
    enable_private_nodes = true
    subnetwork           = google_compute_subnetwork.cluster_subnet.name
  }

  node_config {
    spot         = true
    machine_type = var.machine_type
    image_type   = "COS_CONTAINERD"

    boot_disk {
      disk_type = "pd-balanced"
      size_gb   = 32
    }

    service_account = var.np_sa

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    labels = {
      role = "worker"
    }
  }

  lifecycle {
    ignore_changes = [version]
  }
}
