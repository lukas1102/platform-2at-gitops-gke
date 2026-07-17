variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "name" {
  description = "Resource name of the managed zone"
  type        = string
}

variable "dns_name" {
  description = "DNS name of the zone, e.g. example.com."
  type        = string
}

variable "description" {
  description = "Description of the zone"
  type        = string
  default     = "Managed by OpenTofu"
}

variable "dnssec_enabled" {
  description = "Enable DNSSEC on the zone"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to the zone"
  type        = map(string)
  default     = {}
}
