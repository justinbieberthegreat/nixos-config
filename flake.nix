{
description = "flakies";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    llm-agents.url = "github:numtide/llm-agents.nix";
    apple-fonts.url = "github:Lyndeno/apple-fonts.nix";
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    freesm.url = "github:FreesmTeam/FreesmLauncher";
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
    };

outputs = { self, nixpkgs, nixpkgs-unstable, freesm, home-manager, helium-flake, ... }@inputs:
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
