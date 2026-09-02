# AGENTS.md — Notes for AI agents working on this repository

Operational knowledge for working on this NixOS configuration. Read this before
making changes, deploying, or diagnosing issues.

> ## 🚨🚨🚨 MANDATORY: confirm every switch — do not skip this 🚨🚨🚨
>
> Every single time you run `nixos-rebuild switch` (or `boot`) on this host, **you
> MUST run `sudo nixos-confirm` immediately afterwards** — even if the switch
> printed errors, even if you think nothing changed, even if you only touched one
> file. There is a 5-minute auto-rollback timer that will silently revert the
> whole deployment if you forget. Make it the very next command after every
> switch, before anything else (tests, checks, further edits). If a switch fails
> part-way, re-run the whole switch and then confirm — never leave a generation
> unconfirmed.

## ⚠️ CRITICAL: Automatic rollbacks

`system.autoRollback.enable = true` is set on `grafton-router`. After **any**
`nixos-rebuild switch` (or `boot`), a timer starts that auto-rolls-back to the
last known-good generation after **5 minutes** unless the new generation is
confirmed.

**ALWAYS run immediately after deploying — non-negotiable, no exceptions:**

```bash
sudo nixos-confirm
```

This marks the current generation as good and stops `auto-rollback.service` /
`auto-rollback.timer`. (Rollback logic comes from the `nixos-utils` flake input.)

`nixos-confirm` requires root — run it with `sudo`.

## Deployment workflow

We are **on the production machine itself** (`grafton-router`); the repo lives
at `/home/cjdell/nixos-config` and is a git flake.

```bash
cd /home/cjdell/nixos-config

# Validate first (no system changes):
sudo nixos-rebuild build --flake .

# Deploy:
./scripts/switch.sh          # sudo nixos-rebuild switch --flake .
./scripts/boot.sh            # sudo nixos-rebuild boot --flake .

# Always confirm afterwards (see above):
sudo nixos-confirm
```

### Gotchas

- **New/untracked files are invisible to the flake build.** If you add a new
  `.nix` file (e.g. a service) you must `git add` it before `nixos-rebuild`
  will see it, or the build fails with:
  `Path 'hosts/...' in the repository is not tracked by Git.`
- Adding a service = create `hosts/grafton-router/services/<name>.nix` **and**
  add an import to `hosts/grafton-router/services/default.nix` **and** `git add`
  both.
- This host uses `nixpkgs` from `nixos-26.05` (locked in `flake.lock`). A
  dirty git tree (uncommitted changes) is normal — the user deploys from the
  working tree.
- Format Nix files with `nixfmt` (installed on the system).
- **Path flake inputs are pinned by `narHash` in `flake.lock`.** Editing the
  `nixos-utils` working tree is invisible to this flake's build until you run
  `nix flake lock --update-input nixos-utils`. ⚠️ `flake.nix` currently points
  `nixos-utils` at a **temporary** `path:/home/cjdell/Projects/nixos-utils`
  input; once those changes are committed + pushed, restore it to
  `github:cjdell/nixos-utils` and re-lock.
- **`list-generations`: "booted ❌" right after a `switch` is normal** —
  `/run/booted-system` only changes on reboot; the switched system is the
  active one.
- **`sudo` strips environment variables** — use `sudo env VAR=val cmd`.
- **`curl -i` Location header lines end in CRLF.** Feeding a captured URL into
  `curl` without stripping the `\r` fails with "Malformed input to a URL
  function" — use `curl -w '%{redirect_url}'` instead.
- No `python3`/`node`/`openssl`/`websocat` on PATH — but **`python3` and
  `openssl` are available via `nix shell`**, e.g.
  `nix shell nixpkgs#python3 -c python3 script.py` or
  `nix shell nixpkgs#openssl -c openssl version`. Random hex:
  `od -An -N32 -tx1 /dev/urandom | tr -d ' \n'`. Local Rust toolchain:
  `nix shell nixpkgs#rustc nixpkgs#cargo nixpkgs#gcc` (there is no
  `nixpkgs#cc` flake attr — use `nixpkgs#gcc`).

## Secrets (sops-nix)

- Encrypted secrets: `hosts/grafton-router/secrets/secrets.yaml`
- Recipients/creation rules: `.sops.yaml` (age recipient
  `age1axfjvw2my0usdk082r5ny94rud5wa3whak6zesngkanuux894exqx2dv8g`)
