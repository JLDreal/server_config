# Server Configuration

This repository contains the configuration for a server environment.

## Development Environment

This project uses devenv for development. Enter the environment with:

```sh
devenv shell
```

The environment includes convenient scripts for building and flashing ISOs.

## Building and Flashing an ISO

### Using the provided scripts (recommended)

1. **Enter the development environment**:
   ```sh
   devenv shell
   ```

2. **Build the ISO**:
   ```sh
   build-iso
   ```

3. **Format the USB drive** (replace `sdX` with your device):
   ```sh
   format-usb sdX
   ```

4. **Flash the USB drive** (replace `sdX` with your device):
   ```sh
   flash-usb sdX
   ```

### Manual method

1. **Build the ISO**:
   ```sh
   nix build .#nixosConfigurations.iso.config.system.build.isoImage
   ```

2. **Prepare the USB Drive**:
   - Connect your USB drive.
   - Identify your USB drive using:
     ```sh
     lsblk
     ```
   - Format the USB drive to FAT32. Replace `/dev/sdX` with your USB device identifier:
     ```sh
     sudo mkfs.vfat -F32 /dev/sdX
     ```

3. **Flash the USB Drive**:
   - Flash the USB drive with the resulting ISO. Replace `/dev/sdX` with your USB device identifier:
     ```sh
     sudo dd if=result/iso/nixos-minimal*.iso of=/dev/sdX bs=4M status=progress && sync
     ```

