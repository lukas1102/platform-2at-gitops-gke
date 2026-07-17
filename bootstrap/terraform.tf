terraform {
  backend "gcs" {
    bucket = var.gcp_bucket_state
    prefix = var.bucket_prefix
  }
}