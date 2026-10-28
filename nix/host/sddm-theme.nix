{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "zenith-sddm-theme";
  version = "1.0.0";

  src = ../../sddm/zenith;

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/sddm/themes/zenith
    cp -r * $out/share/sddm/themes/zenith/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Zenith dynamic island SDDM login theme";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
