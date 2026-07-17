variable "project_id" {
  description = "project id"
  type        = string
}

variable "name_prefix" {
  description = "Prefix name for the resources"
  type        = string
  default     = "demo"
}

variable "cluster_name" {
  type    = string
  default = "gke-cluster"
}

variable "region" {
  description = "region"
  type        = string
  default     = "europe-west4"
}

variable "zone" {
  description = "zone"
  type        = string
  default     = "europe-west4-a"
}

variable "min_node_count" {
  type    = number
  default = 1
}

variable "max_node_count" {
  type    = number
  default = 4
}

variable "machine_type" {
  description = "Node machine type"
  type        = string
  default     = "e2-standard-4"
}

variable "np_sa" {
  type = string
}