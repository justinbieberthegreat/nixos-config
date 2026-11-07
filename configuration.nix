{ config, lib, pkgs, pkgsUnstable, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.silentSDDM.nixosModules.default
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
  programs.kdeconnect.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };


  programs.silentSDDM = {
    enable = true;
    theme = "default";

backgrounds = {
 statue = ./love.png;
 };

    settings = {
      "LockScreen" = {
        background = "love.png";
      };

      "LoginScreen" = {
        background = "love.png";
      };

      General = {
        scale = 1.75;
      };

      "LoginScreen.LoginArea.Username" = {
        font-family = "SF Pro";
      };

      "LoginScreen.LoginArea.PasswordInput" = {
        font-family = "SF Pro";
        background-color = "#FFFFFF";
        background-opacity = 0.12;
        content-color = "#FFFFFF";
        border-size = 1;
        border-color = "#FFFFFF";
        border-radius-left = 15;
        border-radius-right = 15;
      };
"LockScreen.Clock" = {
  font-size = 84;
};

"LockScreen.Date" = {
  font-size = 17;
};

"LockScreen.Message" = {
  font-size = 15;
};

      "LoginScreen.LoginArea.LoginButton" = {
        hide-if-not-needed = true;
      };
    };

    profileIcons = {
      gatinho = ./kitty.png;
    };
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  programs.steam.enable = true;
  services.gvfs.enable = true;
  programs.hyprlock.enable = true;
  

  nixpkgs.config.allowUnfree = true;

  services.hypridle.enable = true;
  time.timeZone = "Asia/Tbilisi";

  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  services.libinput.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      Policy = {
        AutoEnable = true;
      };
    };
  };

  users.users.gatinho = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "video" ];
    packages = with pkgs; [
      alacritty
      discord
      sqlite
      playerctl
      gradle_8
      quickshell
      proton-vpn
      fastfetch
      overskride
      nautilus
      xwayland-satellite
      neovim
      android-tools
      nwg-look
      vscodium
      brightnessctl
      krita
      git 
      networkmanagerapplet
      fish
      font-manager
      upscayl
      awww
      btop
      nmgui
      anki
      qbittorrent
      libnotify
      cliphist 
      wl-clipboard 
      wtype 
      lsd
      kdePackages.okular
      bat 
      gcc 
      gnumake
      tree-sitter
      yt-dlp
      ffmpeg
      aria2
      vlc
      papers
      cmus
      curl
      python3
      telegram-desktop
      dialect
      apostrophe
    ];
  };

  programs.firefox.enable = false;

  nixpkgs.overlays = [ 
    inputs.apple-fonts.overlays.default
    inputs.spotx-nix.overlays.default
  ];

  environment.systemPackages = with pkgs; [
    adwaita-icon-theme
    inputs.freesm.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-desktop
inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.chatgpt

    
    (pkgs.spotify-spotx.override {
      spotxArgs = [ "--hide" ];
    })
    ffmpeg
    xdg-user-dirs
    pkgsUnstable.brave-origin
    pkgsUnstable.ani-cli
    mpv
    helium
    jdk21
    stremio-linux-shell
    (mousam.overrideAttrs (old: {
  postPatch = (old.postPatch or "") + ''
    substituteInPlace src/frontendCardAirPollution.py \
      --replace-fail \
      'Gtk.Label(label=self.air_apllution_data["hourly"]["us_aqi"][idx])' \
      'Gtk.Label(label=str(self.air_apllution_data["hourly"]["us_aqi"][idx]))'
  '';
}))
  ];

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    inter
    noto-fonts 
    noto-fonts-cjk-serif
    sf-pro
    noto-fonts-cjk-sans
  ];

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
