#!/usr/bin/env python3
"""Render a host Nginx vhost from the effective installation profile."""
import argparse
import json
from pathlib import Path
import subprocess
from urllib.parse import urlsplit
p = argparse.ArgumentParser()
p.add_argument('--env-file', required=True)
p.add_argument('--acme-root', required=True)
p.add_argument('--certificate-dir')
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
profile = Path(a.env_file).resolve()
subprocess.run(['sh',str(root/'scripts/preflight.sh'),'--env-file',str(profile),'--config-only'],check=True,stdout=subprocess.DEVNULL)
result = subprocess.run(['docker','compose','--project-directory',str(root),'-f',str(root/'compose.yaml'),'--env-file',str(profile),'--env-file',str(root/'releases/release.env'),'config','--format','json'],check=True,capture_output=True)
model = json.loads(result.stdout)
host = urlsplit(model['services']['app']['environment']['MOODLE_WWWROOT']).hostname
port = model['services']['web']['ports'][0]['published']
limit = model['services']['web']['environment']['MOODLE_MAX_REQUEST_MB']
timeout = model['services']['web']['environment']['MOODLE_FASTCGI_READ_TIMEOUT_SECONDS']
for path in [a.acme_root] + ([a.certificate_dir] if a.certificate_dir else []):
    if not path.startswith('/') or any(c not in 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_./-' for c in path):
        p.error('Paths must be absolute with only letters, digits, /, _, . and -')
print(f"""server {{
    listen 80;
    listen [::]:80;
    server_name {host};
    location ^~ /.well-known/acme-challenge/ {{
        root {a.acme_root};
        default_type text/plain;
        try_files $uri =404;
    }}
    location / {{ return 301 https://{host}$request_uri; }}
}}""")
if a.certificate_dir:
    print(f"""server {{
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name {host};
    server_tokens off;
    ssl_certificate {a.certificate_dir}/fullchain.pem;
    ssl_certificate_key {a.certificate_dir}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_session_tickets off;
    client_max_body_size {limit}M;
    location / {{
        proxy_pass http://127.0.0.1:{port};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout {timeout}s;
    }}
}}""")
