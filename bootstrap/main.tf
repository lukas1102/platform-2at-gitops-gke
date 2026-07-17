module "gke" {
  source = "./modules/gke"

  project_id  = var.gcp_project_id
  name_prefix = var.gcp_name_prefix
  np_sa       = module.iam.np_sa_email
}

module "iam" {
  source = "./modules/iam"

  project_id     = var.gcp_project_id
  gcp_user_email = var.gcp_user_email
}

module "dns" {
  source = "./modules/dns"

  project_id = var.gcp_project_id
  name       = var.dns_name
  dns_name   = var.dns_zone
}

