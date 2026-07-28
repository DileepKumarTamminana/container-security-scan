# 📦 Container Security Scanning

[![Container Security Scan](https://github.com/DileepKumarTamminana/container-security-scan/actions/workflows/container-scan.yml/badge.svg)](https://github.com/DileepKumarTamminana/container-security-scan/actions/workflows/container-scan.yml)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Trivy](https://img.shields.io/badge/Trivy-1904DA?style=flat&logo=aquasecurity&logoColor=white)
![Dockle](https://img.shields.io/badge/Dockle-CIS%20Benchmark-orange?style=flat)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-2088FF?style=flat&logo=githubactions&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A hands-on portfolio project demonstrating **container image security scanning**
end-to-end: a deliberately insecure Dockerfile vs. a hardened one, scanned
with **Trivy** (vulnerabilities) and **Dockle** (Dockerfile/CIS best
practices), wired into a **GitHub Actions** pipeline that scans every image
and reports findings to the **Security** tab (hard gating is one flag away).

## Overview

This repo ships a trivial Flask "hello/health" app (`app/app.py`) — the app
itself isn't the point. It exists so there is something realistic to build
into a container image and scan. The interesting part is the pair of
Dockerfiles and the CI gate around them:

| File                 | Purpose                                             |
| -------------------- | ---------------------------------------------------- |
| `Dockerfile.insecure` | Intentionally vulnerable "before" image (for demo/comparison only, not built in CI) |
| `Dockerfile`          | Hardened "after" image — the one CI actually builds and scans |

## What this demonstrates

- **Image vulnerability scanning with Trivy** — scans OS packages and
  application dependencies in the built image for known CVEs, filtered to
  `HIGH,CRITICAL` severity.
- **Dockerfile / image best-practice linting with Dockle** — checks the
  image against CIS Docker Benchmark-style rules (non-root user, HEALTHCHECK
  present, no secrets baked into layers, minimal packages, etc.).
- **Security-tab reporting (gating optional)** — both scanners run in
  report-only mode (`exit-code: 0`) so the pipeline stays green, while Trivy
  findings upload as SARIF to the Security tab. Set `exit-code` to `1` to turn
  this into a hard gate so new HIGH/CRITICAL vulnerabilities or FATAL
  Dockerfile issues cannot merge silently. A weekly scheduled run also
  re-scans the pinned base image for newly disclosed CVEs even when no code
  has changed.

## Before / after: insecure vs. hardened

| Issue                                   | `Dockerfile.insecure` (before)                          | `Dockerfile` (after / hardened)                                   |
| ---------------------------------------- | -------------------------------------------------------- | -------------------------------------------------------------------- |
| Base image tag                           | `python:latest` (floating, non-reproducible, full-fat)    | `python:3.12-slim` (pinned version, minimal package surface)         |
| Runs as                                  | root (no `USER` instruction)                              | dedicated unprivileged `appuser` (UID 10001) via `USER`               |
| `HEALTHCHECK`                            | none — orchestrator can't detect a hung process           | defined, hits `/healthz` on an interval with retries                 |
| Secrets                                  | fake API key baked in via `ENV` (visible in image history) | none baked in; secrets are injected at runtime, never in the image    |
| `COPY` scope                             | `COPY . .` — entire build context, incl. `.git`, configs   | copies only `requirements.txt` and `app.py` — nothing else            |
| Package installs                         | `apt-get install` with no `--no-install-recommends`, cache left behind, extra tools (`curl`, `vim`, `gcc`) | no OS packages added beyond the slim base; `pip install --no-cache-dir` |
| Runtime server                           | Flask dev server (`python app.py`) — single-threaded, insecure for prod | `gunicorn` production WSGI server, bound to the documented port      |
| Working directory                        | none set (builds into `/`)                                | dedicated `/app` `WORKDIR`                                           |
| File ownership                           | everything owned by root                                  | app files `chown`'d to the non-root user before dropping privileges  |

## How to run the scans locally

Prerequisites: [Docker](https://docs.docker.com/get-docker/),
[Trivy](https://aquasecurity.github.io/trivy/latest/getting-started/installation/),
and [Dockle](https://github.com/goodwithtech/dockle#installation) installed.

```bash
# 1. Build the hardened image
docker build -f Dockerfile -t container-security-scan:hardened .

# 2. (Optional) Build the intentionally insecure image, for comparison
docker build -f Dockerfile.insecure -t container-security-scan:insecure .

# 3. Scan the hardened image with Trivy (fails with exit code 1 on HIGH/CRITICAL)
trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 container-security-scan:hardened

# 4. Compare against the insecure image (expect many more findings)
trivy image --severity HIGH,CRITICAL container-security-scan:insecure

# 5. Lint the hardened image with Dockle
dockle --exit-code 1 --exit-level fatal container-security-scan:hardened

# 6. Compare against the insecure image (expect FATAL/WARN hits for root user,
#    missing HEALTHCHECK, baked-in secret, etc.)
dockle container-security-scan:insecure
```

Dockle can also be run without a local install, via its Docker image:

```bash
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  goodwithtech/dockle:latest --exit-code 1 --exit-level fatal container-security-scan:hardened
```

## CI pipeline

`.github/workflows/container-scan.yml` runs on every push/PR to `main`, on a
weekly schedule, and on manual dispatch. It:

1. Builds the **hardened** `Dockerfile` image.
2. Runs `aquasecurity/trivy-action` against it with `severity: HIGH,CRITICAL`
   and `exit-code: 0` (report-only, keeps CI green — set to `1` to fail the job on any matching vulnerability).
3. Uploads a Trivy SARIF report to the GitHub Security tab (Code Scanning
   alerts) for visibility even when the job passes.
4. Runs Dockle (via the `goodwithtech/dockle` image) against the same image
   in report-only mode; set `--exit-code 1` to fail on any `FATAL`-level
   Dockerfile best-practice violation.

## Tools

- 🐳 **Docker** — image build
- 🛡️ **[Trivy](https://github.com/aquasecurity/trivy)** — vulnerability scanner (OS packages + app dependencies)
- 📋 **[Dockle](https://github.com/goodwithtech/dockle)** — Dockerfile/image best-practice & CIS benchmark linter
- ⚙️ **GitHub Actions** — CI pipeline that scans images and reports findings to the Security tab

## Author

**Dileep Kumar Tamminana**
GitHub: [@DileepKumarTamminana](https://github.com/DileepKumarTamminana)

## License

Released under the [MIT License](./LICENSE).
