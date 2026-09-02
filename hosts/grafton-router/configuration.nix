# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, ... }:

{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  system.autoRollback.enable = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Set your time zone.
  time.timeZone = "Europe/London";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_GB.UTF-8";
    LC_IDENTIFICATION = "en_GB.UTF-8";
    LC_MEASUREMENT = "en_GB.UTF-8";
    LC_MONETARY = "en_GB.UTF-8";
    LC_NAME = "en_GB.UTF-8";
    LC_NUMERIC = "en_GB.UTF-8";
    LC_PAPER = "en_GB.UTF-8";
    LC_TELEPHONE = "en_GB.UTF-8";
    LC_TIME = "en_GB.UTF-8";
  };

  # Configure console keymap
  console.keyMap = "uk";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.cjdell = {
    uid = 1001;
    isNormalUser = true;
    description = "Chris Dell";
    # World-traversable (but not readable) so the nginx worker (user 'nginx')
    # can serve /home/cjdell/Projects/Portfolio-Website for jacksballard.com.
    homeMode = "0755";
    extraGroups = [
      "networkmanager"
      "wheel"
      "dialout"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJ63Sro9L4zmSuYKQ654cWwBMq0KFFWxWGflAJbFEFJ me@chrisdell.info"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFKXFQsN5M23Yeh1jPYv/8Ys6wrH4VIluuJ5177ovXZW cjdell@alderlake-thinkpad"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMRCJXVDcEMPZIDsymH52VEBVs19aUK6p7+bsifAq+FG cjdell@N100-NAS"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCbDJ7tQwODw2kx2f1bstOUElKnaR3hP2RbwCsf6zebZ5n/1CFUoM2Ye78D/IG/6kgDc22wD9EkzyvIwF/96fp3IgxK5ja/Q0pEhbd8xAPGIpFC7BUyePqozRusSvJXl7RamBb8lgsjySQxJxYX9MQzbQkfasWOwWE+WWqiC9nwk6WiER7EraOdEVNNF9cuNS/LVFrQZG5xdzI5gSgaxth2kQSgE3z7jIIvmlYkChEjTMXSQt9MrluhWB1nzGDHVrcqW8uu/jAqeMhRCXP39wtmL21v3WFn1jwDQlOgbR1CxnBzy+jE62TqvOJg8x6/J2WC/VXcdndHq1vKYP0s5mQn zen3-nixos@grafton.lan"
    ];
  };

  security.sudo.wheelNeedsPassword = false;

  programs.nix-ld.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    dmidecode
    nmap
    inetutils
    wget
    tmux
    screen
    efibootmgr
    unzip
    direnv
    x264
    pciutils
    usbutils
    lsof
    speedtest-rs
    intel-gpu-tools
    tio
    dig
    outils
    wol
    parallel
    jq
    graphviz
    ethtool

    # Development
    nixfmt
    alejandra
    nixd
    nil
    deno
    git
    node-gyp
    nodejs

    # Debug
    conntrack-tools
    tcpdump # tcpdump -i vlan10 -n host 192.168.10.138 and port 22
  ];

  environment.sessionVariables.LD_LIBRARY_PATH = "${pkgs.stdenv.cc.cc.lib}/lib";

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?
}
