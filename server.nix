{ 
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    git
    gum
    curl
  ];

  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "hans" ];
    };
  };

  # merged networking (hostName + static interface)
  networking = {
    usePredictableInterfaceNames = false;
    interfaces.eth0.ipv4.addresses = [{
      address = "10.1.104.202";
      prefixLength = 16;
    }];
    defaultGateway = "10.1.104.90";
    nameservers = [ "10.1.104.1" ];
    hostName = "sklave1";
  };

  nixpkgs = {
    hostPlatform = lib.mkDefault "x86_64-linux";
    config.allowUnfree = true;
  };

  nix = {
    settings.experimental-features = ["nix-command" "flakes"];
    extraOptions = "experimental-features = nix-command flakes";
  };

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    supportedFilesystems = lib.mkForce ["btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs"];

    # Use systemd-boot (UEFI) to match the installer configuration
    loader = {
      systemd-boot.enable = true;
      # Allow installer / nixos-install to write EFI variables when booted under UEFI
      efi = {
        canTouchEfiVariables = true;
      };
    };
  };

  # Filesystems will be configured by installer
  # These are fallback defaults for non-installer usage
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/ROOT";
    fsType = "ext4";
  };

  # with systemd-boot, the ESP is normally mounted at /boot
  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
  };

  system.stateVersion = "25.11";

  # gnome power settings do not turn off screen
  systemd = {
    services.sshd.wantedBy = pkgs.lib.mkForce ["multi-user.target"];
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
  };

  users.users.hans = {
    isNormalUser = true;
    password = "egon34"; # TODO: replace with hash or use SSH keys
    description = "hans";
    extraGroups = [ "networkmanager" "wheel" "sudo" ];
    packages = with pkgs; [
      git
      curl
    ];
  };

  # avoid keeping root password in plaintext in your repo; prefer a hash or
  # lock the account and use sudo keys
  users.extraUsers.root.password = "egon34";
}
