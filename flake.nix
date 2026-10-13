{
  description = "Zenith - A Hyprland desktop where the whole shell is a single capsule";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          zenith = pkgs.callPackage ./nix/default.nix {};
          zenith-sddm-theme = pkgs.callPackage ./nix/sddm-theme.nix {};
          zenith-grub-theme = pkgs.callPackage ./nix/grub-theme.nix {};
          default = self.packages.${system}.zenith;
        });

      overlays.default = final: prev: {
        zenith = final.callPackage ./nix/default.nix {};
        zenith-sddm-theme = final.callPackage ./nix/sddm-theme.nix {};
        zenith-grub-theme = final.callPackage ./nix/grub-theme.nix {};
      };

      nixosModules = {
        zenith = import ./nix/nixos-module.nix;
        default = self.nixosModules.zenith;
      };

      homeManagerModules = {
        zenith = import ./nix/home-manager-module.nix;
        default = self.homeManagerModules.zenith;
      };

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              bash
              git
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
    
            ];
          };
        });
    };
}
