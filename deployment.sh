#!/bin/bash
set -xe
exec > >(tee /var/log/startup.log|logger -t startup-script) 2>&1

# ===== Update & install dependencies =====
yum update -y
yum install -y python3 python3-pip git postgresql postgresql-server postgresql-contrib

# ===== Initialize PostgreSQL =====
postgresql-setup --initdb
systemctl enable postgresql
systemctl start postgresql
sleep 5

# ===== Configure PostgreSQL DB =====
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'admin12';"
sudo -u postgres psql -c "CREATE DATABASE kasadara;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE kasadara TO postgres;"

# ===== Configure pg_hba.conf for password authentication =====
PG_HBA="/var/lib/pgsql/data/pg_hba.conf"
sed -i 's/^\(local\s\+all\s\+all\s\+\)peer/\1md5/' $PG_HBA || true
sed -i 's/^\(local\s\+all\s\+all\s\+\)ident/\1md5/' $PG_HBA || true
sed -i 's/^\(host\s\+all\s\+all\s\+127.0.0.1\/32\s\+\)ident/\1md5/' $PG_HBA || true
sed -i 's/^\(host\s\+all\s\+all\s\+::1\/128\s\+\)ident/\1md5/' $PG_HBA || true
systemctl restart postgresql

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
systemctl daemon-reload
systemctl enable fastapi
systemctl start fastapi
