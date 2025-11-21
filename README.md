# NixOS Router

My NixOS router implementation.

Secrets missing and should be placed in `secrets` folder. Impure build required, may migrate to `sops` someday.

## Services

Router / Firewall using `nftables`
Interface configuration with `networkd`
PPPoE for UK ISP (Zen Internet)
Home Assistant
Zigbee2MQTT
Frigate NVR
A few other miscellaneous things specific to my setup...

## Applying

```bash
sudo nixos-rebuild boot --flake .#NixOS-Router --impure
```

### Useful tools

```bash
$ sudo list-container-ips 
Container Name: mqtt, Container ID: edeec653856e, IP Address: 10.88.1.1
Container Name: zigbee2mqtt, Container ID: 5f6c197ae0e2, IP Address: 10.88.0.35
Container Name: twofauth, Container ID: 298d44358c1b, IP Address: 10.88.0.37
Container Name: frigate, Container ID: c4af23051376, IP Address: 10.88.0.36
```
