# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./desktop-entries.nix
    
      ./zenith.nix

    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    networkmanager.enable = false;
    wireless.enable = false;
    wireless.iwd.enable = true;
  };

  # Set your time zone.
  time.timeZone = "America/Sao_Paulo";

  # Select internationalisation properties.
  i18n.defaultLocale = "pt_BR.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };


# 1. Ativa o suporte ao Flatpak nativo do NixOS
  services.flatpak.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;
  
  # hyprland
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-hyprland ];
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "br";
    variant = "";
  };

  services.displayManager.sddm.enable = true;
  
  # Configure console keymap
  console.keyMap = "br-abnt2";

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users."levandoski" = {
    isNormalUser = true;
    description = "levandoski";
    extraGroups = [ "networkmanager" "wheel" "i2c" "docker" ];
    packages = with pkgs; [
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Steam config
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.gamemode.enable = true;
  virtualisation.docker.enable = true;
  # List packages installed in system profile.
  nixpkgs.config.allowUnfree = true;  
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
    
  environment.systemPackages = with pkgs; [
    # Com e Mídia
    discord
    spotify
    jetbrains-toolbox    
    obsidian    
    
    bibata-cursors

    hyprland
    quickshell       
    foot
    fish
    eza
    zoxide
    hyprpaper
    hyprsunset
    cliphist
    wf-recorder
    cava
    brightnessctl
    iwd
    qt6.qtmultimedia
    qt6.qtdeclarative

    kitty
    git
    postman
        
    vscode
    prismlauncher
    steam-run
    pavucontrol

    #fonts
    nerd-fonts.jetbrains-mono  
    monocraft
    
    # Zenith dependencies
    bat
    fastfetch
    yazi
    swaylock
    jq
    wl-clipboard
    grim
    slurp
    ffmpeg
    wtype
    ddcutil
    playerctl
    wireplumber
    python3
    openssl
    xdg-utils
    glib
    upower
    mpvpaper
    papirus-icon-theme
    udisks2
    udiskie
    gvfs
    qt6.qtsvg
    python3Packages.secretstorage
    python3Packages.cryptography
    zip
    unzip
    playwright-driver.browsers
    
    # JDK
    jdk21
    nodejs_26
  ];

  environment.sessionVariables = {
    # Em sistemas de GPU híbrida (Intel + NVIDIA PRIME Offload), NÃO devemos
    # definir __GLX_VENDOR_LIBRARY_NAME = "nvidia" ou GBM_BACKEND = "nvidia-drm"
    # globalmente, pois isso força todas as aplicações X11/GLX/Wayland a usarem
    # o driver NVIDIA na tela primária Intel, quebrando o SDDM e outras aplicações.
    # Para rodar jogos/apps na NVIDIA, use `nvidia-offload` / `prime-run`.
    QML2_IMPORT_PATH = "/run/current-system/sw/lib/qt-6/qml";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
  PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

  };

  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    jetbrains-toolbox
  ];

  system.stateVersion = "26.05";

  # 1. Habilitar drivers proprietários NVIDIA
  services.xserver.videoDrivers = [ "nvidia" ];

  # 2. Configurações específicas da NVIDIA (PRIME Offload)
  hardware.nvidia = {
    modesetting.enable = true;

    powerManagement.enable = false;
    powerManagement.finegrained = false;

    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    # PRIME Sync: a GPU NVIDIA RTX 3050 atua como placa principal de renderização,
    # enviando a saída para a tela do notebook gerenciada pelo barramento Intel.
    prime = {
      sync.enable = true;

      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # 3. Suporte a gráficos/OpenGL
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # PAM profile for swaylock & Zenith password vault
  security.pam.services.swaylock = {};
  services.power-profiles-daemon.enable = true;
  services.upower.enable = true;
  hardware.bluetooth.enable = true;
  hardware.i2c.enable = true;
  programs.fish.enable = true;

  # Zenith shared directory for wallpaper & SDDM sync
  systemd.tmpfiles.rules = [
    "d /var/lib/zenith 0777 root root -"
  ];

  # Ignorar acionamento direto do botao Power (evita desligamento acidental)
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "ignore";
  };

  # Desligar apenas quando o botao Power for pressionado com CTRL segurado
  services.acpid = {
    enable = true;
    powerEventCommands = ''
      ${pkgs.python3}/bin/python3 -c '
import glob, fcntl, array, subprocess
buf = array.array("B", [0] * 64)
EVIOCGKEY_64 = 0x80404518
KEY_LEFTCTRL = 29
KEY_RIGHTCTRL = 97
ctrl = False
for ev in glob.glob("/dev/input/event*"):
    try:
        with open(ev, "rb") as f:
            fcntl.ioctl(f.fileno(), EVIOCGKEY_64, buf, True)
            if ((buf[KEY_LEFTCTRL // 8] >> (KEY_LEFTCTRL % 8)) & 1) or ((buf[KEY_RIGHTCTRL // 8] >> (KEY_RIGHTCTRL % 8)) & 1):
                ctrl = True
                break
    except Exception:
        pass
if ctrl:
    subprocess.run(["systemctl", "poweroff"])
'
    '';
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts
    noto-fonts-color-emoji
    noto-fonts-cjk-sans
  ];
}
