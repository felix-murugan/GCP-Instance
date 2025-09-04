#!/bin/bash
set -e

# ===== Update & install dependencies =====
sudo yum update -y
sudo yum install -y python3 python3-pip git

# ===== Clone FastAPI repo =====
cd /opt
if [ ! -d "test_application" ]; then
    git clone https://github.com/digidense/test_application.git
fi

cd test_application

# ===== Switch to feature branch =====
git fetch origin
git checkout feature/1

# ===== Install Python dependencies =====
if [ -f requirements.txt ]; then
    pip3 install --no-cache-dir -r requirements.txt
else
    pip3 install --no-cache-dir fastapi uvicorn[standard] gunicorn
fi

# ===== Create systemd service =====
sudo tee /etc/systemd/system/fastapi.service > /dev/null <<EOF
[Unit]
Description=FastAPI App
After=network.target

[Service]
User=sajin_pub
Group=sajin_pub
WorkingDirectory=/opt/test_application/learning_app
ExecStart=/usr/bin/python3 -m gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app -b 0.0.0.0:8000
Restart=always
Environment="PATH=/usr/local/bin:/usr/bin"

[Install]
WantedBy=multi-user.target
EOF

# ===== Reload and start service =====
sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl enable fastapi
sudo systemctl restart fastapi

# ===== Show logs =====
sudo systemctl status fastapi --no-pager -l


#######################################
## Owner anisha
#####################################
# #!/bin/bash
# set -e

# # Update & install dependencies
# apt-get update -y
# apt-get install -y python3 python3-pip git

# # Clone your FastAPI repo
# cd /opt
# git clone https://github.com/digidense/test_application.git
# cd learning_app

# # Install dependencies
# if [ -f requirements.txt ]; then
#     pip3 install -r requirements.txt
# else
#     pip3 install fastapi uvicorn[standard] gunicorn
# fi

# # Create systemd service for FastAPI
# cat <<EOF > /etc/systemd/system/fastapi.service
# [Unit]
# Description=FastAPI App
# After=network.target

# [Service]
# User=root
# WorkingDirectory=learning_app
# ExecStart=/usr/bin/gunicorn -w 4 -k uvicorn.workers.UvicornWorker <your_python_file_without_.py>:app -b 0.0.0.0:80
# Restart=always

# [Install]
# WantedBy=multi-user.target
# EOF

# # Start service
# systemctl daemon-reload
# systemctl enable fastapi
# systemctl start fastapi
