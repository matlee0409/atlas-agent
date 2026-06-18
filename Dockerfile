FROM ghcr.io/astral-sh/uv:python3.12-bookworm-slim

# Which atlas revision to install. Accepts any git ref the upstream
# repo publishes — a branch name (`main`) for latest.
#
# To bump: check https://github.com/matlee0409/atlas for the
# newest commit/tag and update the default below.
ARG ATLAS_REF=main

# tini = tiny init that we run as PID 1. Without it, atlas's grandchild
# processes (MCP stdio servers, git, bun, browser daemons spawned by tools)
# reparent to PID 1 when their parents exit and pile up as zombies. After
# weeks of uptime that exhausts the kernel's PID table → "fork: cannot
# allocate memory" and the container dies. tini reaps zombies in the
# background and forwards SIGTERM/SIGINT to our entrypoint so Railway's
# stop signal still triggers our graceful shutdown. Standard container init
# (same as Docker's `--init` flag and Kubernetes' pause container).
#
# Node.js is required only at build time to compile the Atlas React dashboard.
# We strip the source + apt lists afterwards to keep the image lean.
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl ca-certificates git tini && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    rm -rf /var/lib/apt/lists/*

# Install atlas-agent (provides the `atlas` CLI) and pre-build its React
# dashboard so `atlas dashboard` has nothing to build at runtime.
#
# messaging platforms, TTS, and other heavy backends are lazy-installed by
# atlas at first use. We pre-install the ones this template actually uses
# so first-message latency is instant.
# `vision` (Pillow) is a soft-dep that is NOT in [all] and is otherwise
# lazy-installed at first image use: without it atlas can't downscale an
# oversized image (>5 MB / >8000px), which then bakes into immutable history
# and bricks the session on Anthropic's non-retryable 400. We bake it in.
# When bumping ATLAS_REF, re-check atlas's pyproject.toml [all] and
# the extras below against the new release's pyproject.toml.
RUN git clone --depth 1 --branch ${ATLAS_REF} https://github.com/matlee0409/atlas.git /opt/atlas-agent && \
    cd /opt/atlas-agent && \
    uv pip install --system --no-cache -e ".[all,messaging,tts-premium,honcho,bedrock,anthropic,edge-tts,hindsight,vision]" && \
    cd /opt/atlas-agent/web && \
    npm install --silent && \
    npm run build && \
    cd /opt/atlas-agent/ui-tui && \
    npm install --silent --no-fund --no-audit --progress=false && \
    npm run build && \
    rm -rf /opt/atlas-agent/web /opt/atlas-agent/.git /root/.npm

# Why pre-build ui-tui (and why we don't delete it after):
# - The dashboard's embedded Chat tab spawns `node ui-tui/dist/entry.js`
#   on every WebSocket connect to /api/pty.
# - Without ATLAS_TUI_DIR, atlas's _make_tui_argv falls through to the
#   npm install + build path (since git-editable installs don't have the
#   bundled tui_dist/ that PyPI wheels include), adding 30-60s to the
#   first chat-open and blocking the asyncio event loop.
# - Pre-building at image time surfaces build failures here rather than
#   at user request time, and makes first-chat-open instant.
# - We keep ui-tui/ entirely (node_modules + dist + src) so ATLAS_TUI_DIR
#   can point at it (see below).

COPY requirements.txt /app/requirements.txt
RUN uv pip install --system --no-cache -r /app/requirements.txt

RUN mkdir -p /data/.atlas

COPY server.py /app/server.py
COPY templates/ /app/templates/
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

ENV HOME=/data
ENV ATLAS_HOME=/data/.atlas

# Points atlas at our pre-built TUI bundle. atlas's _make_tui_argv checks
# ATLAS_TUI_DIR first: if dist/entry.js exists there, it skips the npm
# install/build entirely. This is the official packager path (Nix uses it too)
# and avoids the 30-60s npm bootstrap that git-editable installs would otherwise
# trigger on first /chat connection.
ENV ATLAS_TUI_DIR=/opt/atlas-agent/ui-tui

# tini wraps start.sh so it runs as PID 1's child instead of as PID 1 itself.
# `-g` propagates signals to the whole process group so `docker stop` /
# Railway's SIGTERM cleanly terminates the entire tree, not just start.sh.
ENTRYPOINT ["/usr/bin/tini", "-g", "--"]
CMD ["/app/start.sh"]
