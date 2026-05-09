variable "project_id" {
  description = "GCP project ID used for Terraform-managed resources."
  type        = string
}

variable "region" {
  description = "Default GCP region for this project."
  type        = string
  default     = "asia-northeast3"
}

variable "zone" {
  description = "Default GCP zone for the Compute Engine VM."
  type        = string
  default     = "asia-northeast3-a"
}

variable "vm_name" {
  description = "Name of the Compute Engine VM for the pipeline lab."
  type        = string
  default     = "vehicle-anomaly-vm"
}

variable "machine_type" {
  description = "Compute Engine machine type."
  type        = string
  default     = "e2-small"
}

variable "boot_disk_image" {
  description = "Boot disk image for the VM."
  type        = string
  default     = "debian-cloud/debian-12"
}
