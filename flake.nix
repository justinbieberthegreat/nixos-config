{
description = "flakies";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    zen-browser.url = "github:youwen5/zen-browser-flake";
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    freesm.url = "github:FreesmTeam/FreesmLauncher";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    };
  outputs = { self, nixpkgs, nixpkgs-unstable, freesm, home-manager, ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    in {
      nixosConfigurations.gatinho = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ ./configuration.nix ];
      };

    homeConfigurations = {
        gatinho = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix ];
          };
      };
};
}
