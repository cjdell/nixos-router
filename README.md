# NixOS Router

My NixOS router implementation.

Secrets are managed with `sops-nix` and will need to be recreated for deployment on to other systems. This is my real router configuration however it can serve as a reference to anyone inspired to do the same.

## Services

- Router / Firewall using `nftables`
- Interface configuration with `networkd`
- PPPoE for UK ISP (Zen Internet)
- Home Assistant
- Zigbee2MQTT
- Frigate NVR
- AdGuard
- NGINX Reverse Proxy with ACME Certification Manager (for various home lab services)
- A few other miscellaneous things specific to my setup...

## Installing

Boot the NixOS live environment.

Make sure `/mnt` and `/mnt/boot` are mounted and the correct device IDs are in `hardware-configuration.nix`.

Comment out any services you don't need in `./services/default.nix`.

Generate a new `./secrets/secrets.yaml`.

Tweak your interface names and addresses in `./networking/interface.nix`.

Install with:

```bash
nixos-install --root /mnt --flake .#router
```

## Applying Changes

```bash
sudo nixos-rebuild switch --flake .#router

sudo nixos-confirm  # Mark this generation as good as we don't get rollbacked
```

## Auto Rollbacks

Every time a new generation is deployed a timer starts that will automatically rollback to the last know good configuration in 5 minutes.

This is to prevent you messing up a firewall rule that will lock you out accidentally.

To mark this generation as the last known good configuration, use `sudo nixos-confirm`. See [`nixos-utils`](https://github.com/cjdell/nixos-utils) for more information.

## Useful Tools

```bash
sudo list-containers    # List running containers along with their IP address

list-generations        # See "good", "current" and "booted" generations
```
