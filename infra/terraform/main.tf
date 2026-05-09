resource "google_compute_instance" "pipeline_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.boot_disk_image
      size  = 20
    }
  }

  network_interface {
    network = "default"

    access_config {
      // Allocates an ephemeral public IP for SSH and simple testing.
    }
  }

  tags = ["vehicle-anomaly-pipeline"]

  metadata = {
    enable-oslogin = "TRUE"
  }
}
