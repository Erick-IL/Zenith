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

  zenith-grub-theme = pkgs.stdenvNoCC.mkDerivation {
    pname = "zenith-grub-theme";
    version = "1.0.0";
    src = ./zenith/grub/zenith;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r * $out/
    '';
  };
in
{
  # Ensure runtime directory for wallpaper sync and SDDM bridge
  systemd.tmpfiles.rules = [
    "d /var/lib/zenith 0777 root root -"
  ];

  # SDDM Theme definition and assets helper
  # (Uncomment below to use Zenith theme for SDDM)
  # services.displayManager.sddm = {
  #   enable = true;
  #   wayland.enable = true;
  #   theme = "zenith";
  #   extraPackages = [
  #     zenith-sddm-theme
  #     pkgs.qt6.qtdeclarative
  #     pkgs.qt6.qtsvg
  #     pkgs.qt6.qtmultimedia
  #   ];
  # };
}
