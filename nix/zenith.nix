# /etc/nixos/zenith.nix
# Zenith Desktop Shell module for NixOS
{ config, pkgs, lib, ... }:

let
  zenith-sddm-theme = pkgs.stdenvNoCC.mkDerivation {
    pname = "zenith-sddm-theme";
    version = "1.0.0";
    src = ./zenith/sddm/zenith;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/sddm/themes/zenith
      cp -r * $out/share/sddm/themes/zenith/
    '';
  };
in
{
  # SDDM Display Manager with Zenith Island Theme
  services.displayManager = {
    defaultSession = lib.mkDefault "hyprland";
    sddm = {
      enable = lib.mkDefault true;
      # X11 greeter: stable with NVIDIA. Override with `wayland.enable = true` if desired.
      wayland.enable = lib.mkDefault false;
      theme = "zenith";
      extraPackages = [
        zenith-sddm-theme
        pkgs.qt6.qtdeclarative
        pkgs.qt6.qtsvg
        pkgs.qt6.qtmultimedia
        pkgs.qt6.qt5compat
      ];
    };
  };

  environment.systemPackages = [
    zenith-sddm-theme
  ];

  # Shared runtime state for the SDDM greeter bridge
  systemd.tmpfiles.rules = [
    "d /var/lib/zenith 0777 root root -"
  ];

  # Auto-unlock GNOME Keyring on login via SDDM
  security.pam.services.sddm.enableGnomeKeyring = lib.mkDefault true;
}
