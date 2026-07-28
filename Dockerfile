# =============================================================================
# Dockerfile (hardened)
#
# This is the "after" image for the container-security-scan demo. Each
# instruction is commented with the specific hardening it applies, mirroring
# (and fixing) the anti-patterns called out in Dockerfile.insecure.
# =============================================================================

# HARDENING 1: Pin to a specific, minimal base image tag (not "latest").
# "slim" drastically reduces the package surface vs. the full Debian image,
# and pinning the exact version makes builds reproducible and scannable.
FROM python:3.12-slim AS base

# HARDENING 2: No secrets baked into the image. Configuration/secrets should
# be injected at runtime (env vars from a secrets manager, mounted files,
# orchestrator secrets, etc.) - never via ENV/ARG in the Dockerfile.

# HARDENING 3: Dedicated, non-root working directory for the app.
WORKDIR /app

# HARDENING 4: Create an unprivileged user/group up front so later steps can
# drop privileges before the app ever runs.
RUN groupadd --gid 10001 appgroup \
    && useradd --uid 10001 --gid appgroup --shell /usr/sbin/nologin --no-create-home appuser

# HARDENING 5: Copy only the dependency manifest first (better layer caching)
# and install with --no-cache-dir so pip's cache isn't left behind in the
# image. No compilers/dev tools are installed - the slim base plus wheels is
# enough for this app.
COPY app/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir --no-compile -r requirements.txt

# HARDENING 6: Copy only the application code that is actually needed at
# runtime (not the whole build context: no .git, no CI config, no tests).
COPY app/app.py ./app.py

# HARDENING 7: Ensure application files are owned by the non-root user, then
# drop from root to that user for everything from here on.
RUN chown -R appuser:appgroup /app
USER appuser

# HARDENING 8: Document the port the app actually listens on.
EXPOSE 8080

# HARDENING 9: HEALTHCHECK so the container runtime/orchestrator can detect
# a hung or unresponsive process and restart/replace it automatically.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2).status == 200 else 1)"

# HARDENING 10: Run with a production-grade WSGI server (gunicorn) rather
# than the Flask dev server, bound only to what's needed, as the non-root
# user set above.
RUN pip install --no-cache-dir --no-compile gunicorn==22.0.0
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "2", "app:app"]
