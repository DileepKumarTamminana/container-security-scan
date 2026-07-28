# ▶️ How to Run — Container Security Scanning

Contrasts an **insecure** Dockerfile against a **hardened** one, scanned with Trivy (vulnerabilities) and Dockle (best practices).

## Prerequisites
- Docker
- For local scans: [Trivy](https://trivy.dev) and [Dockle](https://github.com/goodwithtech/dockle)
  (both can also be run via Docker — see below)

## Build & run the hardened image
```bash
docker build -t container-demo .
docker run -p 8080:8080 container-demo
```
Open **http://localhost:8080** — health check at `/healthz`.
The container runs via **gunicorn** as a **non-root** user with a HEALTHCHECK.

## Scan locally — compare insecure vs hardened
```bash
# Hardened image
docker build -t app-secure -f Dockerfile .
trivy image app-secure
dockle app-secure

# Insecure image (expect MORE findings + FATAL best-practice warnings)
docker build -t app-insecure -f Dockerfile.insecure .
trivy image app-insecure
dockle app-insecure
```

### Running the scanners via Docker (no local install)
```bash
# Trivy
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image app-secure
# Dockle
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock goodwithtech/dockle app-secure
```

## What the hardened Dockerfile fixes
Pinned slim base image · non-root user · minimal COPY · no baked-in secrets · cleaned apt layers · HEALTHCHECK · gunicorn instead of the Flask dev server.

## CI
`.github/workflows/container-scan.yml` builds the hardened image, runs **Trivy** (fails on HIGH/CRITICAL, uploads SARIF to the Security tab) and **Dockle**, on every push/PR and weekly.