- **`secrets.yaml` is tracked in git** — do not commit a decrypted version.
- The age key on this machine is **root-only**: `/var/lib/sops-nix/key.txt`
  (the flake sets `SOPS_AGE_KEY_FILE` to it). There is no user-local age key.

### Decrypt / edit / re-encrypt

```bash
# Read the key (needs sudo), then use it:
sudo cp /var/lib/sops-nix/key.txt /tmp/sops-key.txt && sudo chown $USER /tmp/sops-key.txt && chmod 600 /tmp/sops-key.txt
export SOPS_AGE_KEY_FILE=/tmp/sops-key.txt

sops --decrypt hosts/grafton-router/secrets/secrets.yaml > /tmp/secrets-plain.yaml
# ... edit /tmp/secrets-plain.yaml ...
# Encrypt from a path matching the creation rule (secrets/*.yaml) — encrypting
# from /tmp fails with "no matching creation rules found":
cp /tmp/secrets-plain.yaml hosts/grafton-router/secrets/.tmp-secrets.yaml
sops --encrypt hosts/grafton-router/secrets/.tmp-secrets.yaml > hosts/grafton-router/secrets/secrets.yaml
rm hosts/grafton-router/secrets/.tmp-secrets.yaml
```

For simple single-line values, `sops --set '["key"] "value"'` works in place.
Multi-line values (e.g. SSH private keys): use YAML block scalars (`|` /
`|-`). Note: OpenSSH private keys **need a trailing newline** (`|` not `|-`),
or `ssh-keygen`/`ssh.ParsePrivateKey` rejects them.

- Every secret referenced in `sops.nix` (`sops.secrets`) **must exist** in
  `secrets.yaml` or the build fails.
- Secret templates: `sops.templates."name".content` + `convertToEnvFile`
  (from `utils/convert.nix`) — rendered at activation with real values, so the
  Nix store only ever contains placeholders (`config.sops.placeholder.<name>`).

## House patterns

- **Services**: one file per service in `hosts/grafton-router/services/`,
  imported by `services/default.nix`. Keep the same shape as existing files.
- **SSO-protected web apps**: use `mkSSOVirtualHost` from
  `utils/nginx-sso-helper.nix`:
  ```nix
  services.nginx.virtualHosts."app.home.chrisdell.info" = mkSSOVirtualHost { proxyPass = "http://127.0.0.1:<port>"; };
  ```
  This adds nginx-sso `auth_request`, websocket proxying, and sets the
  `X-WEBAUTH-USER` header (full email — `user_id_method = "full-email"`).
- **OCI containers**: rootful podman via `virtualisation.oci-containers`
  (see `containers.nix`; `dockerCompat` + `dockerSocket` are enabled, so
  `/run/docker.sock` → `/run/podman/podman.sock`, group `podman`).
  Containers run as **root** via systemd units `podman-<name>.service` — a
  user-level `podman ps` shows nothing; use `sudo podman`.
- **Firewall**: `networking/nftables/firewall.nix` — default-drop `input` with
  trusted interfaces `lo`, LAN, VLAN10, podman0. Services bound to `127.0.0.1`
  work without firewall changes; anything on `0.0.0.0` needs a rule.

## Beszel monitoring (hub + agent)

Configured in `hosts/grafton-router/services/beszel.nix`. UI:
`https://beszel.home.chrisdell.info` (SSO).

- **Hub**: `127.0.0.1:8090`, nginx-proxied. Runs as fixed user `beszel-hub`
  (uid 9011; the nixpkgs module's default `DynamicUser` is overridden so the
  SSH key can be provisioned). Data + DB: **`/var/lib/beszel-hub/beszel_data`**
  — worth adding to the borg backup (see `services/backup.nix`).
