local input_ok, input_data = pcall(require, "lua.input_data")
if not input_ok or type(input_data) ~= "table" then input_data = {} end

hl.config({
    input = {
        kb_layout  = input_data.layouts or "br,us",
        kb_variant = input_data.variants or "abnt2,",
        kb_model   = input_data.model or "abnt2",
        -- Alt+Shift switches layout
        kb_options = input_data.options or "grp:alt_shift_toggle",
        kb_rules   = "",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = {
            -- natural_scroll = true: Content follows your fingers.
            -- Thumbs up => page scrolls down.
            -- If it feels the other way around, set it to false, this is the only line.
            natural_scroll = true,
            scroll_factor = 1.0,
            disable_while_typing = true,
            tap_to_click = true,
            -- drag_lock left the button “pressed” after releasing the finger:
            -- the selection continued on its own until you tap again
            drag_lock = false,
            clickfinger_behavior = true,
        },
    },
})

-- ---------------------------------------------------------------- gestures
--
-- We use BUILT-IN Hyprland actions, not our own Lua handlers.
-- The difference is fundamental: the handler is triggered once, when the fingers are already
-- released, so the window remained in place until the last moment. Built-in gestures
-- (CCloseTrackpadGesture, CFullscreenTrackpadGesture and others) are updated
-- on every movement, and the window follows your fingers in real time.
--
-- The reverse move also works: if you don’t complete the gesture, the window will return to its place.

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "move" })

-- 3 fingers down -> the window moves down behind your fingers and closes
hl.gesture({ fingers = 3, direction = "down", action = "close" })

-- 3 fingers up -> expands to full screen
hl.gesture({ fingers = 3, direction = "up", action = "fullscreen" })

-- 4 fingers down -> unpin the window and drag it
hl.gesture({ fingers = 4, direction = "down", action = "float" })

-- The block hl.device({ name = "epic-mouse-v1", ... }) was removed intentionally: this
-- the device from the example in the Hyprland stock config, which no one has.
-- But the device settings interrupt the general one - and the one whose mouse once
-- would have been called the same, the speed slider in the settings silently did nothing
-- would. Speed and acceleration now live in the settings window (Mouse section).
