<div align="center">

<img src="assets/logo-256.png" alt="Zenith Shell" width="150">

# Zenith Shell

**One pill for everything.** Um ambiente desktop para Hyprland onde toda a interface vive em uma única cápsula dinâmica na borda da tela.

<p align="center">
  <img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-00AAAE?style=for-the-badge&logo=hyprland&logoColor=white">
  <img alt="Quickshell" src="https://img.shields.io/badge/Quickshell-7F7F7F?style=for-the-badge&logo=qt&logoColor=white">
  <img alt="NixOS" src="https://img.shields.io/badge/NixOS-5277C3?style=for-the-badge&logo=nixos&logoColor=white">
  <img alt="Arch Linux" src="https://img.shields.io/badge/Arch%20Linux-1793D1?style=for-the-badge&logo=archlinux&logoColor=white">
  <img alt="Fish Shell" src="https://img.shields.io/badge/Fish-111111?style=for-the-badge&logo=gnubash&logoColor=white">
  <img alt="Licença MIT" src="https://img.shields.io/badge/Licença-MIT-3b82f6?style=for-the-badge">
</p>

</div>

---

## ✦ Visão Geral

Sem barras espalhadas, sem bandejas poluídas e sem popups desconexos. No **Zenith Shell**, o Wi‑Fi, Bluetooth, perfis de energia, launcher de apps, notificações com som, reprodutor de mídia, gerenciador de arquivos, gerenciador de senhas (vault), docker, calculadora, calendário com alertas e a central de configurações vivem todos dentro de uma **pílula fluida**.

A cápsula abraça a borda da tela com cantos côncavos (estilo notch de hardware): sem molduras flutuantes desnecessárias, com suporte a qualquer borda (topo, fundo, esquerda ou direita), adaptando-se e girando dinamicamente.

---

## 📁 Estrutura do Repositório

```text
Zenith/
├── zenith/               # Shell Quickshell completo (QML, lógica da ilha, scripts e sons)
├── hypr/                 # Configuração Hyprland (hyprland.conf, módulos Lua e regras de janela)
├── fish/                 # Shell Fish completo (config.fish, custom.fish, funções e prompts)
├── foot/                 # Configurações do emulador de terminal Foot e temas dinâmicos
├── fastfetch/            # Temas e especificações do sistema no terminal
├── sddm/                 # Tema de tela de login para SDDM (Zenith Island Greeter)
├── grub/                 # Tema do bootloader GRUB
├── nix/                  # Módulos NixOS, Home-Manager e scripts de injeção automática
├── bin/                  # Utilitários de linha de comando (~/.local/bin)
├── applications/         # Arquivos .desktop integrados à cápsula
├── wallpapers/           # Coleção de papéis de parede integrados
├── flake.nix             # Suporte nativo a Nix Flakes
├── install.sh            # Script de instalação inteligente e modular
└── README.md             # Esta documentação
```

---

## 🚀 Instalação Rápida

Clone o repositório ou navegue até a pasta do projeto:

```bash
cd ~/Zenith
```

### 1. Instalação Padrão (Cópia para `~/.config`)
Copia as configurações diretamente para seu ambiente de usuário:
```bash
./install.sh
```

### 2. Modo Desenvolvimento (`--link`)
Cria links simbólicos de `~/.config` apontando para a pasta `~/Zenith`. Qualquer alteração feita nesta pasta refletirá instantaneamente no seu desktop:
```bash
./install.sh --link
```

### Opções do Instalador
* `--link` ou `-l`: Usa symlinks em vez de copiar arquivos físicos.
* `--no-backup`: Não cria backups automáticos com data e hora.
* `--no-sddm`: Ignora a instalação do tema de login do SDDM.
* `--no-grub`: Ignora a instalação do tema do GRUB.
* `--no-nixos`: Não altera o `/etc/nixos/configuration.nix`.
* `--yes` ou `-y`: Aceita todas as confirmações automaticamente.

---

## ❄️ Integração com NixOS

O Zenith possui módulos prontos e declarativos para o NixOS.

### Opção A: Injeção Automática
Se você já possui um NixOS configurado, basta rodar o instalador:
```bash
./install.sh
```
O instalador detectará o NixOS e injetará as dependências, o módulo `zenith.nix` e os temas de SDDM/GRUB diretamente no seu `/etc/nixos/configuration.nix`.

