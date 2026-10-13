local programs = {}

-- What opens with what. Everything that is here is actually called from
-- keybindings.lua or autostart.lua: entries that no one looks at
-- They leave the system in silence - so there were already menus and instructions hanging here
-- on scripts that are not in the repository.
programs.terminal = "footclient"
programs.fileManagerTui = "footclient yazi" -- in the terminal, on Super+Shift+E
-- The path is absolute, without “~”: exec without a shell does not open the tilde, and the island
-- did not start silently - after logging in, a black screen remained.
--
-- QSG_RENDER_LOOP=threaded - not decoration, but frame rate. With driver
-- NVIDIA Qt itself selects “basic”, and it spins animations from a timer of 16 ms,
-- that is, exactly 60 frames, no matter what the monitor is: at 144 Hz opening
-- The islands are noticeably stepped. Threaded takes a clock from vsync and goes to
-- screen frequency (at 144 Hz - 6.94 ms per frame).
programs.bar = "env QSG_RENDER_LOOP=threaded qs -c "
               .. os.getenv("HOME") .. "/.config/zenith"   -- pill
-- Screenshot of an area using a freeze frame: the script freezes the screen with a snapshot, and then
-- he is being allocated. Otherwise, menus and hints will close before you can
-- frame them. The path is absolute: exec without a shell does not expand the tilde.
programs.screenshot = os.getenv("HOME") .. "/.config/zenith/scripts/shot.sh"
programs.browser = "firefox"
programs.lock = os.getenv("HOME") .. "/.config/zenith/scripts/lock.sh"
programs.note = "obsidian"

return programs
