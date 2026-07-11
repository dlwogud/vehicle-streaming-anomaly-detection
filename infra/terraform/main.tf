resource "google_compute_firewall" "pipeline_ui" {
  name    = "allow-pipeline-ui"
  network = "default"
  project = var.project_id

  allow {
    protocol = "tcp"
    ports    = ["8080", "8081"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["vehicle-anomaly-pipeline"]
}

resource "google_compute_instance" "pipeline_vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.boot_disk_image
      size  = 30
    }
  }

  network_interface {
    network = "default"

    access_config {}
  }

  tags = ["vehicle-anomaly-pipeline"]

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -euo pipefail
    exec > /var/log/startup-script.log 2>&1

    # Install Docker
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker

    # Install Docker Compose v2 plugin
    mkdir -p /usr/local/lib/docker/cli-plugins
    curl -SL "https://github.com/docker/compose/releases/download/v2.27.0/docker-compose-linux-x86_64" \
      -o /usr/local/lib/docker/cli-plugins/docker-compose
    chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

    # Clone repo
    git clone --depth=1 https://github.com/dlwogud/vehicle-streaming-anomaly-detection.git /opt/vehicle
    cd /opt/vehicle

    # Build Flink JAR via Maven Docker container
    mkdir -p build
    docker run --rm \
      -v /opt/vehicle:/workspace \
      -w /workspace/flink \
      maven:3.9.9-eclipse-temurin-11 \
      mvn -q clean package
    cp flink/target/vehicle-anomaly-job.jar build/

    # Start infra layer (Zookeeper, Kafka, PostgreSQL)
    docker compose up -d zookeeper postgres kafka airflow-postgres

    # Wait for Kafka to become healthy
    timeout 180 bash -c \
      'until docker inspect --format="{{.State.Health.Status}}" kafka 2>/dev/null | grep -q healthy; do sleep 5; done'

    # Create Kafka topic (3 partitions)
    docker exec kafka bash -lc \
      "kafka-topics --bootstrap-server kafka:9092 \
       --create --if-not-exists \
       --topic vehicle-sensor-data \
       --partitions 3 \
       --replication-factor 1"

    # Start Flink (standalone-job mode — submits job automatically)
    docker compose up -d jobmanager taskmanager

    # Start Airflow (docker compose resolves airflow-init dependency automatically)
    docker compose up -d airflow-webserver airflow-scheduler

    echo "Startup complete."
  EOF
}
