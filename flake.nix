{
description = "flakies";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    llm-agents.url = "github:numtide/llm-agents.nix";
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    xremap-flake.url = "github:xremap/nix-flake";
    helium-flake.url = "github:oxcl/nix-flake-helium-browser";
    home-manager.url = "github:nix-community/home-manager/release-26.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    silentSDDM = {
      url = "github:uiriansan/SilentSDDM";
      inputs.nixpkgs.follows = "nixpkgs";
   }; 
    spotx-nix = {
    url = "github:SpotX-Official/SpotX-Nix";
     inputs.nixpkgs.follows = "nixpkgs"; 
    };
    zen-browser = {
    url = "github:0xc000022070/zen-browser-flake";
    inputs = {
    nixpkgs.follows = "nixpkgs";
    home-manager.follows = "home-manager";
    };
    };
    nixpkgs-stremio.url = "github:NixOS/nixpkgs/51e103be12cdd94c2af4956e311b66e84af4fb4a";
dl-desktop-src = {
  url = "github:hmlendea/dl-desktop/d493f6de6b465cb279bda2eb9780cda19d4acdb5";
  flake = false;
};
      };

outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, helium-flake, nixpkgs-stremio, xremap-flake,  ... }@inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      pkgs-unstable = nixpkgs-unstable.legacyPackages.${system};
    in {
      nixosConfigurations.gatinho = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [ 
	./configuration.nix
        xremap-flake.nixosModules.default
       {	
       nixpkgs.overlays = [ helium-flake.overlays.default ];
	}
      ];
      };

    homeConfigurations = {
        gatinho = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
	  extraSpecialArgs = { inherit inputs; };
          modules = [ ./home.nix ];
          };
      };
};
}
