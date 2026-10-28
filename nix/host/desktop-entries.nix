{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.makeDesktopItem {
      name = "Modrinth App";      # Nome exibido no menu
      desktopName = "Modrinth App"; # Nome exato do arquivo (.desktop)
      exec = "steam-run ModrinthApp";
      icon = "ModrinthApp";
      terminal = false;
      categories = [ "Game" ];
    })
  ];
}
