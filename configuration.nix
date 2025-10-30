{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
      git
      gum
      (
        writeShellScriptBin "nix_installer"
        ''
          #!/usr/bin/env bash
          set -euo pipefail


          if [ "$(id -u)" -eq 0 ]; then
          	echo "ERROR! $(basename "$0") should be run as a regular user"
          	exit 1
          fi

          if [ ! -d "$HOME/dotfiles/.git" ]; then
          	git clone https://github.com/JLDreal/server_config "$HOME/dotfiles"
          fi

          TARGET_HOST=$(ls -1 ~/dotfiles/configuration.nix | cut -d'/' -f6 | grep -v iso | gum choose)

          gum confirm  --default=false \
          "🔥 🔥 🔥 WARNING!!!! This will ERASE ALL DATA on the disk $TARGET_HOST. Are you sure you want to continue?"

          sudo nixos-install --flake "$HOME/dotfiles#$TARGET_HOST"
        ''
      )
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
      };

      networking = {
        hostName = "sklave1";
      };

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
        password = "egon34";
        description = "hans";
        extraGroups = [ "networkmanager" "wheel" "sudo" "root" ];
        packages = with pkgs; [
          git
          curl
        ];
      };
      users.extraUsers.root.password = "egon34";
}
