local theme = require("theme")

-- Is the NVIDIA driver worth it? A couple of settings below are only needed on it and on
-- it does worse on other video cards, so we ask the kernel, not the person:
-- The module directory exists exactly when the driver is loaded.
-- We read /proc/modules, not /sys/module/nvidia_drm/parameters/*: the latest
-- open only to root, and can be checked by a normal user through them
-- I would always answer “not NVIDIA.”
local nvidia = (function ()
    local f = io.open("/proc/modules", "r")
    if not f then return false end
    for line in f:lines() do
        if line:match("^nvidia_drm") then f:close(); return true end
    end
    f:close()
    return false
end)()

hl.config({
    general = {
        gaps_in  = theme.gaps_in,
        gaps_out = theme.gaps_out,
        border_size = theme.border_size,
        col = {
            active_border   = theme.active_border,
            inactive_border = theme.inactive_border,
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "dwindle",
    },
    decoration = {
        rounding       = theme.rounding,
        rounding_power = theme.rounding_power,
        active_opacity   = theme.active_opacity,
        inactive_opacity = theme.inactive_opacity,
        shadow = {
            enabled      = theme.shadow_enabled,
            range        = theme.shadow_range,
            render_power = theme.shadow_render_power,
            color        = theme.shadow_color,
        },
        blur = {
            enabled   = theme.blur_enabled,
            size      = theme.blur_size,
            passes    = theme.blur_passes,
            vibrancy  = theme.blur_vibrancy,
        },
    },
    animations = {
        enabled = true,
    },
})

-- Animations are now handled in lua/animations.lua
require("lua.animations").apply()

-- Layout Config
hl.config({
    dwindle = { preserve_split = true },
    master = { new_status = "master" },
    scrolling = { fullscreen_on_one_column = true },
    misc = {
        force_default_wallpaper = 0,
        disable_splash_rendering = true,
        disable_hyprland_logo   = true,
        background_color        = "rgb(000000)",
        animate_manual_resizes  = true,
        vrr                     = 1,
    },
    xwayland = { force_zero_scaling = true },
    cursor = {
        sync_gsettings_theme = true,
        inactive_timeout     = 5,
        -- We draw the cursor ourselves, rather than using a separate layer of the video card.
        --
        -- In “auto” on the NVIDIA driver, the cursor goes to the hardware layer, and it
        -- the buffer is transferred to KMS for each movement - this is visible in the log
        -- continuous ribbon “Cursor buffer imported into KMS”. From time to time
        -- the transfer gets stuck and the pointer freezes for a second or two, although
        -- the system itself is alive at this moment.
        --
        -- The software cursor is drawn along with the frame: the extra layer and its
        -- transfers disappear completely. At 144 Hz there is no difference in latency -
        -- The frame already changes every 7 ms.
        no_hardware_cursors = nvidia and true or 2,
    },
})
