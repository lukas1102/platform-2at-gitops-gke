output "external_dns_gsa_email" {
  value = google_service_account.external_dns.email
}
output "cert_manager_gsa_email" {
  value = google_service_account.cert_manager.email
}
output "eso_gsa_email" {
  value = google_service_account.eso.email
}
output "crossplane_gsa_email" {
  value = google_service_account.crossplane.email
}
output "np_sa_email" {
  value = google_service_account.np_sa.email
}
