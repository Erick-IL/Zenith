-- The time is 24 hours, but the language remains English.
--
-- Applications take the clock format from LC_TIME, and not from their settings: en_US
-- means "12 o'clock and AM/PM", and Telegram, calendars and everything else
-- showed 12:02 AM instead of 00:02. A separate variable, not a LANG change:
-- We change exactly the time format without touching the interface language.
hl.env("LC_TIME", "en_GB.UTF-8")

-- Cursor: Bibata Modern Classic - black, without stroke or shadows, exactly under
-- dark shell. The theme name is also needed in the variables (they are read by Xwayland and
-- programs in GTK/Qt), and in Hyprland itself - it draws the cursor itself.
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("GDK_SCALE", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
