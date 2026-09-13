{ config, pkgs, ... }:

{
  home.username = "gatinho";
  home.homeDirectory = "/home/gatinho";

  home.stateVersion = "26.05"; 
  home.packages = [
    pkgs.hello
  ];

  home.sessionVariables = {

  };


  programs.home-manager.enable = true;programs.fish = {
  enable = true;
  interactiveShellInit = ''
    set -g fish_greeting ""
  '';
  shellAliases = {
    ls = "lsd";
    l = "ls -l";
    la = "ls -a";
    lt = "ls --tree";
    cat = "bat";
    krz = "sudo nixos-rebuild switch";
    vld = "home-manager switch --flake /etc/nixos#gatinho -b backup";
  };
};
   programs.bat = {
   enable = true;
   config = {
     theme = "Nord"; 
     };
   };
   home.file.".config/niri/config.kdl".source = ./niri/config.kdl;
   home.file.".config/hypr/hypridle.conf".source = ./hypr/hypridle.conf;
   home.file.".config/waybar/config.jsonc".source = ./waybar/config.jsonc;
   home.file.".config/waybar/style.css".source = ./waybar/style.css;
   home.file.".config/swaync/config.json".source = ./swaync/config.json;
   home.file.".config/swaync/style.css".source = ./swaync/style.css;
   home.file.".config/swaync/Styles/central_control.css".source = ./swaync/Styles/central_control.css;
   home.file.".config/swaync/Styles/notifications.css".source = ./swaync/Styles/notifications.css;
   home.file.".config/swaync/matugen/colors.css".source = ./swaync/matugen/colors.css;
   home.file.".config/rofi/vicinae.rasi".source = ./rofi/vicinae.rasi;
   home.file.".config/fastfetch/config.jsonc".source = ./fastfetch/config.jsonc;
}

