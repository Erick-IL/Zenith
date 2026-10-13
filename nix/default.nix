{ lib
, stdenvNoCC
, makeWrapper
}:

stdenvNoCC.mkDerivation rec {
  pname = "zenith";
  version = "1.0.8";

  src = lib.cleanSourceWith {
    src = ../.;
    filter = path: type:
      let
        base = baseNameOf path;
      in
        !(lib.hasPrefix "." base && base != ".version")
        && base != "flake.nix"
        && base != "flake.lock"
        && base != "nix";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/zenith
    cp -r zenith hypr foot fish fastfetch nano applications assets bin grub sddm install.sh LICENSE README.md $out/share/zenith/

    # Install desktop files
    mkdir -p $out/share/applications
    for f in applications/*.desktop; do
      substitute "$f" "$out/share/applications/$(basename "$f")" \
        --replace-quiet "@HOME@/.config/zenith" "$out/share/zenith/zenith" \
        --replace-quiet "@HOME@" "$out/share/zenith"
    done

    # Ensure scripts have execute permissions
    chmod +x $out/share/zenith/install.sh
    chmod +x $out/share/zenith/zenith/scripts/*.sh 2>/dev/null || true
    chmod +x $out/share/zenith/zenith/scripts/*.py 2>/dev/null || true
    chmod +x $out/share/zenith/hypr/scripts/*.sh 2>/dev/null || true
    chmod +x $out/share/zenith/bin/* 2>/dev/null || true

    # Install helper CLI entrypoints
    mkdir -p $out/bin
    cat > $out/bin/zenith-install <<'EOF'
    #!/usr/bin/env bash
    exec "$out/share/zenith/install.sh" "$@"
    EOF
    substituteInPlace $out/bin/zenith-install --replace-fail '$out' "$out"
    chmod +x $out/bin/zenith-install

    cat > $out/bin/zenith-shell <<'EOF'
    #!/usr/bin/env bash
    export QML2_IMPORT_PATH="''${QML2_IMPORT_PATH:-/run/current-system/sw/lib/qt-6/qml:$HOME/.nix-profile/lib/qt-6/qml}"
    CONF="''${XDG_CONFIG_HOME:-$HOME/.config}/zenith"
    if [ -d "$CONF" ]; then
      exec qs -c "$CONF" "$@"
    else
      exec qs -c "$out/share/zenith/zenith" "$@"
    fi
    EOF
    substituteInPlace $out/bin/zenith-shell --replace-fail '$out' "$out"
    chmod +x $out/bin/zenith-shell

    runHook postInstall
  '';

  meta = with lib; {
    description = "A Hyprland desktop where the whole shell is a single capsule (dynamic island)";
    homepage = "https://github.com/EnsixD/Zenith";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
