{
  description = "My Home Manager configuration";

  inputs = {
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";

    zed.url = "github:zed-industries/zed";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:JLDreal/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
     nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";


     lix = {
      url = "https://git.lix.systems/lix-project/lix/archive/main.tar.gz";
      flake = false;
    };

    lix-module = {
      url = "https://git.lix.systems/lix-project/nixos-module/archive/main.tar.gz";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.lix.follows = "lix";
    };
    flake-parts.url = "github:hercules-ci/flake-parts";

  };
outputs = {self, nixpkgs, home-manager, zen-browser, nixpkgs-unstable,lix, lix-module,zed,flake-parts , ... }@inputs:
let

  system = "x86_64-linux";
  lib = nixpkgs.lib;


  pkgs = import nixpkgs {
    inherit system;
    config = {
      allowUnfree = true;
      allowBroken = true;
    };
  };
in {



  nixosConfigurations = {
    iso = lib.nixosSystem {
      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
        "${nixpkgs}/nixos/modules/installer/cd-dvd/channel.nix"
        ./configuration.nix
      ];
      specialArgs = {inherit inputs;};
    };
    server = lib.nixosSystem {
      modules = [
        ./server.nix
      ];
      specialArgs = {inherit inputs;};
    };
  };

};}
