
{ config, lib, pkgs, pkgsUnstable, inputs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

    _module.args.pkgsUnstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    inherit (config.nixpkgs) config;
  }; 
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  
  networking.hostName = "gatinho"; 
  networking.networkmanager.enable = true;
  
  programs.niri.enable = true;
  services.displayManager.ly = {
  enable = true;
  settings = { 
  animation = "dur_file";
  full_color = true;
  dur_file_path = "/etc/ly/blackhole.dur";
  hide_borders = true;
  clock = "%c";
  bigclock = "en";
  };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.steam.enable = true;
  services.gvfs.enable = true;
  programs.hyprlock.enable = true;
  nixpkgs.config.allowUnfree = true;
  services.hypridle.enable = true;
  environment.etc."ly/blackhole.dur".source = ./blackhole-smooth-240x67.dur;
  
  
  time.timeZone = "Asia/Tbilisi";

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.libinput.enable = true;
   
  hardware.bluetooth = {
  enable = true;
  powerOnBoot = true;
};
 
  users.users.gatinho = {
  isNormalUser = true;
  extraGroups = [ "networkmanager" "wheel" ];
  packages = with pkgs; [
     alacritty
     stremio-linux-shell
     fastfetch
     overskride
     nautilus
     xwayland-satellite
     neovim
     nwg-look
     vscodium
     brightnessctl
     git 
     waybar
     spotify
     networkmanagerapplet
     fish
     font-manager
     upscayl
     awww
     btop
     swaynotificationcenter
     obsidian
     nmgui
     discord
     hyprlock
     anki
     qbittorrent
     rofi
     libnotify
     cliphist 
     wl-clipboard 
     wtype 
     lsd 
     bat 
     gcc 
     gnumake
     tree-sitter
     yt-dlp
     ffmpeg
     aria2
     telegram-desktop
     vlc
     papers
     komikku
     cmus
     curl
     python3
     ];
  };

  programs.firefox.enable = true;
  nixpkgs.overlays = [ inputs.apple-fonts.overlays.default ];

  environment.systemPackages = with pkgs; [
  adwaita-icon-theme 
  inputs.freesm.packages.${pkgs.stdenv.hostPlatform.system}.default
  inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default
  ffmpeg_4
  xdg-user-dirs
  whitesur-icon-theme 
  pkgsUnstable.brave-origin
  mpv
  helium
  ]; 

fonts.packages = with pkgs; [
nerd-fonts.jetbrains-mono
inter
noto-fonts 
noto-fonts-cjk-serif
sf-pro
];
#font settings
fonts.fontconfig.localConf = ''
  <?xml version="1.0"?>
  <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
  <fontconfig>
    <match target="font">
      <edit name="antialias" mode="assign">
        <bool>true</bool>
      </edit>
      <edit name="hinting" mode="assign">
        <bool>true</bool>
      </edit>
      <edit name="rgba" mode="assign">
        <const>rgb</const>
      </edit>
      <edit name="hintstyle" mode="assign">
        <const>hintslight</const>
      </edit>
      <edit name="lcdfilter" mode="assign">
        <const>lcddefault</const>
      </edit>
    </match>

    <alias>
      <family>serif</family>
      <prefer>
        <family>Noto Serif</family>
        <family>Noto Color Emoji</family>
      </prefer>
    </alias>
    <alias>
      <family>sans-serif</family>
      <prefer>
        <family>Noto Sans</family>
        <family>Noto Color Emoji</family>
      </prefer>
    </alias>
    <alias>
      <family>sans</family>
      <prefer>
        <family>Noto Sans</family>
        <family>Noto Color Emoji</family>
      </prefer>
    </alias>
    <alias>
      <family>monospace</family>
      <prefer>
        <family>Noto Sans Mono</family>
        <family>Noto Color Emoji</family>
      </prefer>
    </alias>
    <alias>
      <family>mono</family>
      <prefer>
        <family>Noto Sans Mono</family>
        <family>Noto Color Emoji</family>
      </prefer>
    </alias>
  </fontconfig>
'';
system.stateVersion = "26.05";
}

