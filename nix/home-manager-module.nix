{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.zenith;
  zenithPkg = pkgs.callPackage ./default.nix {};
in {
  options.programs.zenith = {
    enable = mkEnableOption "Zenith user configuration";

    mutableConfigs = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to copy configs to ~/.config so they remain mutable by Zenith's
        built-in settings UI, shortcuts editor, and wallpaper selector.
      '';
    };

    installPackages = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install Zenith runtime packages in user profile.";
    };
  };

  config = mkIf cfg.enable {
    home.sessionVariables = {
      QML2_IMPORT_PATH = lib.mkDefault "/run/current-system/sw/lib/qt-6/qml:$HOME/.nix-profile/lib/qt-6/qml";
    };

    home.packages = mkIf cfg.installPackages (with pkgs; [
      zenithPkg
      quickshell
      hyprland
      hyprpaper
      hyprsunset
      foot
      fish
      eza
      zoxide
      bat
      fastfetch
      yazi
      swaylock
      jq
      wl-clipboard
      cliphist
      grim
      slurp
      ffmpeg
      wf-recorder
      wtype
      brightnessctl
      ddcutil
      playerctl
      wireplumber
      python3
      openssl
      xdg-utils
      glib
      upower
      cava
      mpvpaper
      bibata-cursors
      papirus-icon-theme
      udiskie
    ]);

    # Cursor & GTK settings
    home.pointerCursor = {
      gtk.enable = true;
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };

    gtk = {
      enable = true;
      cursorTheme = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Classic";
        size = 24;
      };
      iconTheme = {
        package = pkgs.papirus-icon-theme;
        name = "Papirus-Dark";
      };
    };

    # Activation hook to set up ~/.config and symlinks
    home.activation.setupZenith = lib.hm.dag.entryAfter ["writeBoundary"] ''
      # Symlink quickshell configuration directory
      mkdir -p $HOME/.config/quickshell
      if [ ! -e $HOME/.config/quickshell/zenith ] && [ -d $HOME/.config/zenith ]; then
        ln -sfn $HOME/.config/zenith $HOME/.config/quickshell/zenith
      fi

      # Ensure executable permissions on Zenith scripts
      chmod +x $HOME/.config/zenith/scripts/*.sh 2>/dev/null || true
      chmod +x $HOME/.config/zenith/scripts/*.py 2>/dev/null || true
      chmod +x $HOME/.config/hypr/scripts/*.sh 2>/dev/null || true
      chmod +x $HOME/.local/bin/* 2>/dev/null || true
    '';
  };
}
