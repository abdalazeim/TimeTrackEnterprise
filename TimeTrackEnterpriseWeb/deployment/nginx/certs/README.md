# TLS certificates

Put the certificate pair used by `deployment/nginx/timetrack.conf` here:

| File | Content |
| --- | --- |
| `fullchain.pem` | server certificate followed by the intermediate chain |
| `privkey.pem` | matching private key (unencrypted, mode `600`) |

The folder is mounted read-only at `/etc/nginx/certs` by
`deployment/docker/docker-compose.yml`. Private keys and certificates are
ignored by git (`.gitignore`: `*.pem`, `*.key`).

## Quick test certificate

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
  -keyout deployment/nginx/certs/privkey.pem \
  -out deployment/nginx/certs/fullchain.pem \
  -subj "/CN=attendance.local" \
  -addext "subjectAltName=DNS:attendance.local,IP:127.0.0.1"
```

Browsers warn about the self-signed certificate; accept it for a local test.

## Production

Use a certificate issued by a public CA (for example Let's Encrypt through
`certbot` with the `webroot` at `/var/www/certbot`) or by your organisation's
internal CA, then reload Nginx:

```bash
docker compose exec nginx nginx -s reload
```
