

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
    ports    = ["80", "443", "8000", "5432"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-enabled"]
}

resource "google_compute_instance" "server_vm" {
  name         = "server-1"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "centos-stream-9-v20250610"
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {}
  }

  metadata = {
    enable-oslogin = "FALSE"
    github_token   = var.github_token
    startup-script = file("${path.module}/deployment.sh")
    ssh-keys       = "${split("@", data.google_client_openid_userinfo.me.email)[0]}:${tls_private_key.ssh.public_key_openssh}"
  }

  tags = ["ssh-enabled", "web-enabled"]
}

output "server_vm_ip" {
  description = "Public IP address of the server VM"
  value       = google_compute_instance.server_vm.network_interface[0].access_config[0].nat_ip
}
