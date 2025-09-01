resource "google_compute_network" "vpc_network" {
  name = "server-networks"
}

resource "google_compute_firewall" "ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "web_ports" {
  name    = "allow-web-traffic"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "3000", "3001", "4000"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = ["web-enabled"]
}

# ==============================
# Compute Instance
# ==============================
resource "google_compute_instance" "fastapi_vm" {
  name         = "fastapi-server"
  machine_type = "e2-medium"
  zone         = var.zone

  tags = ["web-enabled"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {} # Needed for external IP
  }

  # Run deployment.sh automatically on boot
  metadata_startup_script = file("${path.module}/deployment.sh")
}


output "fastapi_vm_ip" {
  description = "Public IP of the FastAPI VM"
  value       = google_compute_instance.fastapi_vm.network_interface[0].access_config[0].nat_ip
}

