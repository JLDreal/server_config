{ pkgs, lib, config, inputs, ... }:
{

  # https://devenv.sh/basics/
  # env.GREET = "devenv";



  enterShell = ''
    echo "Available scripts:"
    echo "  build-iso    - Build the NixOS ISO"
    echo "  format-usb   - Format USB drive to FAT32 (usage: format-usb sdX)"
    echo "  flash-usb    - Flash ISO to USB drive (usage: flash-usb sdX)"
    echo ""
    echo "Quick start:"
    echo "  1. build-iso"
    echo "  2. format-usb sdX"
    echo "  3. flash-usb sdX"
    echo ""
    echo "Current USB devices:"
    lsblk -f
  '';

  # https://devenv.sh/packages/
  packages = [ pkgs.git pkgs.jq ];
  scripts = {
    build-iso.exec = ''
      nix build .#nixosConfigurations.iso.config.system.build.isoImage
  '';

  flash-usb.exec = ''
    echo "flashing:"
    export iso=$(ls result/iso/nixos-minimal*.iso | head -n 1)
    sudo dd if=$iso of="/dev/$1" bs=4M status=progress && sync
  '';

  format-usb.exec = ''
    echo "Formatting USB drive to FAT32:"
    sudo mkfs.vfat -F32 -I "/dev/$1"
  '';
  };




}
