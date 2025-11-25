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

            log_info() {
                echo -e "''${GREEN}[INFO]''${NC} $1"
            }

            log_warn() {
                echo -e "''${YELLOW}[WARN]''${NC} $1"
            }

            log_error() {
                echo -e "''${RED}[ERROR]''${NC} $1"
            }

            if [ "$(id -u)" -eq 0 ]; then
            	log_error "$(basename "$0") should be run as a regular user"
            	exit 1
            fi

            if [ ! -d "$HOME/dotfiles/.git" ]; then
            	log_info "Cloning server_config repository..."
            	git clone https://github.com/JLDreal/server_config "$HOME/dotfiles"
            fi

            # Select target host
            TARGET_HOST="server"

            # Select target disk
            log_info "Available disks:"
            lsblk -d -o NAME,SIZE,MODEL | grep -E '^sd|^nvme|^vd|^hd'
            echo ""
            
            TARGET_DISK=$(lsblk -d -o NAME,SIZE,MODEL | grep -E '^sd|^nvme|^vd|^hd' | gum choose | awk '{print $1}')
            DISK_PATH="/dev/$TARGET_DISK"

            log_warn "Selected disk: $DISK_PATH"
            gum confirm --default=false \
            "🔥 🔥 🔥 WARNING!!!! This will COMPLETELY ERASE ALL DATA on disk $DISK_PATH and install NixOS. Are you sure you want to continue?" || exit 1

            log_info "Starting installation process..."

            # Function to check if disk is busy
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

            # Check if disk is busy
            check_disk_busy

            # Complete disk wipe
            log_info "Wiping disk $DISK_PATH..."
            sudo wipefs -a "$DISK_PATH"
            sudo sgdisk --zap-all "$DISK_PATH" || true
            sudo dd if=/dev/zero of="$DISK_PATH" bs=1M count=10 status=progress
            sudo partprobe "$DISK_PATH"
            sleep 2

            # Create partition table
            log_info "Creating partition table..."
            sudo sgdisk --clear "$DISK_PATH"
            
            # Create EFI partition (512M)
            log_info "Creating EFI partition..."
            sudo sgdisk --new=1:0:+512M --typecode=1:EF00 --change-name=1:EFI "$DISK_PATH"
            
            # Create root partition (remaining space)
            log_info "Creating root partition..."
            sudo sgdisk --new=2:0:0 --typecode=2:8300 --change-name=2:ROOT "$DISK_PATH"
            
            # Inform kernel of partition changes
            sudo partprobe "$DISK_PATH"
            sleep 2

            # Determine partition names
            if [[ "$TARGET_DISK" == nvme* ]]; then
                EFI_PART="''${DISK_PATH}p1"
                ROOT_PART="''${DISK_PATH}p2"
            else
                EFI_PART="''${DISK_PATH}1"
                ROOT_PART="''${DISK_PATH}2"
            fi

            # Format partitions
            log_info "Formatting EFI partition..."
            sudo mkfs.fat -F32 "$EFI_PART"
            
            log_info "Formatting root partition..."
            sudo mkfs.ext4 -F "$ROOT_PART"

            # Mount partitions for installation
            log_info "Mounting partitions..."
            sudo mount "$ROOT_PART" /mnt
            sudo mkdir -p /mnt/boot
            sudo mount "$EFI_PART" /mnt/boot

            # Generate hardware configuration
            log_info "Generating hardware configuration..."
            sudo nixos-generate-config --root /mnt

            # Create a temporary configuration that includes our custom settings
            log_info "Creating installation configuration..."
            cat > /tmp/install-config.nix << 'EOF'
{ config, pkgs, lib, ... }:
{
  imports = [ ./hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  fileSystems."/" = {
    device = "/dev/disk/by-label/ROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
  };

  # Add labels to partitions
  boot.initrd.luks.devices = {
    root = {
      device = "/dev/disk/by-label/ROOT";
    };
  };
}
EOF

            # Update the generated configuration to use labels
            sudo sed -i 's|device = "/dev/[^"]*"|device = "/dev/disk/by-label/ROOT"|g' /mnt/etc/nixos/hardware-configuration.nix
            sudo sed -i 's|fsType = "[^"]*"|fsType = "ext4"|g' /mnt/etc/nixos/hardware-configuration.nix

            # Add labels to partitions
            sudo fatlabel "$EFI_PART" EFI
            sudo e2label "$ROOT_PART" ROOT

            # Copy our custom configuration
            sudo cp "$HOME/dotfiles/configuration.nix" /mnt/etc/nixos/configuration.nix

            # Merge with installation config
            sudo tee -a /mnt/etc/nixos/configuration.nix > /dev/null << 'EOF'

# Installation-specific configuration
boot.loader.systemd-boot.enable = true;
boot.loader.efi.canTouchEfiVariables = true;

fileSystems."/" = {
  device = "/dev/disk/by-label/ROOT";
  fsType = "ext4";
};

fileSystems."/boot" = {
  device = "/dev/disk/by-label/EFI";
  fsType = "vfat";
};
EOF

            # Install NixOS
            log_info "Installing NixOS..."
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
        # Bootloader will be configured by installer
        loader.grub.devices = lib.mkDefault [ "/dev/sda" ];
      };

      # Filesystems will be configured by installer
      # These are fallback defaults for non-installer usage
      fileSystems."/" = lib.mkDefault {
        device = "/dev/disk/by-label/ROOT";
        fsType = "ext4";
      };

      fileSystems."/boot" = lib.mkDefault {
        device = "/dev/disk/by-label/EFI";
        fsType = "vfat";
      };

      system.stateVersion = "25.11";

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
