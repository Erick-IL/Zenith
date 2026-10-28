-- Custom Keybindings & Shortcuts (Lua)
--
-- API: hl.bind(combo, dispatcher [, options])
-- Dispatchers live in hl.dsp — hl.dsp.exec_cmd, hl.dsp.killactive, ...
--
-- Examples:
-- hl.bind("SUPER + C", hl.dsp.exec_cmd("code"))
-- hl.bind("SUPER + B", hl.dsp.exec_cmd("brave"))
-- hl.bind("SUPER + SHIFT + Q", hl.dsp.killactive())

-- Desligar apenas com Ctrl + Botão Power (sem Ctrl não faz nada)
hl.bind("CTRL + XF86PowerOff", hl.dsp.exec_cmd("systemctl poweroff"), { locked = true })