### Opção B: Uso Declarativo Manual
Adicione o módulo ao seu `/etc/nixos/configuration.nix`:
```nix
imports = [
  ./hardware-configuration.nix
  ./zenith.nix # ou aponte para ~/Zenith/nix/zenith.nix
];
```

E certifique-se de habilitar as permissões compartilhadas de tema:
```nix
systemd.tmpfiles.rules = [
  "d /var/lib/zenith 0777 root root -"
];
```

---

## ⌨️ Atalhos de Teclado Principais

Todos os atalhos são gerenciados centralmente e podem ser personalizados no menu de configurações (`Super + I`):

| Atalho | Ação |
|---|---|
| <kbd>Super</kbd> + <kbd>A</kbd> | **Launcher** de Aplicativos |
| <kbd>Super</kbd> + <kbd>Tab</kbd> | **Visão Geral** de Janelas (Overview) |
| <kbd>Super</kbd> + <kbd>Z</kbd> | **Central de Controle** (Wi-Fi, Bluetooth, Áudio, Brilho, Bateria) |
| <kbd>Super</kbd> + <kbd>I</kbd> | **Configurações** do Zenith |
| <kbd>Super</kbd> + <kbd>E</kbd> | **Gerenciador de Arquivos** na Cápsula |
| <kbd>Super</kbd> + <kbd>V</kbd> | Histórico da **Área de Transferência** (Clipboard) |
| <kbd>Super</kbd> + <kbd>D</kbd> | Gerenciador de Containers **Docker** |
| <kbd>Super</kbd> + <kbd>C</kbd> | **Calculadora** Rápida |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>C</kbd> | **Calendário** e Notificações de Eventos |
| <kbd>Super</kbd> + <kbd>Alt</kbd> + <kbd>W</kbd> | Previsão do **Tempo** (Weather) |
| <kbd>Super</kbd> + <kbd>P</kbd> | **Gravação de Tela** e Capturas |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>P</kbd> | **Vault** de Senhas Seguro |
| <kbd>Super</kbd> + <kbd>Shift</kbd> + <kbd>T</kbd> | Seletor de **Temas e Paletas** |
| <kbd>Super</kbd> + <kbd>.</kbd> | Seletor de **Emojis e Símbolos** |
| <kbd>Super</kbd> + <kbd>R</kbd> | Gerador e Testador de **Expressões Regulares** |
| <kbd>Super</kbd> + <kbd>L</kbd> | **Bloquear Tela** (Lock Screen) |
| <kbd>Ctrl</kbd> + <kbd>Alt</kbd> + <kbd>Del</kbd> | Menu de **Energia** (Desligar, Reiniciar, Suspender) |
| <kbd>Alt Direito</kbd> (segurar) | Digitação por Voz (**Voxtype** / Dictation) |

---

## 🎨 Temas e Paletas Dinâmicas

O Zenith analisa o papel de parede atual e extrai a cor de destaque (accent color) automaticamente, aplicando-a de forma síncrona a:
- Cápsula e painéis de controle do Quickshell;
- Bordas ativas do Hyprland;
- Esquema de cores do terminal Foot;
- Destaques do Fastfetch;
- Tela de login do SDDM (via `/var/lib/zenith/accent.qml`).

Para trocar o papel de parede ou paleta:
* Pressione `Super + Shift + T` para abrir a galeria de papéis de parede.
* Ou selecione uma paleta predefinida no menu de Aparência em `Super + I`.

---

## 🛠️ Utilitários CLI Integrados

Estes scripts são disponibilizados diretamente em `~/.local/bin/`:
- `cheat`: Pesquisa rápida de comandos e syntaxes (`cheat tar`, `cheat git`).
- `picker`: Seletor de cores na tela via conta-gotas.
- `regex-gen`: Interface interativa de regex.
- `notify`: Envio de notificações estilizadas para o sistema.
- `smart_volume.sh` / `smart_brightness.sh`: Controle inteligente com feedback visual no OSD.
- `gamemode.sh`: Desativa temporariamente efeitos e animações pesadas para jogos.

---

## 📄 Licença

Distribuído sob a licença **MIT**. Sinta-se livre para modificar, estudar e compartilhar!
