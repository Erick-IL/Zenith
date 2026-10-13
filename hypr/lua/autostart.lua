local programs = require("lua.programs")

hl.on("hyprland.start", function ()
  hl.exec_cmd("foot --server")

  local zenBgRule = hl.window_rule({
      name = "zen-background-startup",
      match = { class = "zen" },
      workspace = "special:zenbg silent"
  })

  hl.timer(function()
      -- zen-browser is not installed
      -- hl.exec_cmd("zen-browser")
      hl.timer(function()
          zenBgRule:set_enabled(false)
      end, { timeout = 5000, type = "oneshot" })
  end, { timeout = 2000, type = "oneshot" })

  hl.exec_cmd("hyprpaper")
  hl.exec_cmd(programs.bar)
  hl.exec_cmd("wl-paste --type text --watch cliphist store")
  hl.exec_cmd("wl-paste --type image --watch cliphist store")
  -- nm-applet disabled: on iwd + systemd-networkd system
  -- hl.exec_cmd("nm-applet --indicator")
  -- The polkit agent is now built into the pill (PolkitAgent in shell.qml).
  -- Two agents cannot register at the same time.
  -- hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("hyprsunset -t 5000")
  -- auto-mounting flash drives and cards: without it, the “Removable” section
  -- won't appear in explorer
  hl.exec_cmd("udiskie --no-notify --no-tray")
  -- Restoring the last topic. Path via $HOME, not /home/levandoski:
  -- on someone else's machine, the hard path did not work silently, and after rebooting
  -- the theme was returned from theme.conf provided by the installer.
  hl.exec_cmd(os.getenv("HOME") .. "/.config/hypr/scripts/switch_theme.sh --restore")
  hl.exec_cmd("cliphist list | tail -n +501 | cliphist delete")
end)
