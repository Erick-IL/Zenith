#!/usr/bin/env bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Por favor, execute este script com sudo: sudo ./fix_greeter_and_power.sh"
  exit 1
fi

echo "=== 1. Corrigindo tema do SDDM (Greeter) ==="
METADATA="/etc/nixos/panacea/sddm/panacea/metadata.desktop"
if [ -f "$METADATA" ]; then
  if ! grep -q "QtVersion" "$METADATA"; then
    echo "QtVersion=6" >> "$METADATA"
    echo "-> Adicionado QtVersion=6 em $METADATA"
  else
    echo "-> QtVersion já configurado em $METADATA"
  fi
fi

echo "=== 2. Configurando botão Power (Segurar Ctrl para desligar) ==="
CONF="/etc/nixos/configuration.nix"
if [ -f "$CONF" ]; then
  if ! grep -q "HandlePowerKey" "$CONF"; then
    cp "$CONF" "${CONF}.bak-$(date +%Y%m%d%H%M%S)"
    sed -i '/fonts\.packages/i \
  # Ignorar acionamento direto do botao Power (evita desligamento acidental)\
  services.logind.settings.Login = {\
    HandlePowerKey = "ignore";\
    HandlePowerKeyLongPress = "ignore";\
  };\
\
  # Desligar apenas quando o botao Power for pressionado com CTRL segurado\
  services.acpid = {\
    enable = true;\
    powerEventCommands = '"''"'\
      ${pkgs.python3}/bin/python3 -c '\''\
import glob, fcntl, array, subprocess\
buf = array.array("B", [0] * 64)\
EVIOCGKEY_64 = 0x80404518\
KEY_LEFTCTRL = 29\
KEY_RIGHTCTRL = 97\
ctrl = False\
for ev in glob.glob("/dev/input/event*"):\
    try:\
        with open(ev, "rb") as f:\
            fcntl.ioctl(f.fileno(), EVIOCGKEY_64, buf, True)\
            if ((buf[KEY_LEFTCTRL // 8] >> (KEY_LEFTCTRL % 8)) & 1) or ((buf[KEY_RIGHTCTRL // 8] >> (KEY_RIGHTCTRL % 8)) & 1):\
                ctrl = True\
                break\
    except Exception:\
        pass\
if ctrl:\
    subprocess.run(["systemctl", "poweroff"])\
'\''\
    '"''"';\
  };\
' "$CONF"
    echo "-> Configuração de logind e acpid inserida em $CONF"
  else
    echo "-> HandlePowerKey já existente em $CONF"
  fi
fi

echo "=== 3. Aplicando alterações com nixos-rebuild switch ==="
nixos-rebuild switch

echo "=== Tudo pronto com sucesso! ==="
