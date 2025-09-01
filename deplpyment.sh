metadata_startup_script = <<-EOT
#!/bin/bash
set -e
apt-get update -y
apt-get install -y python3 python3-pip git
cd /opt
git clone https://github.com/digidense/test_application.git
cd learning_app
if [ -f requirements.txt ]; then
    pip3 install -r requirements.txt
else
    pip3 install fastapi uvicorn[standard] gunicorn
fi
cat <<EOF > /etc/systemd/system/fastapi.service
[Unit]
Description=FastAPI App
After=network.target

[Service]
User=root
WorkingDirectory=learning_app
ExecStart=/usr/bin/gunicorn -w 4 -k uvicorn.workers.UvicornWorker main:app -b 0.0.0.0:80
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable fastapi
systemctl start fastapi
EOT
