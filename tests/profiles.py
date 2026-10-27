#!/usr/bin/env python3
"""Validate independent profiles without creating containers or exposing secrets."""
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASE = """MOODLE_WWWROOT=https://moodle.invalid
POSTGRES_PASSWORD=ProfileOnly9!NotAProductionPassword
MOODLE_ADMIN_PASSWORD=ProfileOnly8!NotAProductionPassword
MOODLE_ADMIN_EMAIL=admin@moodle.invalid
MOODLE_SITE_FULLNAME=Profile validation
MOODLE_SITE_SHORTNAME=Validation
"""

def preflight(profile, success=True, env=None):
    result = subprocess.run(['sh', str(ROOT/'scripts/preflight.sh'), '--env-file', str(profile), '--config-only'], cwd=ROOT, capture_output=True, env=env)
    assert (result.returncode == 0) == success, 'Unexpected preflight result (output withheld)'

with tempfile.TemporaryDirectory(prefix='moodle-profile-check-') as directory:
    models = []
    for name, port, zone in [('profile-check-a', 28081, 'UTC'), ('profile-check-b', 28082, 'America/Santiago')]:
        profile = Path(directory)/name
        profile.write_text(BASE.replace('https://moodle.invalid', f'https://{name}.invalid')+f'COMPOSE_PROJECT_NAME={name}\nMOODLE_HTTP_PORT={port}\nTZ={zone}\n')
        preflight(profile)
        result = subprocess.run(['docker','compose','--project-directory',str(ROOT),'-f',str(ROOT/'compose.yaml'),'--env-file',str(profile),'--env-file',str(ROOT/'releases/release.env'),'config','--format','json'], check=True, capture_output=True)
        model = json.loads(result.stdout)
        assert model['name'] == name
        publication = model['services']['web']['ports'][0]
        assert publication['host_ip'] == '127.0.0.1' and str(publication['published']) == str(port)
        for service in ['web','app','cron','db']:
            assert model['services'][service]['environment']['TZ'] == zone
        assert f'timezone={zone}' in model['services']['db']['command']
        rendered = subprocess.run(['python3',str(ROOT/'scripts/render-proxy.py'),'--env-file',str(profile),'--acme-root','/var/www/letsencrypt','--certificate-dir','/etc/letsencrypt/live/profile-check'], check=True, capture_output=True).stdout.decode()
        assert f'server_name {name}.invalid;' in rendered
        assert f'proxy_pass http://127.0.0.1:{port};' in rendered
        models.append(model)
    for kind in ['volumes', 'networks']:
        identities = [{item['name'] for item in m[kind].values()} for m in models]
        assert identities[0].isdisjoint(identities[1])
    for suffix in ['MOODLE_HTTP_PORT=0\n', 'MOODLE_HTTP_BIND=0.0.0.0\n', 'TZ=Missing/Timezone\n']:
        profile.write_text(BASE+suffix)
        preflight(profile, False)
    profile.write_text(BASE.replace('POSTGRES_PASSWORD=ProfileOnly9!NotAProductionPassword\n',''))
    preflight(profile, False)
    profile.write_text(BASE)
    preflight(profile, False, dict(os.environ, TZ='UTC'))
print('Two isolated profiles, timezone consumers and five rejection cases passed; no resources created.')