- **Hub SSH key**: `/var/lib/beszel-hub/beszel_data/id_ed25519`, provisioned
  by the `beszel-hub-key.service` oneshot from sops secret `beszel_hub_key`
  before the hub starts. The matching public key is sops secret
  `beszel_agent_key`, fed to the agent as `KEY` via the `beszel-agent.env`
  sops template. If you replace this keypair, update **both** secrets and
  restart `beszel-hub-key.service` (oneshot, `RemainAfterExit` — a plain
  switch won't re-run it).
- **Agent**: `127.0.0.1:45876` (loopback only; `LISTEN` env). Monitors system
  stats, podman containers (in the `podman` group via the docker socket), and
  systemd services (module adds D-Bus policy). Agent data dir:
  `/var/lib/beszel-agent` (via `StateDirectory`).
- **Adding systems in the UI**: host `127.0.0.1`, port `45876`, leave
  Public Key/Token as pre-filled (SSH mode uses the hub's key). The
  "Docker"/"Binary" tabs in the Add System dialog only change which install
  command gets copied — irrelevant here, the agent is already running.
- **Module quirks**: beszel 0.18 removed `history-sync`; the nixpkgs module
  still lists it as `ExecStartPre` (overridden in `beszel.nix`). Setting
  `DISABLE_PASSWORD_AUTH=true` hides the first-run "create admin account"
  form (a beszel UI quirk) — don't enable it on a fresh hub.
- `TRUSTED_AUTH_HEADER = "X-WEBAUTH-USER"` gives SSO auto-login: the hub
  matches the header email against its user records, so user emails must equal
  Kanidm emails.

## Container UI (containers.home.chrisdell.info)

Rust (axum) server-rendered web UI for managing the podman containers —
status/ports/CPU/RAM, update one/many, restart, and **live logs over SSE**.
Configured in `hosts/grafton-router/services/container-ui.nix`.
Agent notes for the source repo (deployment loop, podman CLI gotchas):
`/home/cjdell/Projects/nixos-utils/AGENTS.md`.

- **Source lives in the `nixos-utils` repo** (`container-ui/`, built as
  `packages."x86_64-linux".container-ui` by that flake) — not in this repo.
- Runs as **root** (shells out to `podman`/`systemctl`), binds
  `127.0.0.1:8091`. The nginx vhost sets `proxy_buffering off` — required for
  the SSE log tail; if live logs stall, check that first.
- Does **its own Kanidm OIDC** (PKCE + id_token JWKS verification) — it is
  *not* the `mkSSOVirtualHost` pattern. Client `container-ui`: non-public,
  secret in sops `container_ui_oidc_client_secret`, `scopeMaps."admins"`.
- **Login "Access Denied" = group membership, not client misconfig.** A
  `scopeMaps` client grants only the union of the maps for the groups the
  user is in — check `kanidm group list-members admins` first (see Kanidm
  section below).
- Sessions + PKCE state are **in-memory**: a service restart logs everyone out.
- CSRF: per-session token in hidden form inputs; the container detail page has
  **two** forms → two inputs (take the first when scripting).
- axum gotcha: HTML responses must be wrapped in `axum::response::Html`
  (helper `html_resp` in `handlers.rs`) — a bare `(status, String)` response is
  served as `text/plain`, so browsers render raw source and inline JS never
  runs.

## Health dashboard (health.home.chrisdell.info)

Realtime system health page: canvas charts for CPU (per-core), memory, load,
temperature, per-interface network traffic, per-device disk IO and disk
space, with time ranges 1m–24h and hover tooltips. Configured in
`hosts/grafton-router/services/health.nix` (SSO vhost via `mkSSOVirtualHost`).
Agent notes for the source repo: `/home/cjdell/Projects/nixos-utils/AGENTS.md`.

- **Source lives in the `nixos-utils` repo** (`health/`): axum backend that
  samples `/proc` + `statvfs` + hwmon every second, plus a dioxus 0.7 SPA
  (wasm). Enabled here via `services.health.enable = true` (the `health`
  nixos module) — this service file only adds the nginx vhost.
- Binds `127.0.0.1:8092`; the SPA polls `/api/data` every second (no SSE).
- **All history is in-memory** — a `systemctl restart health` resets the
  graphs; data from before the restart is gone.
- The loopback port map: health `8092` (after container-ui `8091`, beszel
  hub `8090`).
- Series names are an API contract (`cpu.core.N`, `net.<iface>.rx/.tx`, …)
  — keep backend and SPA in sync if you rename any.

## Kanidm (IdM) — operations & troubleshooting

Version 1.10.4. CLI: the `kanidm-with-secret-provisioning` package in the nix
store; `KANIDM_URL=https://kanidm.home.chrisdell.info` and
`KANIDM_NAME=idm_admin` are set system-wide.

- `kanidm login` is **interactive**. To script the CLI, inject a fresh bearer
  JWT into `~/.cache/kanidm_tokens` (JSON shape
  `{"instances":{"":{"keys":{...},"tokens":{"<spn>":"<jwt>"}}}}`) — back
  the file up first.
- Server logs: `sudo journalctl -u kanidm` (extremely verbose — grep, e.g.
  `kopid`). Config `/etc/kanidm/server.toml`, bind `127.0.0.1:8999`, database
  in `/srv/kanidm` (bind path of `/var/lib/kanidm`).
- **`scopeMaps` semantics**: a user's available scopes are the union of the
  maps for the groups they belong to; with none, the login page shows
  "Access Denied" (kanidm log shows `available_scopes: {}`). Don't remove
  `scopeMaps` — it's the house pattern for every client.
- **OAuth codes expire in ~1–2 minutes** ("Expired token exchange request") —
  run the whole login → consent → exchange flow in one fast scripted pass.
- Scriptable HTML login flow (what the UI uses): `POST /ui/login/begin` form
  `{username}` → `POST /ui/login/pw` form `{password}` → 303 + `bearer` cookie
  (JWT, ~1h). Then `GET /ui/oauth2?response_type=code&...` with the cookie →
  consent page (hidden `consent_token` input) or a straight 303 to the callback
  if consent was already granted. `POST /ui/oauth2/consent` form
  `{consent_token}` → 303 to the callback. No CSRF header needed for these.
- The API authorize route is `/oauth2/authorise` (British spelling, at the
  root) and requires an `Authorization: Bearer` header — the `bearer` cookie
  is not honoured there.
- Reset an account's password non-interactively:
  ```bash
  sudo env KANIDM_RECOVER_ACCOUNT_PASSWORD="<new>" <kanidm-pkg>/bin/kanidmd scripting \
    recover-account -c /etc/kanidm/server.toml <account> --from-environment
  ```
- ⚠️ **The self-service reset UI lies.** `POST /ui/reset/add_password` returns
  **200** but only *adds* a password credential — it does **not** replace the
  account's active/primary credential. So after a "successful" UI reset the
  new password still fails login with `Denied: incorrect password`. The robust
  path is the `recover-account` scripting command above, which sets the
  primary credential. Always verify with a `kanidm login` afterwards.
- **Password quality policy is zxcvbn/passphrase-based** (server rejects weak
  picks with `PasswordQuality([UseAFewWordsAvoidCommonPhrases, ...])`). Use a
  multi-word passphrase.
- **Provisioned users** (added to `provision.persons` in `kanidm.nix`) are
  created with **no password** — set one via `recover-account`.
- **Admin groups/users must be declared in the Nix provision**, not created via
  CLI. `admins` has `overwriteMembers=true` and `autoRemove=true`, so a CLI-only
  admin (or a person not in the provision) is silently reverted/removed on the
  next `nixos-rebuild switch`. Users: `jack` (admin), `testuser`, `cjdell`.
- ⚠️ **Never reset `cjdell`'s password for testing** — it locks the user out
  of *every* SSO app. Test with `idm_admin` instead (add it to `admins`
  temporarily if you need to exercise a `scopeMaps` client, then remove it
  again — the Nix provision enforces `overwriteMembers=true`). Its password is
  rotated and **not stored anywhere** — reset it with the command above when
  you need it.

## Verifying web UIs with a headless browser

Works well for end-to-end checks of SSO + live features (e.g. SSE):

```bash
nix shell nixpkgs#chromium --command sh -c \
  'chromium --headless=new --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-prof --no-sandbox about:blank' &
# first run downloads ~500 MB from cache.nixos.org — wait up to ~90 s
curl -X PUT 'http://127.0.0.1:9222/json/new?about:blank'    # → page ws URL
nix shell nixpkgs#websocat --command websocat -t <ws-url>   # pipe CDP JSON lines
```

Drive it with CDP JSON: `Network.setCookie`, `Page.navigate`,
`Runtime.evaluate` (`returnByValue: true`). Session cookies are HttpOnly, so
set them with `Network.setCookie` (you can't read them from JS).

## Other useful facts

- `README.md` covers architecture, install, and the auto-rollback workflow.
- Helper tools on the system: `list-containers`, `list-generations` (shows
  "good"/"current"/"booted" generations).
- `system.updateContainers` posts to the notifications gateway on port 8888
  (`notifications.gateway` in `http.nix`).
- Network constants live in `hosts/grafton-router/networking/constants.nix`.
- Loopback port map: kanidm bind `8999`, beszel hub `8090`, container-ui
  `8091`, health `8092`, beszel agent `45876`, frigate-whisper web `8973`,
  notifications gateway `8888`.
- The repo also contains a microVM (hackspace client) and several
  `junk/` files that are **not** imported — don't assume they're active.
