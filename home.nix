{ inputs, config, pkgs, ... }:

{
  home.username = "gatinho";
  home.homeDirectory = "/home/gatinho";

  home.stateVersion = "26.05"; 
  home.packages = [
    #pkgs.hello
    #pkgs.numix-cursor-theme
  ];

home.pointerCursor = {
  package = pkgs.capitaine-cursors;
  name = "capitaine-cursors";
  size = 25;
  gtk.enable = true;
  x11.enable = true;
};

  i18n.inputMethod = {
  enable = true;
  type = "fcitx5";
  fcitx5 = {
    waylandFrontend = true;
    addons = with pkgs; [
      fcitx5-mozc
      fcitx5-hangul
      fcitx5-gtk
    ];
  };
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
    ff = "fastfetch";
    krz = "sudo nixos-rebuild switch";
    vld = "home-manager switch --flake /etc/nixos#gatinho -b backup";
  };
};
xdg.configFile."fontconfig/fonts.conf".text = ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <!-- Anti-aliasing, Hinting, Subpixel RGB, LCD Filter -->
      <match target="font">
        <edit name="antialias" mode="assign"><bool>true</bool></edit>
        <edit name="hinting" mode="assign"><bool>true</bool></edit>
        <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
        <edit name="rgba" mode="assign"><const>rgb</const></edit>
        <edit name="lcdfilter" mode="assign"><const>lcddefault</const></edit>
      </match>

      <!-- Default font preferences & Emoji fallback -->
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
        <family>monospace</family>
        <prefer>
          <family>Noto Sans Mono</family>
          <family>Noto Color Emoji</family>
        </prefer>
      </alias>

      <!-- Disable embedded bitmaps for crisp fonts, EXCEPT Noto Color Emoji -->
      <match target="font">
        <edit name="embeddedbitmap" mode="assign"><bool>false</bool></edit>
      </match>
      <match target="font">
        <test name="family" qual="any"><string>Noto Color Emoji</string></test>
        <edit name="embeddedbitmap" mode="assign"><bool>true</bool></edit>
      </match>
    </fontconfig>
  '';
  home.sessionVariables = {
    FREETYPE_PROPERTIES = "truetype:interpreter-version=40 cff:no-stem-darkening=0 autofitter:no-stem-darkening=0";
  };
  xresources.properties = {
    "Xft.lcdfilter" = "lcddefault";
    "Xft.hintstyle" = "hintslight";
    "Xft.hinting" = 1;
    "Xft.antialias" = 1;
    "Xft.rgba" = "rgb";
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
   home.file.".config/rofi/vicinae.rasi".source = ./rofi/vicinae.rasi;
   home.file.".config/fastfetch/config.jsonc".source = ./fastfetch/config.jsonc;
   home.file.".config/swaync/config.json".source = ./swaync/config.json;
   home.file.".config/swaync/style.css".source = ./swaync/style.css;
   home.file.".config/swaync/Styles/central_control.css".source = ./swaync/Styles/central_control.css;
   home.file.".config/swaync/Styles/notifications.css".source = ./swaync/Styles/notifications.css;
   home.file.".config/matugen/colors.css".source = ./swaync/matugen/colors.css;
   xdg.configFile."mpv/scripts/mpvacious".source =
   config.lib.file.mkOutOfStoreSymlink "/home/gatinho/mpvacious";
}

