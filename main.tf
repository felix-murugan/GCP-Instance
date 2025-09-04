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

  target_tags = ["web-enabled"]
}

data "google_client_openid_userinfo" "me" {}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "google_compute_instance" "server_vm" {
  name         = "server-1"
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

  # ✅ required: network interface
  network_interface {
    network       = google_compute_network.vpc_network.name
    access_config {} # assign external IP
  }

  # Inline startup script
  metadata = {
    ssh-keys           = "${split("@", data.google_client_openid_userinfo.me.email)[0]}:${tls_private_key.ssh.public_key_openssh}"
    serial-port-enable = "TRUE"
    startup-script     = <<EOT
#!/bin/bash
set -xe
exec > >(tee /var/log/startup.log | logger -t startup-script | tee /dev/ttyS0) 2>&1

# ===== Update & install dependencies =====
yum -y update
yum install -y python3 python3-pip git postgresql postgresql-server postgresql-contrib

# ===== Initialize PostgreSQL =====
/usr/bin/postgresql-setup --initdb
systemctl enable postgresql
systemctl start postgresql

# ===== Configure PostgreSQL DB =====
su - postgres -c "psql -c \\"ALTER USER postgres WITH PASSWORD 'admin12';\\""
su - postgres -c "psql -c \\"CREATE DATABASE kasadara;\\""
su - postgres -c "psql -c \\"GRANT ALL PRIVILEGES ON DATABASE kasadara TO postgres;\\""

# ===== Configure pg_hba.conf for password authentication =====
PG_HBA=$(find /var/lib/pgsql -name pg_hba.conf | head -n 1)
sed -i 's/^\(local\s\+all\s\+all\s\+\)peer/\1md5/' $PG_HBA || true
sed -i 's/^\(local\s\+all\s\+all\s\+\)ident/\1md5/
