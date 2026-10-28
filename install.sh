#!/usr/bin/env bash
# ==============================================================================
# Zenith Shell - One pill for everything.
# Dynamic Island Desktop Environment for Hyprland & NixOS/Arch
# https://github.com/Erick-IL/Zenith
# ==============================================================================

set -euo pipefail

SRC="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
CONF="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN_DIR="$HOME/.local/bin"
APPS_DIR="$HOME/.local/share/applications"

# Terminal formatting
if [ -t 1 ]; then
    B=$'\e[1m'; DIM=$'\e[2m'; OK=$'\e[32m'; WARN=$'\e[33m'; ERR=$'\e[31m'; ACC=$'\e[36m'; N=$'\e[0m'
else
    B=""; DIM=""; OK=""; WARN=""; ERR=""; ACC=""; N=""
fi

step() { printf '\n%s▍ %s%s\n' "$B" "$*" "$N"; }
ok()   { printf '  %s✓%s %s\n' "$OK" "$N" "$*"; }
warn() { printf '  %s!%s %s\n' "$WARN" "$N" "$*"; }
die()  { printf '\n%sErro:%s %s\n' "$ERR" "$N" "$*" >&2; exit 1; }

# Flags
DO_LINK=0
DO_BACKUP=1
DO_SDDM=1
DO_GRUB=1
DO_NIXOS=0
AUTO_YES=0

usage() {
    cat <<EOF
Uso: ./install.sh [opções]

Opções:
  -l, --link        Criar links simbólicos para ~/.config em vez de copiar (ótimo para desenvolvimento)
  -c, --copy        Copiar arquivos para ~/.config (padrão)
  -y, --yes         Responder "sim" a todas as perguntas
  --no-backup       Não criar cópias de backup das configurações existentes
  --no-sddm         Não instalar tema do SDDM
  --no-grub         Não instalar tema do GRUB
  --nixos           Injetar módulo Zenith no /etc/nixos/configuration.nix
  -h, --help        Exibir esta ajuda
EOF
    exit 0
}

while [ $# -gt 0 ]; do
    case "$1" in
        -l|--link)     DO_LINK=1 ;;
        -c|--copy)     DO_LINK=0 ;;
        -y|--yes)      AUTO_YES=1 ;;
        --no-backup)   DO_BACKUP=0 ;;
        --no-sddm)     DO_SDDM=0 ;;
        --no-grub)     DO_GRUB=0 ;;
        --nixos)       DO_NIXOS=1 ;;
        -h|--help)     usage ;;
        *) warn "Opção desconhecida: $1" ;;
    esac
    shift
done

ask() {
    [ "$AUTO_YES" = "1" ] && return 0
    local prompt="$1"
    read -rp "$prompt [S/n] " ans
    case "${ans,,}" in
        ""|s|sim|y|yes) return 0 ;;
        *) return 1 ;;
    esac
}

# Banner
printf '%s' "$ACC"
cat <<'EOF'
  ______           _ _   _       _____ _          _ _ 
 |___  /          (_) | | |     / ____| |        | | |
    / / ___ _ __   _| |_| |__  | (___ | |__   ___| | |
   / / / _ \ '_ \ | | __| '_ \  \___ \| '_ \ / _ \ | |
  / /_|  __/ | | || | |_| | | | ____) | | | |  __/ | |
 /_____\___|_| |_||_|\__|_| |_||_____/|_| |_|\___|_|_|
EOF
printf '%s\n' "$N"
printf '  %sOne pill for everything • Hyprland Desktop Environment%s\n\n' "$DIM" "$N"

if [ "$DO_LINK" = "1" ]; then
    printf '  %sModo:%s Links Simbólicos (%s → ~/.config)\n' "$B" "$N" "$SRC"
else
    printf '  %sModo:%s Cópia física de arquivos\n' "$B" "$N"
fi

# Detect environment
IS_NIXOS=0
if [ -f /etc/NIXOS ] || grep -qiE 'ID=nixos|ID_LIKE=.*nixos' /etc/os-release 2>/dev/null; then
    IS_NIXOS=1
fi

