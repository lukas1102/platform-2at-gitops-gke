terraform {
  required_version = ">= 1.12.0"

  required_providers {
    google = {
      source  = "opentofu/google"
      version = ">= 7.0"
    }
  }
}

provider "google" {

  project = var.project_id
  region  = var.region
  zone    = var.zone
}
