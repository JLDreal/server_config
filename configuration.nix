{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    git
    gum
    curl
    (
      writeShellScriptBin "nix_installer"
        ''
          #!/usr/bin/env bash
          set -euo pipefail

          # Color codes for output
          RED='\033[0;31m'
          GREEN='\033[0;32m'
          YELLOW='\033[1;33m'
          NC='\033[0m' # No Color

          log_info()  { echo -e "''${GREEN}[INFO]''${NC} $1"; }
          log_warn()  { echo -e "''${YELLOW}[WARN]''${NC} $1"; }
          log_error() { echo -e "''${RED}[ERROR]''${NC} $1"; }

          if [ "$(id -u)" -eq 0 ]; then
            log_error "$(basename "$0") should be run as a regular user"
            exit 1
          fi

          if [ ! -d "$HOME/dotfiles/.git" ]; then
            log_info "Cloning server_config repository..."
            git clone https://github.com/JLDreal/server_config "$HOME/dotfiles"
          fi

          TARGET_HOST="server"

          log_info "Available disks:"
          lsblk -d -o NAME,SIZE,MODEL | grep -E '^sd|^nvme|^vd|^hd'
          echo ""

          TARGET_DISK=$(lsblk -d -o NAME,SIZE,MODEL | grep -E '^sd|^nvme|^vd|^hd' | gum choose | awk '{print $1}')
          DISK_PATH="/dev/$TARGET_DISK"

          log_warn "Selected disk: $DISK_PATH"
          gum confirm --default=false \
          "🔥 WARNING: This will ERASE ALL DATA on $DISK_PATH. Continue?" || exit 1

          check_disk_busy() {
            if mount | grep -q "$DISK_PATH"; then
              log_error "Disk $DISK_PATH has mounted partitions. Unmount them first."
              exit 1
            fi
            if swapoff --show=NAME | grep -q "$DISK_PATH"; then
              log_info "Disabling swap on $DISK_PATH..."
              sudo swapoff $(swapoff --show=NAME | grep "$DISK_PATH") || true
            fi
          }
          check_disk_busy

          log_info "Wiping disk $DISK_PATH..."
          sudo wipefs -a "$DISK_PATH"
          sudo sgdisk --zap-all "$DISK_PATH" || true
          sudo dd if=/dev/zero of="$DISK_PATH" bs=1M count=10 status=progress
          sudo partprobe "$DISK_PATH"
          sleep 2

          log_info "Creating GPT partition table and bios_grub + ROOT partitions..."
          sudo sgdisk --clear "$DISK_PATH"

          # Create bios_grub partition (2MiB) - do NOT format or mkfs it.
          sudo sgdisk --new=1:1MiB:+2MiB --typecode=1:ef02 --change-name=1:bios_grub "$DISK_PATH"

          # Create root partition (rest)
          sudo sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:ROOT "$DISK_PATH"

          sudo partprobe "$DISK_PATH"
          sleep 2

          if [[ "$TARGET_DISK" == nvme* ]]; then
            BIOS_PART="$DISK_PATH"p1
            ROOT_PART="$DISK_PATH"p2
          else
            BIOS_PART="$DISK_PATH"1
            ROOT_PART="$DISK_PATH"2
          fi

          log_info "Formatting root partition..."
          sudo mkfs.ext4 -F "$ROOT_PART"

          log_info "Mounting root partition..."
          sudo mount "$ROOT_PART" /mnt

          log_info "Generating hardware configuration..."
          sudo nixos-generate-config --root /mnt

          # Use labels for root
          sudo e2label "$ROOT_PART" ROOT
          sudo sed -i 's|device = "/dev/[^"]*"|device = "/dev/disk/by-label/ROOT"|g' /mnt/etc/nixos/hardware-configuration.nix
          sudo sed -i 's|fsType = "[^"]*"|fsType = "ext4"|g' /mnt/etc/nixos/hardware-configuration.nix

          # Copy the flake configuration as a reference and append installation-specific bits
          sudo cp "$HOME/dotfiles/configuration.nix" /mnt/etc/nixos/configuration.nix

          sudo tee -a /mnt/etc/nixos/configuration.nix > /dev/null << 'EOF'

# Installation-specific configuration (BIOS)
fileSystems."/" = {
  device = "/dev/disk/by-label/ROOT";
  fsType = "ext4";
};
EOF

          # Export the install target so the flake can read it when evaluated
          export INSTALL_DISK="$DISK_PATH"
          log_info "EXPORT INSTALL_DISK=$INSTALL_DISK"

          log_info "Installing NixOS (this will copy closures into /nix/store on the target)..."
          sudo nixos-install --root /mnt --flake "$HOME/dotfiles#server"

          log_info "Installation completed successfully!"
          log_info "You can now reboot into your new NixOS system."
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
    # The flake's server.nix controls GRUB installation; default here is harmless.
    loader.grub.devices = lib.mkDefault [ "/dev/sda" ];
  };

  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/ROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = lib.mkDefault {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
  };

  system.stateVersion = "25.11";

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
