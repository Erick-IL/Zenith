-- Screens.
--
-- The remembered settings come here from settings.json via
-- zenith/scripts/genmonitors.sh - in the same way as keyboard shortcuts.
-- There is no file (first installation, someone else’s machine) - “preferred” remains, and that’s it
-- works as before.
--
-- Why is the mode set here and not just by the shell: it applies it
-- about half a second after its start, and Qt binds the timer
-- animations to the refresh rate once when the first window is created. Monitor
-- at this moment it is still set to “preferred” - via HDMI it is quite often 60 Hz,
-- even the panel is at 144. As a result, the shell spins animations at 60 Hz for the entire session
-- on a monitor that switched a long time ago. The mode must stand until it starts.
local ok, saved = pcall(require, "lua.monitors_data")
if not ok or type(saved) ~= "table" then saved = {} end

for _, m in ipairs(saved) do
    hl.monitor({
        output    = m.output,
        mode      = m.mode,
        position  = m.position or "auto",
        scale     = m.scale or 1.0,
        transform = m.transform or 0,
        vrr       = m.vrr or 0,
    })
end

-- Everything else that is connected: resolution according to the panel’s preference.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1.0,
})
