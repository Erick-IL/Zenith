{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "zenith-grub-theme";
  version = "1.0.0";

  src = ../../grub/zenith;

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r * $out/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Zenith dynamic island GRUB boot theme";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
