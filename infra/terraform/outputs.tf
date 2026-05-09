output "vm_name" {
  description = "Name of the provisioned Compute Engine VM."
  value       = google_compute_instance.pipeline_vm.name
}

output "vm_zone" {
  description = "Zone where the VM is provisioned."
  value       = google_compute_instance.pipeline_vm.zone
}

output "vm_external_ip" {
  description = "Ephemeral public IP address assigned to the VM."
  value       = google_compute_instance.pipeline_vm.network_interface[0].access_config[0].nat_ip
}
