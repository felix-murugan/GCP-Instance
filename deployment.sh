#!/bin/bash

# Exit immediately if a command fails
set -xe

# Safe logging: log to file + journald + serial (only if available)
if [ -w /dev/ttyS0 ]; then
  exec > >(tee -a /var/log/deployment.log | logger -t deployment-script | tee /dev/ttyS0) 2>&1
else
  exec > >(tee -a /var/log/deployment.log | logger -t deployment-script) 2>&1
fi

echo "===== [1/7] Updating system and installing dependencies ====="
yum -y update
yum install -y python3 python3-pip git postgresql postgresql-server postgresql-contrib

echo "===== [2/7] Initializing and starting PostgreSQL ====="
/usr/bin/postgresql-setup --initdb || true
systemctl enable postgresql
systemctl start postgresql

echo "===== [3/7] Configuring PostgreSQL user and database ====="
sudo -u postgres psql <<EOF
ALTER USER postgres WITH PASSWORD 'admin12';
CREATE DATABASE kasadara;
GRANT ALL PRIVILEGES ON DATABASE kasadara TO postgres;
EOF

echo "===== [4/7] Updating pg_hba.conf to allow md5 auth ====="
PG_HBA=$(find /var/lib/pgsql -name pg_hba.conf | head -n 1)
if [ -f "$PG_HBA" ]; then
  sed -i 's/^\(local\s\+all\s\+all\s\+\)peer/\1md5/' $PG_HBA || true
  sed -i 's/^\(local\s\+all\s\+all\s\+\)ident/\1md5/' $PG_HBA || true
  sed -i 's/^\(host\s\+all\s\+all\s\+127.0.0.1\/32\s\+\)ident/\1md5/' $PG_HBA || true
  sed -i 's/^\(host\s\+all\s\+all\s\+::1\/128\s\+\)ident/\1md5/' $PG_HBA || true
  systemctl restart postgresql
else
  echo "⚠️ pg_hba.conf not found, skipping edits."
fi

echo "===== [5/7] Creating application user ====="
if ! id "sajin_pub" &>/dev/null; then
  useradd -m sajin_pub
fi

echo "===== [6/7] Cloning FastAPI repository ====="
cd /opt
if [ ! -d "test_application" ]; then
  git clone https://github.com/digidense/test_application.git
fi

cd test_application
git fetch origin
git checkout feature/1

echo "===== [7/7] Installing Python dependencies ====="
cd /opt/test_application/learning_app
pip3 install --no-cache-dir -r requirements.txt

echo "===== Creating FastAPI systemd service ====="
cat >/etc/systemd/system/fastapi.service <<EOF
[Unit]
Description=FastAPI App
After=network.target postgresql.service

[Service]
User=sajin_pub
Group=sajin_pub
WorkingDirectory=/opt/test_application
ExecStart=/usr/bin/python3 -m uvicorn learning_app.main:app --host 0.0.0.0 --port 8000
Restart=always
Environment="PATH=/usr/local/bin:/usr/bin"

[Install]
WantedBy=multi-user.target
EOF


echo "===== Enabling and starting FastAPI service ====="
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable fastapi
systemctl restart fastapi

echo "===== Deployment complete! ====="
systemctl status fastapi --no-pager -l || true
