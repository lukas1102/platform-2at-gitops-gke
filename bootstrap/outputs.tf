output "gke" {
  value = module.gke.kubernetes_cluster_gcloud_command
}

output "vpc_name" {
  value = module.gke.vpc_name
}

output "dns_name" {
  value = module.dns.name_servers
}