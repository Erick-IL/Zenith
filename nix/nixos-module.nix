{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.zenith;
  zenithPkg = cfg.package;
  sddmTheme = cfg.sddmPackage;
  grubTheme = cfg.grubPackage;
in {
  options.programs.zenith = {
    enable = mkEnableOption "Zenith dynamic island desktop shell";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ./default.nix {};
      description = "The Zenith package to use.";
    };

    sddmPackage = mkOption {
      type = types.package;
      default = pkgs.callPackage ./sddm-theme.nix {};
      description = "The Zenith SDDM theme package to use.";
    };

    grubPackage = mkOption {
      type = types.package;
      default = pkgs.callPackage ./grub-theme.nix {};
      description = "The Zenith GRUB theme package to use.";
    };

    enableSddmTheme = mkOption {
      type = types.bool;
      default = true;
      description = "Enable and configure the Zenith SDDM theme.";
    };

    enableGrubTheme = mkOption {
      type = types.bool;
      default = false;
      description = "Enable and configure the Zenith GRUB theme.";
    };

    enableServices = mkOption {
      type = types.bool;
      default = true;
      description = "Enable recommended services (iwd, power-profiles-daemon, upower, pipewire, bluetooth, i2c).";
    };

    enableFonts = mkOption {
      type = types.bool;
      default = true;
      description = "Install recommended fonts (JetBrainsMono Nerd Font, Noto fonts).";
    };
  };

  config = mkIf cfg.enable {
    # Hyprland Compositor & XDG Portal
    programs.hyprland = {
      enable = mkDefault true;
      xwayland.enable = mkDefault true;
    };

    xdg.portal = {
      enable = mkDefault true;
      extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
    };

    # Session environment variables for Qt6 / QML support on NixOS
    environment.sessionVariables = {
      QML2_IMPORT_PATH = "/run/current-system/sw/lib/qt-6/qml";
    };

    # Keyboard layout (ABNT2 default)
    services.xserver.xkb = {
      layout = mkDefault "br";
      variant = mkDefault "abnt2";
      model = mkDefault "abnt2";
    };
    console.keyMap = mkDefault "br-abnt2";

    # PAM profile for swaylock (lock screen & password vault)
    security.pam.services.swaylock = {};

    # Recommended fonts
    fonts = mkIf cfg.enableFonts {
      packages = with pkgs; [
        nerd-fonts.jetbrains-mono
        noto-fonts
        noto-fonts-color-emoji
        noto-fonts-cjk-sans
        noto-fonts-extra
      ];
    };

    # System services
    networking.wireless.iwd = mkIf cfg.enableServices {
      enable = mkDefault true;
      settings = {
        General = {
          EnableNetworkConfiguration = mkDefault true;
        };
      };
    };
    services.power-profiles-daemon.enable = mkIf cfg.enableServices (mkDefault true);
    services.upower.enable = mkIf cfg.enableServices (mkDefault true);
    hardware.bluetooth.enable = mkIf cfg.enableServices (mkDefault true);
    hardware.i2c.enable = mkIf cfg.enableServices (mkDefault true);

    # PipeWire Audio
    services.pipewire = mkIf cfg.enableServices {
      enable = mkDefault true;
      alsa.enable = mkDefault true;
      alsa.support32Bit = mkDefault true;
      pulse.enable = mkDefault true;
      wireplumber.enable = mkDefault true;
    };

    # SDDM Login Theme
    services.displayManager.sddm = mkIf cfg.enableSddmTheme {
      enable = mkDefault true;
      wayland.enable = mkDefault true;
      theme = "zenith";
      extraPackages = [
        sddmTheme
        pkgs.qt6.qtdeclarative
        pkgs.qt6.qtsvg
        pkgs.qt6.qtmultimedia
      ];
    };

    # GRUB Boot Theme
    boot.loader.grub = mkIf cfg.enableGrubTheme {
      theme = "${grubTheme}";
    };

    # Shared runtime state for SDDM greeter bridge
    systemd.tmpfiles.rules = [
      "d /var/lib/zenith 0755 root root -"
    ];

    # System packages needed by Zenith
    environment.systemPackages = with pkgs; [
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
      udisks2
      udiskie
      gvfs
      qt6.qtmultimedia
      qt6.qtdeclarative
    ];
  };
}
