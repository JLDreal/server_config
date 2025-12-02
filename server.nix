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

    # BIOS (legacy) GRUB for non-UEFI systems.
    # The disk device used for grub installation will be taken from the INSTALL_DISK
    # environment variable if present, otherwise it falls back to /dev/sda.
    loader.grub = {

      enable = true;
      efiSupport = false;
      # read device from env variable set by the installer script:
      device = lib.mkDefault (let devEnv = builtins.getEnv "INSTALL_DISK"; in if devEnv == "" then "/dev/sda" else devEnv);
    };
  };

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/ROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    # Keep a harmless default for /boot if someone creates it; not used on minimal BIOS installs.
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
  };

  system.stateVersion = "25.11";

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
    password = "egon34"; # TODO: replace with a hash or SSH keys
    description = "hans";
    extraGroups = [ "networkmanager" "wheel" "sudo" ];
    packages = with pkgs; [
      git
      curl
    ];
  };

  users.extraUsers.root.password = "egon34"; # TODO: remove plaintext
}
