variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "gitops-cluster"
}

variable "gcp_project_id" {
  type = string
}

variable "gcp_name_prefix" {
  description = "Prefix name for the resources"
  type        = string
  default     = "demo"
}

variable "gcp_user_email" {
  type = string
}

variable "region" {
  type    = string
  default = "europe-west4"
}

variable "gcp_bucket_state" {
  type = string
}

variable "bucket_prefix" {
  type = string
}

variable "dns_name" {
  type    = string
  default = "fhbglstudy"
}

variable "dns_zone" {
  type    = string
  default = "example.com"
}

variable "cloudflare_api_token" {
  type = string
}

variable "cloudflare_zone_id" {
  description = "Zone ID of the parent domain in Cloudflare"
  type        = string
}
