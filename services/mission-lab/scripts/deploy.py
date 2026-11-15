"""Deploy the isolated companion demo; never uploads provider secrets.
Requires CLOUDFLARE_ACCOUNT_ID and a scoped CLOUDFLARE_API_TOKEN.
"""
import json, os, pathlib, re, urllib.request, urllib.error, uuid
ROOT = pathlib.Path(__file__).resolve().parents[3]
ACCOUNT = os.environ['CLOUDFLARE_ACCOUNT_ID']
if not re.fullmatch(r'[0-9a-f]{32}', ACCOUNT):
    raise SystemExit('CLOUDFLARE_ACCOUNT_ID must be the 32-character account ID, not an email.')
NAME = 'komaku-mission-lab'
BASE = 'https://api.cloudflare.com/client/v4/accounts/' + ACCOUNT
HEADERS = {'Authorization': 'Bearer ' + os.environ['CLOUDFLARE_API_TOKEN']}
def call(path, method, body, content_type):
    req = urllib.request.Request(BASE + path, data=body, method=method, headers={**HEADERS, 'Content-Type': content_type})
    try:
        with urllib.request.urlopen(req, timeout=60) as response:
            return json.load(response)
    except urllib.error.HTTPError as exc:
        result = json.loads(exc.read())
        # Print codes/messages only; no request headers or secret values.
        print('Cloudflare HTTP', exc.code, [(e.get('code'), e.get('message')) for e in result.get('errors', [])])
        return {'success': False}
metadata = {'main_module': 'services/mission-lab/src/index.js', 'compatibility_date': '2026-11-15', 'keep_bindings': ['secret_text'], 'bindings': [{'name': 'COACH_LIMITER', 'type': 'ratelimit', 'namespace_id': '1001', 'simple': {'limit': 10, 'period': 60}}], 'observability': {'enabled': False}}
boundary = 'komaku-' + uuid.uuid4().hex
parts = []
def part(name, value, filename=None):
    disposition = 'Content-Disposition: form-data; name="' + name + '"'
    if filename: disposition += '; filename="' + filename + '"'
    parts.append(('--' + boundary + '\r\n' + disposition + '\r\nContent-Type: ' + ('application/javascript+module' if filename else 'application/json') + '\r\n\r\n').encode() + value + b'\r\n')
part('metadata', json.dumps(metadata).encode())
for name in ['services/mission-lab/src/index.js', 'services/mission-lab/src/coach.js', 'services/mission-lab/src/ui.js', 'services/mission-lab/src/data.js', 'services/nasa-context-worker/src/index.js']:
    part(name, (ROOT / name).read_bytes(), name)
payload = b''.join(parts) + ('--' + boundary + '--\r\n').encode()
result = call('/workers/scripts/' + NAME, 'PUT', payload, 'multipart/form-data; boundary=' + boundary)
if not result.get('success'): raise SystemExit('Worker upload failed.')
print('Worker uploaded:', NAME)
result = call('/workers/scripts/' + NAME + '/subdomain', 'POST', b'{"enabled":true}', 'application/json')
if not result.get('success'): raise SystemExit('Worker uploaded, but workers.dev activation is blocked. Complete account onboarding in the dashboard.')
req = urllib.request.Request(BASE + '/workers/subdomain', headers=HEADERS)
try:
    with urllib.request.urlopen(req, timeout=20) as response: subdomain = json.load(response)['result']['subdomain']
except urllib.error.HTTPError:
    raise SystemExit('Worker uploaded. Public URL unavailable until workers.dev account setup is completed in Cloudflare.')
print('Public URL: https://' + NAME + '.' + subdomain + '.workers.dev')
