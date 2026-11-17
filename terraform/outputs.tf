output "app_public_ip" {
  description = "IP Público da VM da Aplicação"
  value       = oci_core_instance.vm_app.public_ip
}

output "app_private_ip" {
  description = "IP Privado da VM da Aplicação"
  value       = oci_core_instance.vm_app.private_ip
}

output "db_private_ip" {
  description = "IP Privado da VM do MongoDB"
  value       = oci_core_instance.vm_db.private_ip
}

output "app_url" {
  description = "URL de acesso ao ToDo App"
  value       = "https://${oci_core_instance.vm_app.public_ip}.sslip.io"
}