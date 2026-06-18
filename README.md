# Atlas Agent — Railway Template

Deploy [Atlas Agent](https://github.com/matlee0409/atlas) on [Railway](https://railway.app) with a web-based admin dashboard for configuration, gateway management, and user pairing.

> Atlas Agent is a whitelabelled autonomous AI agent forked from [Hermes Agent](https://github.com/NousResearch/hermes-agent) by Nous Research. It lives on your server, connects to your messaging channels (Telegram, Discord, Slack, etc.), and gets more capable the longer it runs.

## Features

- **Admin Dashboard** — dark-themed UI to configure providers, channels, tools, and manage the gateway
- **One-Page Setup** — provider dropdown, checkbox-based channel/tool toggles — no config files to edit
- **Gateway Management** — start, stop, restart the Atlas gateway from the browser
- **Live Status** — stat cards for gateway state, uptime, model, and pending pairing requests
- **Live Logs** — streaming gateway log viewer
- **User Pairing** — approve or deny users who message your bot, revoke access anytime
- **Basic Auth** — password-protected admin panel
- **Reset Config** — one-click reset to start fresh

## Getting Started

The easiest way to get started:

### 1. Get an LLM Provider Key (free)

1. Register for free at [OpenRouter](https://openrouter.ai/)
2. Create an API key from your [OpenRouter dashboard](https://openrouter.ai/keys)

### 2. Deploy on Railway

1. Click the Deploy button above
2. Set `ADMIN_PASSWORD` to a secure password
3. Attach a Railway volume at `/data` for persistent storage
4. The app starts on the port Railway assigns via `$PORT`

### 3. Configure

1. Open the app URL — you'll be redirected to the Setup Wizard
2. Log in with username `admin` and your `ADMIN_PASSWORD`
3. Enter your OpenRouter API key and select a model (e.g. `openai/gpt-4o-mini`)
4. Optionally connect a messaging channel (Telegram is easiest — just paste your bot token)
5. Click **Save & Start** — your Atlas Agent is now live!

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `ADMIN_PASSWORD` | Yes | Password for the admin panel |
| `ADMIN_USERNAME` | No | Username (default: `admin`) |
| `ATLAS_HOME` | No | Atlas data dir (default: `/data/.atlas` in Docker) |
| `PORT` | No | Server port (default: `8080`, set by Railway) |
| `ATLAS_DASHBOARD_PORT` | No | Native Atlas dashboard port (default: `9119`) |

LLM provider keys, messaging tokens, and tool keys are configured from the Setup Wizard UI and saved to `$ATLAS_HOME/.env`.

## Running Locally (Docker)

```bash
docker build -t atlas-agent .
docker run --rm -it \
  -p 8080:8080 \
  -e PORT=8080 \
  -e ADMIN_PASSWORD=changeme \
  -v atlas-data:/data \
  atlas-agent
```

Then open [http://localhost:8080](http://localhost:8080).

## Architecture

- `server.py` — Starlette app: admin UI, management API, reverse proxy to native Atlas dashboard, subprocess management
- `templates/index.html` — Alpine.js single-page admin dashboard
- `start.sh` — Docker entrypoint: initialises `$ATLAS_HOME` directories and starts `server.py`
- `Dockerfile` — Clones and installs Atlas Agent from `matlee0409/atlas`, pre-builds the React dashboard and TUI

## Upgrading Atlas

To upgrade the Atlas Agent version, update `ATLAS_REF` in the `Dockerfile` (branch name or commit SHA) and redeploy.
