#!/bin/bash

set -xe
exec > >(tee /var/log/deployment.log | logger -t deployment-script) 2>&1

# ===== Load environment variables (GitHub token, etc.) =====
if [ -f /opt/kasadra_backened_repo/learning_app/.env ]; then
    export $(grep -v '^#' /opt/kasadra_backened_repo/learning_app/.env | xargs)
fi


# ===== Update system and install dependencies =====
yum update -y
yum install -y git postgresql postgresql-server postgresql-contrib python3 python3-pip -y

# ===== Initialize PostgreSQL =====
postgresql-setup --initdb || true
systemctl enable postgresql
systemctl start postgresql
sleep 5

# ===== Configure PostgreSQL =====
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'admin12';"
sudo -u postgres psql -c "CREATE DATABASE kasadara;" || true
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE kasadara TO postgres;"

# ===== Configure pg_hba.conf for password authentication =====
PG_HBA="/var/lib/pgsql/data/pg_hba.conf"
sed -i 's/^\(local\s\+all\s\+all\s\+\)peer/\1md5/' $PG_HBA || true
sed -i 's/^\(local\s\+all\s\+all\s\+\)ident/\1md5/' $PG_HBA || true
sed -i 's/^\(host\s\+all\s\+all\s\+127.0.0.1\/32\s\+\)ident/\1md5/' $PG_HBA || true
sed -i 's/^\(host\s\+all\s\+all\s\+::1\/128\s\+\)ident/\1md5/' $PG_HBA || true
systemctl restart postgresql

# ===== Ensure application user exists =====
id -u sajin_pub &>/dev/null || useradd -m sajin_pub

# ===== Clone FastAPI repository =====
APP_ROOT=/opt/kasadra_backened_repo
APP_DIR=$APP_ROOT/learning_app
VENV_DIR=$APP_ROOT/venv

cd /opt
if [ ! -d "$APP_ROOT" ]; then
    git clone https://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:x-oauth-basic@github.com/SoftwareStackSolutions/kasadra_backened_repo.git "$APP_ROOT"
fi

cd "$APP_ROOT"
git fetch origin
git checkout feature/python 

# ===== Fix ownership =====
chown -R sajin_pub:sajin_pub "$APP_ROOT"
chmod -R 755 "$APP_ROOT"

# ===== Create virtual environment and install dependencies =====
if [ ! -d "$VENV_DIR" ]; then
    python3 -m venv "$VENV_DIR"
fi

source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install --no-cache-dir -r "$APP_DIR/requirements.txt"
deactivate

# ===== Patch Python 3.10+ syntax if necessary =====
find "$APP_DIR" -name "*.py" | while read file; do
    grep -q "from typing import Optional" "$file" || sed -i '1i from typing import Optional' "$file"
    sed -i -E 's/([a-zA-Z_][a-zA-Z0-9_]*)\s*:\s*([a-zA-Z0-9_]+)\s*\|\s*None/\1: Optional[\2]/g' "$file"
done

# ===== Create systemd service for FastAPI =====
tee /etc/systemd/system/fastapi.service > /dev/null <<EOF
[Unit]
Description=FastAPI App
After=network.target postgresql.service

[Service]
User=sajin_pub
Group=sajin_pub
WorkingDirectory=/opt/kasadra_backened_repo/learning_app
ExecStart=/opt/kasadra_backened_repo/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
Environment="PATH=/opt/kasadra_backened_repo/venv/bin:/usr/local/bin:/usr/bin"

[Install]
WantedBy=multi-user.target
EOF

# ===== Reload systemd and start service =====
systemctl daemon-reload
systemctl enable fastapi
systemctl restart fastapi

# ===== Check status =====
systemctl status fastapi --no-pager -l
