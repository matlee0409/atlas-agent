#!/bin/bash
set -e

# Mirror dashboard-ref-only's startup: create every directory atlas expects
# and seed a default config.yaml if the volume is empty. Without these,
# `atlas dashboard` endpoints that hit logs/, sessions/, cron/, etc. can fail
# with opaque errors even though no auth is actually involved.
mkdir -p /data/.atlas/cron /data/.atlas/sessions /data/.atlas/logs \
         /data/.atlas/memories /data/.atlas/skills /data/.atlas/pairing \
         /data/.atlas/hooks /data/.atlas/image_cache /data/.atlas/audio_cache \
         /data/.atlas/workspace /data/.atlas/skins /data/.atlas/plans \
         /data/.atlas/home

# Stamp the install method as "docker" so atlas treats this as an immutable
# container image, not a pip checkout. atlas's detect_install_method() reads
# $ATLAS_HOME/.install_method FIRST (before any .git / pip fallback). Without
# this stamp the template falls through to "pip" — because the Dockerfile strips
# /opt/atlas-agent/.git — and the dashboard's "Update Atlas" button then runs
# a real `atlas update` (PyPI pip-upgrade) INSIDE the running container. That
# upgrade is ephemeral (reverts on the next redeploy) and can desync the Python
# package from the image's pre-built web_dist/ui-tui bundles. Stamping "docker"
# makes that button correctly refuse with "pull a fresh image / redeploy", which
# matches the real upgrade path here (bump ATLAS_REF in Railway + redeploy).
# Written unconditionally each boot so it stays correct and self-heals.
printf 'docker\n' > /data/.atlas/.install_method

if [ ! -f /data/.atlas/config.yaml ] && [ -f /opt/atlas-agent/cli-config.yaml.example ]; then
  cp /opt/atlas-agent/cli-config.yaml.example /data/.atlas/config.yaml
fi

[ ! -f /data/.atlas/.env ] && touch /data/.atlas/.env

# Bootstrap OAuth tokens from env var (e.g. xAI Grok SuperGrok).
# Set ATLAS_AUTH_JSON_BOOTSTRAP to the contents of a locally-generated
# ~/.atlas/auth.json. Written only once — subsequent token refreshes update
# the file in place on the persistent volume.
if [ ! -f /data/.atlas/auth.json ] && [ -n "${ATLAS_AUTH_JSON_BOOTSTRAP}" ]; then
  printf '%s' "${ATLAS_AUTH_JSON_BOOTSTRAP}" > /data/.atlas/auth.json
  chmod 600 /data/.atlas/auth.json
fi

# Clear any stale gateway PID file left over from the previous container.
# `atlas gateway` writes /data/.atlas/gateway.pid on start but does not
# remove it on SIGTERM. Since /data is a persistent volume, the file
# survives container restarts and causes every subsequent boot to exit with
# "ERROR gateway.run: PID file race lost to another gateway instance".
# No atlas process can be running at this point (we're pre-exec in a fresh
# container), so removing the file unconditionally is safe.
rm -f /data/.atlas/gateway.pid

exec python /app/server.py