SUDO=""
if [ "$EUID" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    elif command -v doas >/dev/null 2>&1; then
        SUDO="doas"
    fi
fi

# ------------------------------------------------------------------------------
# 1. Backups
# ------------------------------------------------------------------------------
STAMP="$(date +%Y%m%d-%H%M%S)"
if [ "$DO_BACKUP" = "1" ]; then
    step "Criando backup das configurações atuais..."
    mkdir -p "$CONF"
    for d in zenith hypr foot fish fastfetch nano; do
        if [ -e "$CONF/$d" ] && [ ! -L "$CONF/$d" ]; then
            cp -r "$CONF/$d" "$CONF/${d}.bak-${STAMP}"
            ok "Backup: ~/.config/${d}.bak-${STAMP}"
        fi
    done
fi

# ------------------------------------------------------------------------------
# 2. Instalar configurações (zenith, hypr, foot, fish, fastfetch, nano)
# ------------------------------------------------------------------------------
step "Instalando configurações do Zenith..."
mkdir -p "$CONF" "$BIN_DIR" "$APPS_DIR"

# Files generated/owned by the user at runtime - never overwritten in copy mode
STATE_EXCLUDES=(
    --exclude='__pycache__' --exclude='*.pyc' --exclude='.version' --exclude='.vibrance'
    --exclude='.whatsnew' --exclude='*.pid' --exclude='*_state.json' --exclude='last_wifi_ssid'
    --exclude='eq_prev_sink.txt' --exclude='/settings.json' --exclude='*_data.lua'
    --exclude='/wallpaper/custom' --exclude='/wallpaper.conf' --exclude='/palette.conf'
    --exclude='/monitors.conf' --exclude='/input_data.conf' --exclude='/custom/'
    --exclude='/custom.fish' --exclude='/custom.ini' --exclude='/custom.jsonc'
)

install_dir() {
    local src_dir="$1"
    local dst_dir="$2"
    local name="$3"

    [ -d "$src_dir" ] || return 0

    if [ "$DO_LINK" = "1" ]; then
        rm -rf "$dst_dir"
        ln -sfn "$src_dir" "$dst_dir"
        ok "Link: ~/.config/$name → $src_dir"
    elif command -v rsync >/dev/null 2>&1; then
        [ -L "$dst_dir" ] && rm -f "$dst_dir"
        mkdir -p "$dst_dir"
        # Seed user-owned files only when missing, then sync the rest
        rsync -a --ignore-existing "$src_dir/" "$dst_dir/"
        rsync -a --delete "${STATE_EXCLUDES[@]}" "$src_dir/" "$dst_dir/"
        ok "Sincronizado: ~/.config/$name (configurações do usuário preservadas)"
    else
        [ -L "$dst_dir" ] && rm -f "$dst_dir"
        mkdir -p "$dst_dir"
        cp -rn "$src_dir/." "$dst_dir/"
        (cd "$src_dir" && find . -type f ! -name settings.json ! -name '*_data.lua' ! -name 'custom*' -exec cp --parents -f {} "$dst_dir/" \;)
        ok "Copiado: ~/.config/$name"
    fi
}

# Migração: instalação antiga "panacea" -> "zenith" (preserva configurações do usuário)
if [ "$DO_LINK" = "0" ] && [ -d "$CONF/panacea" ] && [ ! -L "$CONF/panacea" ] && [ ! -e "$CONF/zenith" ]; then
    mkdir -p "$CONF/zenith"
    cp "$CONF/panacea/settings.json" "$CONF/zenith/" 2>/dev/null || true
    ok "Migrado settings.json de ~/.config/panacea"
fi

install_dir "$SRC/zenith"    "$CONF/zenith"    "zenith"
install_dir "$SRC/hypr"      "$CONF/hypr"      "hypr"
install_dir "$SRC/foot"      "$CONF/foot"      "foot"
install_dir "$SRC/fish"      "$CONF/fish"      "fish"
install_dir "$SRC/fastfetch" "$CONF/fastfetch" "fastfetch"

if [ -f "$SRC/nano/nanorc" ]; then
    cp "$SRC/nano/nanorc" "$HOME/.nanorc"
    ok "Configuração: ~/.nanorc"
fi

# Link do Quickshell para permitir `qs -c zenith`
mkdir -p "$CONF/quickshell"
ln -sfn "$CONF/zenith" "$CONF/quickshell/zenith"
ok "Quickshell: ~/.config/quickshell/zenith configurado"

# ------------------------------------------------------------------------------
# 3. Scripts auxiliares em ~/.local/bin
# ------------------------------------------------------------------------------
step "Instalando scripts auxiliares em ~/.local/bin..."
if [ -d "$SRC/bin" ]; then
    cp "$SRC/bin/"* "$BIN_DIR/" 2>/dev/null || true
    chmod +x "$BIN_DIR/"* 2>/dev/null || true
    ok "Scripts copiados para $BIN_DIR"
fi

# Criar atalhos úteis
ln -sfn "$CONF/zenith/scripts/cheat.sh" "$BIN_DIR/cheat"
ln -sfn "$CONF/zenith/scripts/picker.sh" "$BIN_DIR/picker"
ln -sfn "$CONF/zenith/scripts/regex_gen.sh" "$BIN_DIR/regex-gen"
ok "Atalhos (cheat, picker, regex-gen) configurados"

# ------------------------------------------------------------------------------
# 4. Entradas Desktop (.desktop)
# ------------------------------------------------------------------------------
step "Instalando lançadores de aplicativos (.desktop)..."
if [ -d "$SRC/applications" ]; then
    for df in "$SRC/applications/"*.desktop; do
        [ -f "$df" ] || continue
        base="$(basename "$df")"
        sed "s|@HOME@|$HOME|g" "$df" > "$APPS_DIR/$base"
        chmod +x "$APPS_DIR/$base"
    done
    ok "Lançadores instalados em $APPS_DIR"
fi

# ------------------------------------------------------------------------------
# 5. Permissões de execução
# ------------------------------------------------------------------------------
step "Ajustando permissões executáveis..."
chmod +x "$CONF"/zenith/scripts/*.sh 2>/dev/null || true
chmod +x "$CONF"/zenith/scripts/*.py 2>/dev/null || true
chmod +x "$CONF"/hypr/scripts/*.sh 2>/dev/null || true
ok "Permissões corrigidas"

# ------------------------------------------------------------------------------
# 6. Diretório de estado compartilhado (/var/lib/zenith)
# ------------------------------------------------------------------------------
step "Configurando diretório compartilhado (/var/lib/zenith)..."
if [ -n "$SUDO" ]; then
    $SUDO mkdir -p /var/lib/zenith 2>/dev/null || true
    $SUDO chmod 777 /var/lib/zenith 2>/dev/null || true
    ok "/var/lib/zenith com permissões 777"
else
    mkdir -p /var/lib/zenith 2>/dev/null || true
    chmod 777 /var/lib/zenith 2>/dev/null || true
fi

# ------------------------------------------------------------------------------
# 7. Geradores de configurações iniciais
# ------------------------------------------------------------------------------
step "Gerando configurações de atalhos e monitores..."
if [ -x "$CONF/zenith/scripts/genbinds.sh" ]; then
    "$CONF/zenith/scripts/genbinds.sh" >/dev/null 2>&1 || true
    ok "Atalhos gerados (lua/binds_data.lua)"
fi

if [ -x "$CONF/zenith/scripts/genmonitors.sh" ]; then
    "$CONF/zenith/scripts/genmonitors.sh" >/dev/null 2>&1 || true
    ok "Configurações de monitores geradas"
fi

if [ -x "$CONF/zenith/scripts/thumbs.sh" ]; then
    "$CONF/zenith/scripts/thumbs.sh" all >/dev/null 2>&1 || true
    ok "Miniaturas de temas e papéis de parede geradas"
fi

# ------------------------------------------------------------------------------
# 8. Integração NixOS / SDDM / GRUB
# ------------------------------------------------------------------------------
if [ "$IS_NIXOS" = "1" ] && [ "$DO_NIXOS" = "1" ]; then
    step "Ambiente NixOS detectado!"
    if [ -f /etc/nixos/configuration.nix ] && [ -f "$SRC/nix/inject-config.sh" ]; then
        if ask "Deseja injetar as dependências e o módulo do Zenith no seu /etc/nixos/configuration.nix?"; then
            $SUDO "$SRC/nix/inject-config.sh" "/etc/nixos/configuration.nix" "$USER" 0 || warn "Configuração injetada (rebuild pendente)"
        fi
    fi
else
    # Configuração genérica de SDDM
    if [ "$DO_SDDM" = "1" ] && [ -d "$SRC/sddm/zenith" ] && [ -n "$SUDO" ]; then
        step "Instalando tema SDDM (Zenith)..."
        $SUDO mkdir -p /usr/share/sddm/themes
        $SUDO cp -r "$SRC/sddm/zenith" /usr/share/sddm/themes/ 2>/dev/null || true
        ok "Tema SDDM copiado para /usr/share/sddm/themes/zenith"
    fi

    # Configuração genérica de GRUB
    if [ "$DO_GRUB" = "1" ] && [ -d "$SRC/grub/zenith" ] && [ -n "$SUDO" ]; then
        step "Instalando tema GRUB (Zenith)..."
        $SUDO mkdir -p /boot/grub/themes 2>/dev/null || true
        $SUDO cp -r "$SRC/grub/zenith" /boot/grub/themes/ 2>/dev/null || true
        ok "Tema GRUB copiado para /boot/grub/themes/zenith"
    fi
fi

# ------------------------------------------------------------------------------
# Conclusão
# ------------------------------------------------------------------------------
printf '\n%s%sInstalação do Zenith concluída com sucesso!%s\n' "$OK" "$B" "$N"
cat <<EOF

Próximos passos:
  1. Recarregar o Hyprland:
     hyprctl reload
  2. Iniciar ou reiniciar a cápsula/shell:
     pkill -x qs; quickshell -c ~/.config/zenith &

Dica de atalhos rápidos:
  • Super + A              Launcher de Aplicativos
  • Super + Z              Central de Controle (Wi-Fi, Áudio, Brilho, etc.)
  • Super + I              Configurações do Zenith
  • Super + D              Gerenciador do Docker
  • Super + C              Calculadora
  • Super + Shift + C      Calendário & Eventos
  • Super + V              Histórico da Área de Transferência
  • Super + P              Gravação de Tela / Captura

EOF
