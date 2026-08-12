# AGENTS.md — Notes for AI agents working on this repository

Operational knowledge for working on this NixOS configuration. Read this before
making changes, deploying, or diagnosing issues.

## ⚠️ CRITICAL: Automatic rollbacks

`system.autoRollback.enable = true` is set on `grafton-router`. After **any**
`nixos-rebuild switch` (or `boot`), a timer starts that auto-rolls-back to the
last known-good generation after **5 minutes** unless the new generation is
confirmed.

**Always run after deploying:**

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

## Other useful facts

- `README.md` covers architecture, install, and the auto-rollback workflow.
- Helper tools on the system: `list-containers`, `list-generations` (shows
  "good"/"current"/"booted" generations).
- `system.updateContainers` posts to the notifications gateway on port 8888
  (`notifications.gateway` in `http.nix`).
- Network constants live in `hosts/grafton-router/networking/constants.nix`.
- The repo also contains a microVM (hackspace client) and several
  `junk/` files that are **not** imported — don't assume they're active.
