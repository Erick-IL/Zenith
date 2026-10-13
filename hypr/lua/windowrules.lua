hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name  = "no-gaps-wtv1",
    match = { float = false, workspace = "w[tv1]" },
    border_size = 0,
    rounding    = 0,
})

hl.window_rule({
    name  = "no-gaps-f1",
    match = { float = false, workspace = "f[1]" },
    border_size = 0,
    rounding    = 0,
})

hl.window_rule({
    name  = "blueberry",
    match = { class = "blueberry.py" },
    float = true,
    size  = "400 500",
    move  = "(monitor_w-410) 35",
})

hl.window_rule({
    name  = "calculator",
    match = { class = "org.gnome.Calculator" },
    float = true,
    size  = "400 500",
    move  = "(monitor_w-410) 95",
})

hl.window_rule({
    name  = "file-dialogs",
    match = { title = "^(Apri file|Open File|Salva come|Save As|Sfoglia|Library)$" },
    float = true,
    size  = "800 500",
    center = true,
})

hl.window_rule({
    name  = "portal-gtk",
    match = { class = "xdg-desktop-portal-gtk" },
    float = true,
    size  = "900 600",
    center = true,
})

hl.window_rule({
    name  = "spotify",
    match = { class = "^(Spotify|spotify)$" },
    float = true,
    size  = "800 600",
    center = true,
    workspace = "special:magic silent",
})

-- The terminal is now tiled like a regular window:
-- the first takes up the entire screen, the second stands next to it (layout dwindle).
-- The old rule forced it to float 850x650 in the center.

-- "Terminal Cascade" removed: it made already open terminals float
-- with each new window and broke the normal tiling.

-- Terminal transparency. The value is written by the shell (slider in Appearance)
-- in lua/term_data.lua; the file may not exist - then there is simply no rule and
-- the terminal remains opaque.
--
-- Linker rule, not alpha in foot.ini: foot itself reads the config
-- only at startup, and the slider would not change anything in already open windows.
-- The rule applies immediately, to everyone at once.
local ok_term, term = pcall(require, "lua.term_data")
if ok_term and term and term.opacity and term.opacity < 1 then
    hl.window_rule({
        name    = "zenith-term-opacity",
        match   = { class = "^(footclient|foot)$" },
        opacity = term.opacity,
    })
end
