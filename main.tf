# ===== VPC Network =====
resource "google_compute_network" "vpc_network" {
  name = "server-networks"
}

# ===== Firewall Rules =====
resource "google_compute_firewall" "ssh" {
  name    = "allow-ssh-2"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_firewall" "web_ports" {
  name    = "allow-web-traffic-2"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8000", "5432"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-enabled"]
}

# ===== Get current user email for SSH =====
data "google_client_openid_userinfo" "me" {}

# ===== SSH Key =====
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# ===== Compute Instance =====
resource "google_compute_instance" "server_vm" {
  name         = "server-2"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "centos-stream-9-v20250610"
      labels = {
        my_label = "value"
      }
    }
  }

  network_interface {
    network       = google_compute_network.vpc_network.name
    access_config {}
  }

  tags = ["ssh-enabled", "web-enabled"]

  metadata = {
    enable-oslogin = "FALSE"

    # ===== Inject GitHub Token into startup script =====
    startup-script = <<-EOT
      #!/bin/bash
      export GITHUB_TOKEN="${GITHUB_TOKEN}"
      /bin/bash /deployment.sh
    EOT

    ssh-keys = "${split("@", data.google_client_openid_userinfo.me.email)[0]}:${tls_private_key.ssh.public_key_openssh}"
  }
}

# ===== Outputs =====
output "server_vm_ip" {
  description = "Public IP address of the server VM"
  value       = google_compute_instance.server_vm.network_interface[0].access_config[0].nat_ip
