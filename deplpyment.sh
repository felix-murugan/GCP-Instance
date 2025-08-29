#!/bin/bash
set -e

# Update & install dependencies
apt-get update -y
apt-get install -y python3 python3-pip git

# Clone your FastAPI repo
cd /opt
git clone https://github.com/digidense/test_application.git
cd learning_app

# Install dependencies
if [ -f requirements.txt ]; then
    pip3 install -r requirements.txt
else
    pip3 install fastapi uvicorn[standard] gunicorn
fi

# Create systemd service for FastAPI
cat <<EOF > /etc/systemd/system/fastapi.service
[Unit]
Description=FastAPI App
After=network.target

[Service]
User=root
WorkingDirectory=learning_app
ExecStart=/usr/bin/gunicorn -w 4 -k uvicorn.workers.UvicornWorker <your_python_file_without_.py>:app -b 0.0.0.0:80
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start service
systemctl daemon-reload
systemctl enable fastapi
systemctl start fastapi
