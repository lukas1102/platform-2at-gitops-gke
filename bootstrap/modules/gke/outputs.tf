output "project_id" {
  value       = var.project_id
  description = "Project ID where the cluster is deployed"
}
output "zone" {
  value       = var.zone
  description = "Zone where the cluster is deployed"
}

output "vpc_name" {
  value = google_compute_network.vpc.name
}

output "kubernetes_cluster_name" {
  value       = google_container_cluster.cluster.name
  description = "Cluster Name"
}

output "kubernetes_cluster_gcloud_command" {
  value       = "KUBECONFIG=./gke.kubeconfig gcloud container clusters get-credentials ${google_container_cluster.cluster.name} --zone ${var.zone} --project ${var.project_id}"
  description = "Command to get credentials for the cluster"
}

output "cluster_endpoint" {
  value = google_container_cluster.cluster.endpoint
}

output "ca_cert" {
  value     = base64decode(google_container_cluster.cluster.master_auth[0].cluster_ca_certificate)
  sensitive = true
}

data "google_client_config" "default" {}

output "access_token" {
  value = data.google_client_config.default.access_token
}