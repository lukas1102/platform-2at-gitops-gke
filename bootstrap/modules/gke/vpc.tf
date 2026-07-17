resource "google_compute_network" "vpc" {
  name                    = "${var.name_prefix}-cluster-vpc"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "cluster_subnet" {
  name          = "${var.name_prefix}-cluster-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "192.168.0.0/20"

  secondary_ip_range {
    range_name    = "pod-cidr-range"
    ip_cidr_range = "10.10.0.0/19"
  }

  secondary_ip_range {
    range_name    = "service-cidr-range"
    ip_cidr_range = "10.10.32.0/19"
  }
}

resource "google_compute_router" "router" {
  project = var.project_id
  name    = "${var.name_prefix}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "nat" {
  project                            = var.project_id
  name                               = "${var.name_prefix}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = false
    filter = "ERRORS_ONLY"
  }
}
