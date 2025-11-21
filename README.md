# NixOS Router

My NixOS router implementation.

Secrets missing and should be placed in `secrets` folder. Impure build required, may migrate to `sops` someday.

## Services

- Router / Firewall using `nftables`
- Interface configuration with `networkd`
- PPPoE for UK ISP (Zen Internet)
- Home Assistant
- Zigbee2MQTT
- Frigate NVR
- A few other miscellaneous things specific to my setup...

## Installing

Make sure `/mnt` and `/mnt/boot` are mounted and the correct device IDs are in `hardware-configuration.nix`.

Comment out any services you don't need in `./services/default.nix`.

Tweak your interface names and address in `./networking/interface.nix`.

Install with:

```bash
nixos-install --impure --root /mnt --flake .#NixOS-Router
```

## Applying

```bash
sudo nixos-rebuild switch --flake .#NixOS-Router --impure

nixos-confirm # Don't rollback if the current generation is good
```

## Auto Rollbacks

Every time a new generation is deployed a timer starts that will automatically rollback to the last know good configuration in 5 minutes.

This is to prevent you messing up a firewall rule that will lock you out accidentally.

To make this generation the last known good configuration, use `nixos-confirm`. See `./rollback.nix` for more information.

## Useful tools

```bash
$ sudo list-container-ips 
Container Name: mqtt, Container ID: edeec653856e, IP Address: 10.88.1.1
Container Name: zigbee2mqtt, Container ID: 5f6c197ae0e2, IP Address: 10.88.0.35
Container Name: twofauth, Container ID: 298d44358c1b, IP Address: 10.88.0.37
Container Name: frigate, Container ID: c4af23051376, IP Address: 10.88.0.36
```
