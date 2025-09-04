#!/bin/bash
set -x
exec > >(tee /var/log/startup.log | logger -t startup-script) 2>&1

# ===== Install dependencies =====
yum makecache
yum install -y python3 python3-pip git postgresql13 postgresql13-server postgresql13-contrib

# ===== Initialize PostgreSQL =====
if [ ! -d "/var/lib/pgsql/13/data/base" ]; then
  /usr/pgsql-13/bin/postgresql-13-setup initdb
fi

systemctl enable postgresql-13
systemctl start postgresql-13
sleep 5

# ===== Configure PostgreSQL DB =====
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'admin12';" || true
sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname = 'kasadara';" | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE kasadara;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE kasadara TO postgres;" || true

# ===== Configure pg_hba.conf for password authentication =====
PG_HBA="/var/lib/pgsql/13/data/pg_hba.conf"
if [ -f "$PG_HBA" ]; then
  sed -i 's/^\(local\s\+all\s\+all\s\+\)peer/\1md5/' $PG_HBA || true
  sed -i 's/^\(local\s\+all\s\+all\s\+\)ident/\1md5/' $PG_HBA || true
  sed -i 's/^\(host\s\+all\s\+all\s\+127.0.0.1\/32\s\+\)ident/\1md5/' $PG_HBA || true
  sed -i 's/^\(host\s\+all\s\+all\s\+::1\/128\s\+\)ident/\1md5/' $PG_HBA || true
  systemctl restart postgresql-13
fi

# ===== Clone FastAPI repo =====
cd /opt
if [ ! -d "test_application" ]; then
  git clone https://github.com/digidense/test_application.git
fi

cd test_application
git fetch origin
git checkout feature/1

# ===== Install Python dependencies =====
cd /opt/test_application/learning_app
pip3 install --no-cache-dir -r requirements.txt

# ===== Ensure app user exists =====
id -u sajin_pub &>/dev/null || useradd -m sajin_pub

# ===== Create systemd service =====
tee /etc/systemd/system/fastapi.service > /dev/null <<EOF
[Unit]
Description=FastAPI App
After=network.target postgresql-13.service

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
systemctl daemon-reload
systemctl enable fastapi
systemctl start fastapi
