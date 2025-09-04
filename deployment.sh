#!/bin/bash
set -e

# ===== Update & install dependencies =====
sudo yum update -y
sudo yum install -y python3 python3-pip git postgresql postgresql-server postgresql-contrib -y

# ===== Initialize PostgreSQL =====
sudo postgresql-setup initdb
sudo systemctl enable postgresql
sudo systemctl start postgresql

# ===== Configure PostgreSQL DB =====
sudo -u postgres psql <<EOF
ALTER USER postgres WITH PASSWORD 'admin12';
CREATE DATABASE kasadara;
GRANT ALL PRIVILEGES ON DATABASE kasadara TO postgres;
EOF

# ===== Configure pg_hba.conf for password authentication =====
PG_HBA="/var/lib/pgsql/data/pg_hba.conf"
sudo sed -i 's/^\(local\s\+all\s\+all\s\+\)peer/\1md5/' $PG_HBA || true
sudo sed -i 's/^\(local\s\+all\s\+all\s\+\)ident/\1md5/' $PG_HBA || true
sudo sed -i 's/^\(host\s\+all\s\+all\s\+127.0.0.1\/32\s\+\)ident/\1md5/' $PG_HBA || true
sudo sed -i 's/^\(host\s\+all\s\+all\s\+::1\/128\s\+\)ident/\1md5/' $PG_HBA || true

sudo systemctl restart postgresql



# ===== Clone FastAPI repo =====
cd /opt
if [ ! -d "test_application" ]; then
    git clone https://github.com/digidense/test_application.git
fi

cd test_application

# ===== Switch to feature branch =====
git fetch origin
git checkout feature/1   # <-- replace with your branch

# ===== Install Python dependencies =====
cd /opt/test_application/learning_app
pip3 install --no-cache-dir -r requirements.txt

# ===== Create systemd service =====
sudo tee /etc/systemd/system/fastapi.service > /dev/null <<EOF
[Unit]
Description=FastAPI App
After=network.target postgresql.service

[Service]
User=sajin_pub
Group=sajin_pub
WorkingDirectory=/opt/test_application/learning_app
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
Environment="PATH=/usr/local/bin:/usr/bin"

[Install]
WantedBy=multi-user.target
EOF

# ===== Reload and start FastAPI service =====
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable fastapi
sudo systemctl restart fastapi

# ===== Show FastAPI status =====
sudo systemctl status fastapi --no-pager -l
