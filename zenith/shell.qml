import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import Quickshell.Services.SystemTray
import Quickshell.Services.Polkit
import Quickshell.Services.Pam
import Quickshell.Bluetooth
import Quickshell.Hyprland
import "Themes.js" as Themes

// One pill for everything.
//
// Collapsed: day of the week, time, charge.
// Music/video plays -> the pill turns into a media capsule
//   (cover + title + live equalizer).
// Hover -> smoothly opens: without music - Wi-Fi and Bluetooth,
//   with music - player. The cursor has left -> collapses back.
// Super+A -> application launcher in the same pill.
ShellRoot {

PanelWindow {
    id: root

    // ------------------------------------------------- saved settings
    // They live in ~/.config/zenith/settings.json and are edited using Super+I.
    // The file is read at start and re-read when external changes occur.
    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/zenith/settings.json"
        watchChanges: true
        onFileChanged: reload()
        adapter: JsonAdapter {
            property string fontFam: "JetBrainsMono Nerd Font"
            property int    fontSize: 15
            property int    iconSize: 17
            property string colFg:    "#ffffff"
            property real   mutedAlpha: 0.45
            property string colOn:    "#3b82f6"
            property int    pillH:  38
            // where the island lives: top | bottom | left | right
            property string pillPos: "top"
            // Auto-hide: the island moves off the edge and does not take up space underneath
            // itself, windows get the entire screen. Returned by pointing to
            // a narrow strip at the very edge.
            property bool   pillAutoHide: false
            // Режим оверлея: остров парит поверх окон без резервирования полосы
            property bool   pillOverlay: true
            // Остров виден при раскрытии (панель открывается отдельной плавающей карточкой)
            property bool   pillKeepVisible: false
            // Закрывать оверлей Zenith по Super+Q (иначе убивать фоновое окно)
            property bool   closeZenithFirst: true

            // Monitor settings from the Display tab, JSON view
            // {"eDP-1":{w,h,rr,scale,transform,vrr,pos}}. Hyprland doesn't have them
            // remembers: hyprctl rules the live state, and after reboot
            // config or reboot, the screen returns to its config.
            property string monOverrides: ""
            // What screen does the island live on? "auto" - on where you are now
            // focus: the island moves after the person. Otherwise exit name
            // (“eDP-1”, “DP-2”) - the island is nailed tightly to it.
            property string pillScreen: "auto"

            // ---------------------------------------------- Bar & Island
            // Cutout mode: The island fits close to the edge of the screen and
            // spreads over it with concave corners. Off - Island
            // becomes a rectangular capsule with an indentation from the edge.
            property bool   notchMode: true
            // radius of concave corner of abutment
            property int    notchFlare: 12
            // width of the collapsed island and height of the expanded panel
            property int    collapsedW: 260
            property int    expandedH: 620
            // indentation of the capsule from the edge when cutout mode is turned off
            property int    islandGap: 12
            // rounding the capsule outside the cutout mode (0 - at half height)
            property int    islandRadius: 0

            // ---------------------------------------------- Clock & Date
            property bool   clockSeconds: false
            property bool   clockWeekday: true
            // "auto" — region and time zone are taken from the system
            property string clockTz: "auto"
            property string clockDateFmt: "d MMMM"

            // ---------------------------------------------- Appearance
            // Palette theme independent of wallpaper. "default" - what it costs
            // now; the rest are listed in root.themes.
            property string themeId: "default"
            // text font and heading font
            property string fontBody: "JetBrainsMono Nerd Font"
            property string fontDisplay: "JetBrainsMono Nerd Font"
            // indentation step and small radius - all geometry is calculated from them
            property int    spacingUnit: 8
            property int    smallRadius: 10

            // ---------------------------------------------- Motion
            // Complete rejection of animations: all durations are considered zero.
            property bool   reduceMotion: false
            property int    animMove: 230      // size and position, ms
            property int    animFade: 200      // transparency and color, ms
            property int    animHover: 150     // response to pointing, ms
            property int    animBounce: 79     // oscillator flight, %

            // ---------------------------------------------- Notifications
            property bool   notifDnd: false
            property int    notifTimeout: 5000       // regular, ms
            property int    notifCritTimeout: 0      // 0 - hang until response
            property bool   notifPreview: true       // collapsed text
            property bool   notifSound: true

            // ---------------------------------------------- Lock Screen
            property int    lockBlur: 32
            property string lockHint: ""

            // ---------------------------------------------- Control Center
            // The order of quick settings tiles specified by a person.
            // Empty line - factory layout from root.ccDefault.
            property string ccLayout: ""
            // Is it possible to move the island with the mouse directly on the screen?
            property bool   pillDrag: false
            property int    panelW: 540
            property string lang: "en"        // "en" | "ru", default English
            property bool   clock12: false    // 12 hour clock with AM/PM
            // screen recording
            property int    recFps: 60
            property string recDir: "~/Videos"
            property bool   recSysAudio: false   // system sound
            property bool   recMic: false        // microphone
            property string recMicDevice: ""     // "" = default microphone
            // password manager: offer to save passwords from clipboard
            property bool   vaultCapture: true
            // explorer with a separate Hyprland window, not a pill page
            property bool   filesWindow: false
            // Show files from dot. Default yes: in home directory
            // almost everything they come into it for begins with her -
            // .config, .local, .ssh.
            property bool   filesHidden: true
            // How the explorer lays out the contents: "list" - lines with
            // small icons, size and date; "grid" - larger tiles,
            // when it is more important to recognize a file in person than to read numbers about it.
            // The switch is located next to the search, the choice is remembered.
            property string filesMode: "list"

            // Digital intensity, scale as in the NVIDIA panel: 50 - as
            // yes, 100 is the maximum. On Wayland the knob from nvidia-settings is not
            // works at all, so the color is controlled by the compositor shader.
            property int    vibrance: 50

            // ------------------------------------------------------- mouse
            // Pointer speed as understood by libinput: -1 is the slowest,
            // 0 - as is, 1 - the fastest. This is not “multiplying by two”, but
            // the curve shifts, so the step is small.
            property real   mouseSens: 0
            // Direct input: libinput stops accelerating pointer suddenly
            // movement, and the same distance on the table always gives the same
            // and the same distance across the screen. What people turn off in games for
            // “increased accuracy of pointer installation.”
            property bool   mouseRaw: false
            property string keyboardLayouts: "br,us"
            property string keyboardVariants: "abnt2,"
            property string keyboardModel: "abnt2"
            property string keyboardOptions: "grp:alt_shift_toggle"

            // Features included. When installing dotfiles, everything is available in its entirety
            // (default true); island installer turns off what man
            // didn’t mark it, and then there is no corresponding button/page in the pill,
            // and the service (notification daemon, polkit agent) is not registered -
            // so as not to argue with those already installed in the system.
            property bool   featLauncher: true
            property bool   featPlayer: true
            property bool   featWifi: true
            property bool   featBluetooth: true
            property bool   featClipboard: true
            property bool   featNotifications: true
            property bool   featCalendar: true
            property bool   featThemes: true
            property bool   featRecord: true
            property bool   featFiles: true
            property bool   featMedia: true
            property bool   featVault: true
            property bool   featLock: true
            property bool   featAudio: true
            property bool   featPowerProfiles: true
            property bool   featOsd: true
            property bool   featPowermenu: true
            property bool   featPolkit: true

            // ---------------------------------------------- Weather & Widgets
            // Key and city are empty by default: without them the weather widget is simply
            // not shown. The key is someone else’s, free and issued by mail -
            // You can’t put something of your own here.
            property string weatherKey: ""
            property string weatherCity: ""
            property string weatherUnits: "metric"   // metric | imperial
            // Weather in a collapsed island. On: it takes up space
            // small, but they look at the island more often than at the desktop,
            // which is closed with windows.
            property bool   weatherOnIsland: true
            property bool   systemLoadOnIsland: true
            property bool   calNotify: true
            property int    calNotifyMinutes: 15
            property bool   calNotifySound: true
            // Desktop widgets. Off by default: they are drawn
            // over the wallpaper and change the appearance of the desktop, and this is included
            // themselves, rather than being detected after the update.
            property bool   featWidgets: false
            property string widgetClockMode: "analog"
            property string widgetRightMode: "weather"
            property string widgetProgressMode: "day"
            // JSON string: {"Turkish":"TR","Russian":"RU"}
            property string keyboardLayoutMap: ""

            // Terminal transparency. Lives here and edits in foot.ini:
            // foot itself does not read the shell settings.
            property real   termAlpha: 0.90

            // combinations; rebuilt in lua/binds_data.lua
            property string bind_pillFeatures: "SUPER + F1"
            property string bind_pillDocker: "SUPER + D"
            property string bind_pillCalc: "SUPER + C"
            property string bind_pillCalendar: "SUPER + SHIFT + C"
            property string bind_pillWeather: "SUPER + ALT + W"
            property string bind_pillLauncher: "SUPER + A"
            property string bind_pillControls: "SUPER + Z"
            property string bind_pillSettings: "SUPER + I"
            property string bind_pillShortcuts: "SUPER + slash"
            property string bind_overview: "SUPER + Tab"
            property string bind_pillWifi: "SUPER + SHIFT + W"
            property string bind_pillBt: "SUPER + SHIFT + B"
            property string bind_pillClip: "SUPER + V"
            property string bind_pillPower: "CTRL + ALT + delete"
            property string bind_pillNotif: "SUPER + SHIFT + N"
            property string bind_pillRecord: "SUPER + P"
            property string bind_terminal: "SUPER + T"
            property string bind_terminalAlt: "SUPER + Return"
            property string bind_closeWindow: "SUPER + Q"
            property string bind_browser: "SUPER + F"
            property string bind_fullscreen: "SUPER + SHIFT + F"
            property string bind_exitHypr: "SUPER + SHIFT + M"
            property string bind_floatToggle: "SUPER + W"
            property string bind_pillVault: "SUPER + SHIFT + P"
            // Voice to text (voxtype): hold down the right Alt - speak, release -
            // inserted. Handled by the press/release pair in keybindings.lua.
            property string bind_voxDictate: "Alt_R"
            property string bind_floatCenter: "SUPER + SHIFT + Space"
            property string bind_fileManager: "SUPER + E"
            property string bind_fileManagerTui: "SUPER + SHIFT + E"
            property string bind_toggleSplit: "SUPER + J"
            property string bind_notes: "SUPER + O"
            property string bind_screenshot: "SUPER + SHIFT + S"
            property string bind_screenOff: "SUPER + SHIFT + F12"
            property string bind_packWorkspaces: "SUPER + SHIFT + A"
            property string bind_emptyWorkspace: "SUPER + Space"
            property string bind_specialWorkspace: "SUPER + S"
            property string bind_workspace1: "SUPER + 1"
            property string bind_workspace2: "SUPER + 2"
            property string bind_workspace3: "SUPER + 3"
            property string bind_workspace4: "SUPER + 4"
            property string bind_workspace5: "SUPER + 5"
            property string bind_workspace6: "SUPER + 6"
            property string bind_workspace7: "SUPER + 7"
            property string bind_workspace8: "SUPER + 8"
            property string bind_workspace9: "SUPER + 9"
            property string bind_workspace10: "SUPER + 0"
            property string bind_moveWorkspace1: "SUPER + SHIFT + 1"
            property string bind_moveWorkspace2: "SUPER + SHIFT + 2"
            property string bind_moveWorkspace3: "SUPER + SHIFT + 3"
            property string bind_moveWorkspace4: "SUPER + SHIFT + 4"
            property string bind_moveWorkspace5: "SUPER + SHIFT + 5"
            property string bind_moveWorkspace6: "SUPER + SHIFT + 6"
            property string bind_moveWorkspace7: "SUPER + SHIFT + 7"
            property string bind_moveWorkspace8: "SUPER + SHIFT + 8"
            property string bind_moveWorkspace9: "SUPER + SHIFT + 9"
            property string bind_moveWorkspace10: "SUPER + SHIFT + 0"
            property string bind_themeSwitch: "SUPER + SHIFT + T"
            property string bind_lockScreen: "SUPER + L"
            property string bind_closeMouse: "mouse:277"
            property string bind_focusLeft: "SUPER + left"
            property string bind_focusRight: "SUPER + right"
            property string bind_focusUp: "SUPER + up"
            property string bind_focusDown: "SUPER + down"
            property string bind_moveLeft: "SUPER + SHIFT + left"
            property string bind_moveRight: "SUPER + SHIFT + right"
            property string bind_moveUp: "SUPER + SHIFT + up"
            property string bind_moveDown: "SUPER + SHIFT + down"
            property string bind_resizeRight: "ALT + right"
            property string bind_resizeLeft: "ALT + left"
            property string bind_resizeUp: "ALT + up"
            property string bind_resizeDown: "ALT + down"
            property string bind_workspaceNext: "SUPER + mouse_down"
            property string bind_workspacePrevious: "SUPER + mouse_up"
            property string bind_dragWindow: "SUPER + mouse:272"
            property string bind_resizeWindowMouse: "SUPER + mouse:273"
            property string bind_micMute: "XF86AudioMicMute"
            property string bind_volumeUp: "XF86AudioRaiseVolume"
            property string bind_volumeDown: "XF86AudioLowerVolume"
            property string bind_volumeMute: "XF86AudioMute"
            property string bind_brightnessUp: "XF86MonBrightnessUp"
            property string bind_brightnessDown: "XF86MonBrightnessDown"
            property string bind_mediaNextAlt: "SUPER + XF86AudioRaiseVolume"
            property string bind_mediaPreviousAlt: "SUPER + XF86AudioLowerVolume"
            property string bind_mediaNext: "XF86AudioNext"
            property string bind_mediaPause: "XF86AudioPause"
            property string bind_mediaPlay: "XF86AudioPlay"
            property string bind_mediaPrevious: "XF86AudioPrev"
            property string bind_lidOn: "switch:on:Lid Switch"
            property string bind_lidOff: "switch:off:Lid Switch"
        }
    }
    // Factory combinations. Keep one list to “Reset”
    // returned exactly the default values.
    readonly property var defaultBinds: ({
        pillFeatures: "SUPER + F1",
        pillDocker:   "SUPER + D",
        pillCalc:     "SUPER + C",
        pillCalendar: "SUPER + SHIFT + C",
        pillWeather:  "SUPER + ALT + W",
        pillLauncher: "SUPER + A",
        pillControls: "SUPER + Z",
        pillSettings: "SUPER + I",
        pillShortcuts: "SUPER + slash",
        overview:     "SUPER + Tab",
        pillWifi:     "SUPER + SHIFT + W",
        pillBt:       "SUPER + SHIFT + B",
        pillClip:     "SUPER + V",
        pillPower:    "CTRL + ALT + delete",
        pillNotif:    "SUPER + SHIFT + N",
        pillRecord:   "SUPER + P",
        terminal:       "SUPER + T",
        terminalAlt:    "SUPER + Return",
        closeWindow:    "SUPER + Q",
        browser:        "SUPER + F",
        fullscreen:     "SUPER + SHIFT + F",
        exitHypr:       "SUPER + SHIFT + M",
        floatToggle:    "SUPER + W",
        pillVault:      "SUPER + SHIFT + P",
        voxDictate:     "Alt_R",
        floatCenter:    "SUPER + SHIFT + Space",
        fileManager:    "SUPER + E",
        fileManagerTui: "SUPER + SHIFT + E",
        toggleSplit:    "SUPER + J",
        notes:          "SUPER + O",
        screenshot:     "SUPER + SHIFT + S",
        screenOff:      "SUPER + SHIFT + F12",
        packWorkspaces: "SUPER + SHIFT + A",
        emptyWorkspace: "SUPER + Space",
        specialWorkspace: "SUPER + S",
        lockScreen:     "SUPER + L",
        workspace1: "SUPER + 1",
        workspace2: "SUPER + 2",
        workspace3: "SUPER + 3",
        workspace4: "SUPER + 4",
        workspace5: "SUPER + 5",
        workspace6: "SUPER + 6",
        workspace7: "SUPER + 7",
        workspace8: "SUPER + 8",
        workspace9: "SUPER + 9",
        workspace10: "SUPER + 0",
        moveWorkspace1: "SUPER + SHIFT + 1",
        moveWorkspace2: "SUPER + SHIFT + 2",
        moveWorkspace3: "SUPER + SHIFT + 3",
        moveWorkspace4: "SUPER + SHIFT + 4",
        moveWorkspace5: "SUPER + SHIFT + 5",
        moveWorkspace6: "SUPER + SHIFT + 6",
        moveWorkspace7: "SUPER + SHIFT + 7",
        moveWorkspace8: "SUPER + SHIFT + 8",
        moveWorkspace9: "SUPER + SHIFT + 9",
        moveWorkspace10: "SUPER + SHIFT + 0",
        themeSwitch: "SUPER + SHIFT + T",
        closeMouse: "mouse:277",
        focusLeft: "SUPER + left",
        focusRight: "SUPER + right",
        focusUp: "SUPER + up",
        focusDown: "SUPER + down",
        moveLeft: "SUPER + SHIFT + left",
        moveRight: "SUPER + SHIFT + right",
        moveUp: "SUPER + SHIFT + up",
        moveDown: "SUPER + SHIFT + down",
        resizeRight: "ALT + right",
        resizeLeft: "ALT + left",
        resizeUp: "ALT + up",
        resizeDown: "ALT + down",
        workspaceNext: "SUPER + mouse_down",
        workspacePrevious: "SUPER + mouse_up",
        dragWindow: "SUPER + mouse:272",
        resizeWindowMouse: "SUPER + mouse:273",
        micMute: "XF86AudioMicMute",
        volumeUp: "XF86AudioRaiseVolume",
        volumeDown: "XF86AudioLowerVolume",
        volumeMute: "XF86AudioMute",
        brightnessUp: "XF86MonBrightnessUp",
        brightnessDown: "XF86MonBrightnessDown",
        mediaNextAlt: "SUPER + XF86AudioRaiseVolume",
        mediaPreviousAlt: "SUPER + XF86AudioLowerVolume",
        mediaNext: "XF86AudioNext",
        mediaPause: "XF86AudioPause",
        mediaPlay: "XF86AudioPlay",
        mediaPrevious: "XF86AudioPrev",
        lidOn: "switch:on:Lid Switch",
        lidOff: "switch:off:Lid Switch"
    })

    readonly property var cfg: cfgFile.adapter
    Binding { target: Compositor; property: "keyboardLayoutMap"; value: root.cfg.keyboardLayoutMap }
    function saveCfgNow() { cfgFile.writeAdapter(); }

    // Factory values of everything that is edited in the settings window. Combinations
    // keys are not included here: they have their own list and their own reset button.
    readonly property var defaultCfg: ({
        fontFam: "JetBrainsMono Nerd Font", fontBody: "JetBrainsMono Nerd Font",
        fontDisplay: "JetBrainsMono Nerd Font", fontSize: 15, iconSize: 17,
        colFg: "#ffffff", colOn: "#ffffff", mutedAlpha: 0.45, themeId: "nothing",
        spacingUnit: 8, smallRadius: 10,
        pillH: 38, pillPos: "top", pillScreen: "auto", pillAutoHide: false, pillOverlay: true,
        pillKeepVisible: false, closeZenithFirst: true,
        pillDrag: false, panelW: 540,
        monOverrides: "",
        notchMode: true, notchFlare: 12, collapsedW: 260, expandedH: 620,
        islandGap: 12, islandRadius: 0,
        reduceMotion: false, animMove: 230, animFade: 200, animHover: 150, animBounce: 0,
        clock12: false, clockSeconds: false, clockWeekday: true,
        clockTz: "auto", clockDateFmt: "d MMMM",
        notifDnd: false, notifTimeout: 5000, notifCritTimeout: 0, notifPreview: true, notifSound: true,
        lockBlur: 32, lockHint: "",
        ccLayout: "", filesWindow: false, filesHidden: true, filesMode: "list",
        vaultCapture: true,
        vibrance: 50, mouseSens: 0, mouseRaw: false,
        keyboardLayouts: "br,us", keyboardVariants: "abnt2,", keyboardModel: "abnt2", keyboardOptions: "grp:alt_shift_toggle",
        recFps: 60, recDir: "~/Videos", recSysAudio: false, recMic: false, recMicDevice: "",
        weatherKey: "", weatherCity: "", weatherUnits: "metric",
        weatherOnIsland: false, systemLoadOnIsland: true, keyboardLayoutMap: "", featWidgets: false,
        calNotify: true, calNotifyMinutes: 15, calNotifySound: true,
        widgetClockMode: "analog", widgetRightMode: "weather", widgetProgressMode: "day",
        termAlpha: 0.90,
        uiSounds: true
    })

    // ------------------------------------------------------------------ звуки
    Process { id: pSound }

    function playSound(name) {
        if (root.cfg.uiSounds === false) return;
        var p = Quickshell.env("HOME") + "/.config/zenith/sounds/" + name + ".wav";
        pSound.command = ["sh", "-c", "command -v pw-play >/dev/null 2>&1 && pw-play --volume 1.0 \"$1\" >/dev/null 2>&1 || (command -v paplay >/dev/null 2>&1 && paplay \"$1\" >/dev/null 2>&1)", "_", p];
        pSound.running = false;
        pSound.running = true;
    }

    function resetCfg() {
        for (var k in root.defaultCfg) cfg[k] = root.defaultCfg[k];
        root.saveCfg();
    }

    // ------------------------------------------------------- screens
    // One point through which the Display tab talks to Hyprland,
    // and she is also the memory of this conversation.
    //
    // hyprctl keyword is rejected by the new (non-legacy) config parser and when
    // this exits with zero code, so before setting the monitor silently
    // didn't go anywhere. We go through hyprctl eval and hl.monitor{}, and keyword
    // We leave a fallback for old configs.
    Process { id: pMon; property string args: ""; command: ["sh", "-c", pMon.args] }

    function monCmd(n, o) {
        var mode = o.w + "x" + o.h + "@" + Number(o.rr).toFixed(2);
        var lua = "hl.monitor({ output=\"" + n + "\", mode=\"" + mode
                + "\", position=\"" + o.pos + "\", scale=" + Number(o.scale).toFixed(6)
                + ", transform=" + o.transform + ", vrr=" + (o.vrr ? 1 : 0) + " })";
        var legacy = n + "," + mode + "," + o.pos + "," + Number(o.scale).toFixed(6)
                   + ",transform," + o.transform + ",vrr," + (o.vrr ? 1 : 0);
        return "out=$(hyprctl eval '" + lua + "' 2>&1); case \"$out\" in ok*) ;; *) "
             + "hyprctl keyword monitor '" + legacy + "' ;; esac";
    }

    function monMap() {
        try { return JSON.parse(root.cfg.monOverrides || "{}") || ({}); }
        catch (e) { return ({}); }
    }

    function monApply(n, o) {
        pMon.args = root.monCmd(n, o);
        pMon.running = false;
        pMon.running = true;
        var all = root.monMap();
        all[n] = o;
        root.cfg.monOverrides = JSON.stringify(all);
        root.saveCfg();
        // The linker needs the mode even before we launch: Qt binds
        // animation timer to the update rate when it creates the first window, and
        // We're just getting started by then. We rebuild its config so that
        // the next time the monitor rose immediately at its frequency.
        genMonTimer.restart();
    }

    Process { id: pGenMon }
    Timer {
        id: genMonTimer
        interval: 400
        onTriggered: {
            pGenMon.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/zenith/scripts/genmonitors.sh"];
            pGenMon.running = false;
            pGenMon.running = true;
        }
    }

    // Roll up what you remember again: at the start of the shell and after each
    // reloading the linker config - it resets the live settings.
    function monReplay() {
        var all = root.monMap(), parts = [];
        for (var n in all) parts.push(root.monCmd(n, all[n]));
        if (!parts.length) return;
        pMon.args = parts.join("; ");
        pMon.running = false;
        pMon.running = true;
    }

    // ------------------------------------------- digital intensity
    // Counts and applies a separate script: the shader itself and knowledge also lie there
    // about how to talk to the linker. Here we just remember.
    Process { id: pVibrance }

    // The slider sends a value for every mouse movement, and every call is
    // rebuilding the shader and re-reading it by the linker. Without restraint
    // they overlap, and Hyprland catches the file in the middle of the recording. Number in
    // window changes immediately, only what the pen is on goes to the linker
    // stopped.
    Timer {
        id: vibranceFlush
        interval: 160
        onTriggered: {
            pVibrance.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/zenith/scripts/vibrance.sh set "
                + root.cfg.vibrance];
            pVibrance.running = false;
            pVibrance.running = true;
            root.saveCfg();
        }
    }

    function applyVibrance(pct) {
        root.cfg.vibrance = Math.max(0, Math.min(100, Math.round(pct)));
        vibranceFlush.restart();
    }

    // ----------------------------------------------------------- mouse
    // Via hyprctl eval for the same reason as monitor settings:
    // keyword non-legacy parser silently rejects, leaving with a zero code.
    Process { id: pInput; property string args: ""; command: ["sh", "-c", pInput.args] }
    Process {
        id: pGenInput
        command: [root.scriptDir + "/geninput.sh"]
        stderr: StdioCollector {
            onStreamFinished: {
                var message = String(text).trim();
                if (message.length) root.keyboardInputError = message;
            }
        }
    }
    property bool keyboardInputPending: false
    property string keyboardInputError: ""
    function applyKeyboardLayouts(layouts, variants, options, model) {
        var l = String(layouts).replace(/\s+/g, "");
        var v = String(variants).replace(/\s+/g, "");
        var o = String(options).replace(/\s+/g, "");
        var m = (model !== undefined && model !== null) ? String(model).replace(/\s+/g, "") : (root.cfg.keyboardModel || "abnt2");
        if (!/^[A-Za-z0-9_,+-]+$/.test(l) || l[0] === "," || l[l.length - 1] === "," || l.indexOf(",,") >= 0
                || !/^[A-Za-z0-9_,+-]*$/.test(v) || !/^[A-Za-z0-9_,:+-]*$/.test(o) || !/^[A-Za-z0-9_-]*$/.test(m)) {
            root.keyboardInputError = root.tr("Некорректные коды раскладок или параметры переключения");
            return false;
        }
        var count = l.split(",").length;
        if (/^,*$/.test(v)) v = Array(count).join(",");
        if (v.split(",").length !== count) {
            root.keyboardInputError = root.tr("Число вариантов должно совпадать с числом раскладок");
            return false;
        }
        root.keyboardInputError = "";
        root.cfg.keyboardLayouts = l;
        root.cfg.keyboardVariants = v;
        root.cfg.keyboardOptions = o;
        root.cfg.keyboardModel = m;
        root.keyboardInputPending = true;
        root.saveCfg();
        return true;
    }
    function applyInput() {
        var lua = "hl.config({ input = { sensitivity = "
                + Number(root.cfg.mouseSens).toFixed(3)
                + ", accel_profile = \"" + (root.cfg.mouseRaw ? "flat" : "adaptive") + "\""
                + " } })";
        var legacy = "hyprctl keyword input:sensitivity "
                   + Number(root.cfg.mouseSens).toFixed(3)
                   + "; hyprctl keyword input:accel_profile "
                   + (root.cfg.mouseRaw ? "flat" : "adaptive");
        pInput.args = "out=$(hyprctl eval '" + lua + "' 2>&1); "
                    + "case \"$out\" in ok*) ;; *) " + legacy + " ;; esac";
        pInput.running = false;
        pInput.running = true;
        root.saveCfg();
    }

    // Input and color settings live in the linker, but it doesn’t remember them: any
    // hyprctl reload - and everything returned to what was written in the config. Yours
    // roll it over again along with the monitor settings, one timer -
    // see monReplayTimer, it also fires at the start of the shell.

    // ------------------------------------------------- wired network
    // The cable is plugged in - the network icon should be wired, not Wi-Fi: connection
    // walks along it, and drawing an antenna on top of a working cable is incorrect.
    //
    // We look in sysfs, and do not ask NetworkManager: the system may have
    // iwd with systemd-networkd, and then NM is simply not there. The kernel knows about
    // the carrier is always on the interface, no matter who controls the network.
    //
    //   type == 1  — Ethernet (ARPHRD_ETHER);
    //   carrier - is there a link right now, that is, is the cable plugged in;
    //   wireless/ - only wireless ones have a directory, we skip them.
    //
    // We filter out bridges, docker, tunnels and virtual pairs by name: they have
    // also type 1 and their own carrier, but they are not the Internet.
    property string wiredName: ""
    readonly property bool wiredOn: root.wiredName.length > 0

    Process {
        id: pWired
        command: ["sh", "-c",
            "for d in /sys/class/net/*; do " +
            "n=${d##*/}; " +
            "[ -d \"$d/wireless\" ] && continue; " +
            "case $n in lo|docker*|veth*|br-*|virbr*|tun*|tap*|wg*|zt*|tailscale*) continue ;; esac; " +
            "[ \"$(cat $d/type 2>/dev/null)\" = 1 ] || continue; " +
            "[ \"$(cat $d/carrier 2>/dev/null)\" = 1 ] && { echo $n; exit 0; }; " +
            "done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n");
                root.wiredName = lines.length ? lines[lines.length - 1].trim() : "";
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: { pWired.running = false; pWired.running = true; }
    }

    // monospace font families for settings drop-down list
    property var fontList: ["JetBrainsMono Nerd Font"]
    Process {
        id: pFonts
        command: ["sh", "-c",
            "fc-list :spacing=100 family | tr ',' '\\n' | sed 's/^ *//' | sort -u | grep -v '^$'"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var a = text.trim().split("\n").filter(x => x.length);
                if (a.length) root.fontList = a;
            }
        }
    }

    function saveCfg() { cfgFile.writeAdapter(); }

    // Translation. The key is Russian text, so the sources remain readable,
    // and a dictionary is needed only for English; the lines themselves are in Translations.qml.
    readonly property Translations i18n: Translations {}

    readonly property string localeId: String(cfg.lang || "en")
    readonly property string languageCode: localeId.split(/[_-]/)[0].toLowerCase()
    readonly property bool isPt: languageCode === "pt" || localeId.indexOf("pt") === 0
    readonly property bool isEn: languageCode === "en" || localeId.indexOf("en") === 0
    readonly property bool isRu: languageCode === "ru" || localeId.indexOf("ru") === 0
    function tr(k) {
        if (root.languageCode === "ru") return k;
        if (root.isPt && i18n.pt && i18n.pt[k] !== undefined) return i18n.pt[k];
        if (root.languageCode === "tr" && i18n.tr && i18n.tr[k] !== undefined) return i18n.tr[k];
        return (i18n.en && i18n.en[k] !== undefined) ? i18n.en[k] : k;
    }

    // -------------------------------------------------- login screen language
    // Greeter runs as user sddm and our settings cannot be read
    // can: ~/closed. Duplicate the selected language into the general directory with the same
    // QML fragment, which is the focus of the topic - otherwise the login screen would continue
    // speak Russian after switching the system to English.
    // The directory is created by the installer; if it is not there, we do nothing in silence.
    Process {
        id: pGreeterLocale
        command: ["sh", "-c",
            "d=/var/lib/zenith; [ -w \"$d\" ] || exit 0; " +
            "printf 'import QtQuick 2.15\\nQtObject { property string lang: \"%s\" }\\n' " +
            "\"$1\" > \"$d/locale.qml\" && chmod 644 \"$d/locale.qml\"",
            "_", root.cfg.lang]
    }
    // Palette for the login screen - in the same way and in the same directory.
    //
    // Previously it was written by hypr/scripts/palette.sh from $accent_color, and this
    // a palette of terminals and editors that has nothing to do with the shell theme.
    // The coincidence was accidental: on a black and white theme, the login screen met
    // a terracotta avatar circle and the same loading circle.
    //
    // We write not just one accent, but the whole four: Nothing has its own not only
    // highlighting paint, but also text with background.
    Process {
        id: pGreeterTheme
        command: ["sh", "-c",
            "d=/var/lib/zenith; [ -w \"$d\" ] || exit 0; " +
            "printf 'import QtQuick 2.15\\nQtObject {\\n" +
            "  property color value: \"%s\"\\n" +
            "  property color fg: \"%s\"\\n" +
            "  property color muted: \"%s\"\\n" +
            "  property color bg: \"%s\"\\n}\\n' " +
            "\"$1\" \"$2\" \"$3\" \"$4\" > \"$d/accent.qml\" " +
            "&& chmod 644 \"$d/accent.qml\"",
            "_",
            String(root.colOn), String(root.colFg),
            String(root.colMuted), String(root.colBg)]
    }
    // Terminal transparency is a linker rule, not alpha in foot.ini.
    //
    // Foot itself reads its config only at startup: the slider would not change
    // nothing in the already open windows, which is where they move it, looking at
    // terminal. The Hyprland rule is applied immediately and to all windows at once.
    //
    // We write and apply: the file is needed so that the value survives the reboot -
    // windowrules.lua picks it up at startup, and eval to see
    // result now, without waiting for the next login.
    Process {
        id: pTermAlpha
        command: ["sh", "-c",
            "d=\"$HOME/.config/hypr/lua\"; mkdir -p \"$d\" || exit 0; " +
            "printf 'return { opacity = %s }\\n' \"$1\" > \"$d/term_data.lua\"; " +
            "hyprctl eval \"hl.window_rule({ name = 'zenith-term-opacity', " +
            "match = { class = '^(footclient|foot)$' }, opacity = $1 })\" >/dev/null 2>&1",
            "_", root.cfg.termAlpha.toFixed(2)]
    }
    // We hold back, just like recording brightness on the bus: the slider sends the value to
    // every mouse movement, and every one is a launch of hyprctl. They race
    // are arguing over the same call and the linker shows a banner with
    // mistake. We write when the hand stops.
    Timer {
        id: termAlphaFlush
        interval: 180
        onTriggered: {
            pTermAlpha.running = false;
            pTermAlpha.running = true;
        }
    }
    function applyTermAlpha() { termAlphaFlush.restart(); }

    // Restarting the terminal server.
    //
    // Needed where the linker rule is powerless: foot has its own alpha,
    // colors, font - the server reads all this once at startup and distributes
    // clients. You can’t just kill him: autostart works once every
    // session and will not pick up again, and without the server the terminal will stop
    // open at all. Therefore, we kill and immediately raise ourselves.
    //
    // The open windows will close - they are the clients of the deceased
    // server. This is stated on the button.
    Process {
        id: pTermRestart
        command: ["sh", "-c",
            "pkill -x foot >/dev/null 2>&1; sleep 0.4; " +
            "setsid -f foot --server >/dev/null 2>&1"]
    }
    // Run a command that survives the panel being closed.
    //
    // Process declared inside the page dies with it: menu
    // power closes the panel immediately after startup and the page is destroyed
    // at the same moment. Quick commands like systemctl took a moment
    // separate, but not blocking: its script first prepares a background from wallpaper,
    // and Process were killed before it even reached the screen. Co
    // On the other hand, it looked like a broken button.
    //
    // Here the process lives in the root of the shell, which is never destroyed,
    // so he has nowhere to rush.
    Process { id: pDetached }
    function runDetached(cmd) {
        // Through the linker, and not with your Process.
        //
        // Even an unbound setsid child did not survive the panel's closing:
        // the lock managed to reach the screen startup - this can be seen from the trace in
        // lock.log, - and then died, leaving not a line in stderr and not
        // your log file. This is what a killed process looks like, not a crashed one.
        //
        // Hyprland runs programs with its descendants - in the same way
        // how hotkeys open them - and the shell has nothing to do with it
        // parent. Then the process lives on its own.
        //
        // We escape single quotes inside the command: the path does not contain them,
        // but the command comes from outside, and a silently corrupted line is worse than an explicit one.
        if (Hyprland.usingLua) {
            var safe = String(cmd).replace(/'/g, "\\'");
            Hyprland.dispatch("hl.dsp.exec_cmd('" + safe + "')");
        } else {
            Hyprland.dispatch("exec " + String(cmd));
        }
    }

    function restartTerminalServer() {
        pTermRestart.running = false;
        pTermRestart.running = true;
    }

    // Terminal background to match the theme.
    //
    // On Nothing it matches the widget cards - the same dark gray,
    // so that the terminal is read by part of the set, and not by someone else's window. On the rest
    // themes, the file is empty, and the color remains the one specified by the general palette: it
    // edits by hand and does not know about shell themes.
    //
    // We write to our own file, and not to the one generated by palette.sh: for one
    // There are no two owners of a file without a dispute. foot.ini connects both, ours
    // second - the one connected later wins.
    readonly property string termBg: "171717"
    Process {
        id: pTermTheme
        command: ["sh", "-c",
            "f=\"$HOME/.config/foot/zenith-theme\"; mkdir -p \"$(dirname \"$f\")\" || exit 0; " +
            "if [ -n \"$1\" ]; then " +
            "printf '[colors-dark]\\nbackground=%s\\n' \"$1\" > \"$f\"; " +
            "else : > \"$f\"; fi",
            "_", root.termBg]
    }
    function syncTermTheme() {
        pTermTheme.running = false;
        pTermTheme.running = true;
    }

    function syncGreeterTheme() {
        pGreeterTheme.running = false;
        pGreeterTheme.running = true;
    }
    onThemeChanged: {
        root.syncGreeterTheme();
        root.syncTermTheme();
    }

    // ------------------------------------------------------------ language
    // The shell language changes instantly - it is its own dictionary. Language
    // the rest (applications, menus, system messages) lives in LANG and
    // requires root, so it goes through pkexec: the shell has its own polkit agent,
    // She will draw the password window herself.
    //
    // The clock remains 24-hour in any language: the format is controlled by
    // a separate variable, and the script does not touch it.
    property string sysLang: "en"
    property bool   sysLangPending: false
    function canonicalLocale(value) {
        if (value === "en") return "en_US";
        if (value === "ru") return "ru_RU";
        if (value === "tr") return "tr_TR";
        return String(value || "");
    }
    readonly property bool systemLocaleMatches: canonicalLocale(root.sysLang) === canonicalLocale(root.cfg.lang)

    Process {
        id: pLocaleGet
        running: true
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/zenith/scripts/locale.sh get"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = text.trim().split("\n").pop().trim();
                if (s.length) root.sysLang = s;
            }
        }
    }

    Process {
        id: pLocaleSet
        onExited: {
            root.sysLangPending = false;
            pLocaleGet.running = false;
            pLocaleGet.running = true;
        }
    }

    function setLang(code) {
        // The shell switches immediately, without waiting for a password: its dictionary
        // does not concern the system language, and there is nothing to expect here.
        root.cfg.lang = code;
        root.saveCfg();

        root.sysLangPending = true;
        pLocaleSet.command = ["pkexec", Quickshell.env("HOME") + "/.config/zenith/scripts/locale.sh", "set", code];
        pLocaleSet.running = false;
        pLocaleSet.running = true;
    }

    function syncGreeterLocale() {
        pGreeterLocale.running = false;
        pGreeterLocale.running = true;
    }
    // One handler per signal: QML does not allow a second one, so everything that
    // should happen at language change, collected here.
    //
    // We ask the weather again because the description in words comes from the service
    // already translated - the language is transmitted in the request. Your signature shell
    // switches immediately, but this one would remain in the same language until
    // the next survey, that is, until a quarter of an hour.
    onIsEnChanged: {
        root.syncGreeterLocale();
        if (root.cfg.featWidgets || root.cfg.weatherOnIsland) root.refreshWeather();
    }

    // Visibility of the concave corners of the island.
    //
    // They go out immediately and appear with a delay while the capsule is moving.
    // Corners are separate elements attached to its edges, and when returning from
    // settings they appeared instantly, even when the capsule was traveling to the place:
    // from the outside it looked like two stickers were flying towards the island from different
    // sides While he is driving, they are simply not there, and he arrives intact.
    readonly property bool cornersWanted:
        !(root.settingsMode || root.wallsOpen || root.pillHidden)
    property bool cornersOn: false
    Timer {
        id: cornerReveal
        interval: root.animMs + 40
        onTriggered: root.cornersOn = true
    }
    onCornersWantedChanged: {
        if (root.cornersWanted) {
            cornerReveal.restart();
        } else {
            cornerReveal.stop();
            root.cornersOn = false;
        }
    }

    // ------------------------------------ reboot to another system
    // The process lives HERE, in the root, and not in the launcher from where it is called.
    //
    // The launcher closes immediately after selection, and after animMs + 40 ms the page
    // is reset to the main one - the view is destroyed, and with it everything in
    // it was announced. Process running inside the launcher died within a quarter
    // seconds, while pkexec at this point only had time to draw the window
    // with a password. From the outside it looked exactly like “pressed and nothing happened”
    // happened": no error, no window, no reboot.
    //
    // setsid is no good here, although it would survive closing the panel: it takes away
    // process into a new session, and polkit decides whose right it is by session. Root
    // The shell lives as long as the shell itself, and that’s enough.
    Process {
        id: pBootOs
        stderr: StdioCollector {
            onStreamFinished: {
                var t = String(text).trim();
                if (t.length === 0) return;
                // This team cannot fall silently: the person is waiting for a reboot and
                // the absence of a window will not distinguish between polkit failure and the fact that
                // The pressure didn't come through at all.
                console.warn("bootos:", t);
                pBootOsSay.command = ["notify-send", "-u", "critical",
                                      root.tr("Не удалось перезагрузиться"), t];
                pBootOsSay.running = false;
                pBootOsSay.running = true;
            }
        }
    }
    Process { id: pBootOsSay }

    // ------------------------------------ open the file with the selected program
    // Lives here for the same reason as rebooting to another system:
    // Explorer closes immediately after selection, and Process declared inside
    // him, died along with the appearance - before he had time to launch the program.
    // From the outside it looked like “selected a program, the explorer closed, nothing
    // didn't open."
    Process { id: pOpenWith }
    function openFileWith(path, desktopFile) {
        if (!path) return;
        var s = root.scriptDir + "/files.sh";
        pOpenWith.command = desktopFile && desktopFile.length
            ? ["sh", "-c", s + ' open "$1" "$2"', "_", String(path), String(desktopFile)]
            : ["sh", "-c", s + ' open "$1"', "_", String(path)];
        pOpenWith.running = false;
        pOpenWith.running = true;
    }

    function bootIntoSystem(id) {
        if (!id) return;
        pBootOs.command = ["pkexec", root.scriptDir + "/bootos.sh", "boot", String(id)];
        pBootOs.running = false;
        pBootOs.running = true;
    }

    // Shell version number: this is edited by the author upon release, and the commit hash
    // next to it it says from what state of the repository the assembly was compiled.
    readonly property string version: "1.0.11"

    // ------------------------------------------------------------ update
    // The installed version is marked by the installer (~/.config/zenith/.version),
    // and update.sh checks it against the end of the branch on GitHub. The commit hash changes from
    // any edits - both from new files, and from changes in old ones, and from deletions,
    // therefore, one comparison is enough to catch everything at once.
    property string updStatus: ""      // "" | current | behind | unknown | offline
    property string updSubject: ""     // last commit header
    property string updLatest: ""      // hash on GitHub
    property string updCurrent: ""     // hash from which you bet
    property bool   updBusy: false
    property string updStep: ""
    property string updError: ""      // error code from update.sh, not text
    // which version has already been reported: one notification per release, not per review
    property string updNotified: ""

    readonly property bool updateAvailable: updStatus === "behind"

    // update.sh prints the code, not the phrase: otherwise the error text would appear on
    // script language and did not obey the selected interface language.
    readonly property string updErrorText: {
        switch (root.updError) {
        case "":         return "";
        case "nogit":    return root.tr("Не установлен git");
        case "offline":  return root.tr("Нет связи с GitHub");
        case "download": return root.tr("Не удалось скачать обновление");
        case "install":  return root.tr("Установщик завершился с ошибкой");
        default:         return root.tr("Обновление не удалось");
        }
    }

    // Is it being checked now? Separate from updBusy: update takes minutes and
    // is shown in the island, and the check takes a second or two and lives only in
    // settings window. Without this flag, clicking on “Check” did not respond with anything:
    // the answer came when the person had already decided that the button was broken - and if
    // the version turned out to be the same, nothing changed at all.
    property bool updChecking: false

    function checkUpdate() {
        if (root.updBusy || root.updChecking) return;
        root.updChecking = true;
        root.updError = "";
        pUpdCheck.running = false;
        pUpdCheck.running = true;
    }

    function applyUpdate() {
        if (root.updBusy) return;
        root.updBusy = true;
        root.updError = "";
        root.updStep = "download";
        root.updCreepAt = 0;
        // The update takes minutes and survives closing the settings: show
        // him on the island, otherwise only the open window would know about him.
        root.beginBusy(root.tr("Обновление…"), "󰚰", root.updStepPercent);
        pUpdApply.running = true;
    }

    // Update percentages are calculated based on the steps that update.sh prints:
    // It doesn’t count bytes or files, and the stages are known in advance.
    //
    // Weights, not equal shares. Stages last differently: downloading in progress
    // seconds, and saving settings and marking the version takes a fraction of a second. When
    // in equal parts the strip froze on the first seventh, and then in an instant
    // skipped the other six - that is, she galloped instead of
    // fill up. Numbers taken from measurements: clone about three seconds,
    // the installer is about one, the rest is moments.
    readonly property var updSteps: [
        { id: "download",      w: 30 },
        { id: "selfupdate",    w: 2  },
        { id: "backup",        w: 4  },
        { id: "install",       w: 16 },
        { id: "greeter",       w: 2  },
        { id: "restore",       w: 4  },
        { id: "voxtype_model", w: 15 },
        { id: "restart",       w: 4  },
        { id: "done",          w: 0  }
    ]
    readonly property real updWeightTotal: {
        var t = 0;
        for (var i = 0; i < root.updSteps.length; i++) t += root.updSteps[i].w;
        return t > 0 ? t : 1;
    }
    function updStepIndex(id) {
        for (var i = 0; i < root.updSteps.length; i++)
            if (root.updSteps[i].id === id) return i;
        return -1;
    }
    // The share of the started stage is what has accumulated before it. Inside the stage itself
    // the strip is moved by updCreep: the script does not know how long it has passed.
    readonly property int updStepPercent: {
        var i = root.updStepIndex(root.updStep);
        if (i < 0) return 0;
        var acc = 0;
        for (var k = 0; k < i; k++) acc += root.updSteps[k].w;
        return Math.round(acc * 100 / root.updWeightTotal);
    }
    // How much to give to the current stage entirely: we crawl up to this limit.
    readonly property int updStepCeil: {
        var i = root.updStepIndex(root.updStep);
        if (i < 0) return 0;
        var acc = 0;
        for (var k = 0; k <= i; k++) acc += root.updSteps[k].w;
        return Math.round(acc * 100 / root.updWeightTotal);
    }

    // The streak also creeps within the stage, without waiting for the next one.
    //
    // The longest step is downloading, and its duration depends on the connection:
    // Neither git nor the installer reports progress. Standing strip on
    // slow network reads like a stuck update. So she moves
    // herself, slowing down at the stage boundary and never crossing it: reach
    // an end before the real end would be deception.
    // Its own fractional share, not busyProgress: it’s whole, and the increment is smaller
    // units would be lost in it - the strip would get stuck at the very border, where
    // creeps up more and more slowly.
    property real updCreepAt: 0
    readonly property int updProgress: Math.max(0, Math.min(100, Math.round(root.updCreepAt)))

    Timer {
        id: updCreep
        interval: 180
        repeat: true
        running: root.updBusy && root.updStep !== "done"
        onTriggered: {
            var to = Math.max(root.updStepCeil, root.updStepPercent + 5);
            if (root.updCreepAt >= to) return;
            // the closer the boundary, the smaller the step
            var left = to - root.updCreepAt;
            root.updCreepAt = Math.min(to, root.updCreepAt + Math.max(0.3, left * 0.05));
            root.busyProgress = Math.round(root.updCreepAt);
        }
    }
    onUpdStepChanged: {
        if (!root.updBusy) return;
        // The lane does not go back: the stage could have started earlier than it crawled
        // previous, and the rollback would be read as a failure.
        if (root.updStepPercent > root.updCreepAt)
            root.updCreepAt = root.updStepPercent;
        if (root.updStep === "done") root.updCreepAt = 100;
        root.busyProgress = Math.round(root.updCreepAt);
    }

    function updParse(text, done) {
        var lines = String(text).trim().split("\n");
        for (var i = 0; i < lines.length; i++) {
            var kv = lines[i].split("=");
            if (kv.length < 2) continue;
            var k = kv[0].trim(), v = lines[i].slice(kv[0].length + 1).trim();
            if (k === "status")       root.updStatus = v;
            else if (k === "subject") root.updSubject = v;
            else if (k === "latest")  root.updLatest = v;
            else if (k === "current") root.updCurrent = v;
            else if (k === "step")    root.updStep = v;
            else if (k === "error")   root.updError = v;
            else if (k === "missing")  root.missingDeps = v;
            else if (k === "obsolete") root.obsoleteDeps = v;
            else if (k === "version") root.updCurrent = v;
        }
        if (!done) return;
        // The notification is shown once per version: the check runs on a timer,
        // and being reminded of the same thing every six hours is obsessive.
        if (root.updStatus === "behind" && root.updLatest !== root.updNotified) {
            root.updNotified = root.updLatest;
            pUpdNotify.running = true;
        }
    }

    Process {
        id: pUpdCheck
        command: [root.scriptDir + "/update.sh", "check"]
        stdout: StdioCollector { onStreamFinished: root.updParse(text, true) }
        // We remove the flag at the exit of the process, and not at the end of the output: the script can
        // fall without printing anything, and then the spinner would remain forever.
        onExited: root.updChecking = false
    }

    Process {
        id: pUpdApply
        command: [root.scriptDir + "/update.sh", "apply"]
        // Line by line, not StdioCollector.
        //
        // StdioCollector collects the entire output and gives it back in one piece when
        // the stream will close, that is, when the update has already finished. Strings
        // step= everyone arrived at once and at the very end - the strip honestly stood on
        // the whole update was zero, and then the shell was simply restarted. Move
        // work shown after its completion is not the progress of the work.
        //
        // SplitParser returns each line as soon as the script prints it.
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.updParse(data, false)
        }
        onExited: code => {
            root.updBusy = false;
            root.endBusy();
            if (code !== 0 && root.updError.length === 0)
                root.updError = "failed";
            if (code === 0) { root.updStatus = "current"; root.updStep = "done"; }
        }
    }

    // Normal desktop notification: it will be seen even when the settings window
    // is closed and will be caught by the shell's own notification service.
    // -p causes notify-send to print the notification number. He is needed
    // to then find out your own notification in the general feed: compare the text
    // it’s impossible - it’s translated, and in another language the check would silently stop
    // match.
    property int updNotifId: -1
    Process {
        id: pUpdNotify
        command: ["notify-send", "-p", "-a", "Zenith", "-i",
                  Quickshell.env("HOME") + "/.config/zenith/assets/logo-128.png",
                  root.tr("Доступно обновление Zenith"), root.updSubject]
        stdout: StdioCollector {
            onStreamFinished: root.updNotifId = parseInt(String(text).trim()) || -1
        }
    }

    // ----------------------------------------------------- "what's new"
    // update.sh puts the list of changes into .whatsnew. Shell after
    // restarting shows it once and the file is erased.
    property var whatsNew: []
    readonly property bool whatsNewOpen: whatsNew.length > 0

    FileView {
        id: whatsNewFile
        path: Quickshell.env("HOME") + "/.config/zenith/.whatsnew"
        watchChanges: true
        // The file is almost always not there, and this is not an error: it only appears
        // after the update. Without this, the log would become clogged every time it was launched.
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            var t = String(whatsNewFile.text()).trim();
            root.whatsNew = t.length ? t.split("\n").filter(x => x.trim().length) : [];
        }
        onLoadFailed: root.whatsNew = []
    }

    // The tracking clings to an existing file, but .whatsnew appears already
    // after starting the shell, if updated without restarting. Therefore
    // We reread the first half a minute ourselves.
    Timer {
        interval: 3000
        running: root.whatsNew.length === 0
        repeat: true
        triggeredOnStart: true
        property int tries: 0
        onTriggered: {
            whatsNewFile.reload();
            if (++tries > 10) running = false;
        }
    }

    // Packages that are missing after the update. It's not us who put it: update
    // comes with --no-deps, and grab packages via sudo from under the button in the settings
    // - not what is expected of him. Therefore, we simply call them on the same screen.
    property string missingDeps: ""

    // Simple copying to clipboard. Passwords go their own way - they need
    // --sensitive-data and timed cleanup, see vaultCopy().
    Process { id: pCopyText }
    function copyText(t) {
        pCopyText.running = false;
        pCopyText.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", String(t)];
        pCopyText.running = true;
    }

    FileView {
        id: missingDepsFile
        path: Quickshell.env("HOME") + "/.config/zenith/.missingdeps"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.missingDeps = String(missingDepsFile.text()).trim()
        onLoadFailed: root.missingDeps = ""
    }

    // The downside: what the shell used to install and no longer uses.
    // We won’t delete it ourselves - these are packages in a person’s system, not ours.
    property string obsoleteDeps: ""
    FileView {
        id: obsoleteDepsFile
        path: Quickshell.env("HOME") + "/.config/zenith/.obsoletedeps"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.obsoleteDeps = String(obsoleteDepsFile.text()).trim()
        onLoadFailed: root.obsoleteDeps = ""
    }

    function dismissWhatsNew() {
        root.whatsNew = [];
        root.missingDeps = "";
        root.obsoleteDeps = "";
        pWhatsNewClear.running = true;
    }
    Process {
        id: pWhatsNewClear
        command: ["sh", "-c",
                  "rm -f \"$1/.whatsnew\" \"$1/.missingdeps\" \"$1/.obsoletedeps\"", "_",
                  Quickshell.env("HOME") + "/.config/zenith"]
    }

    // The first check is not at the start: when you log in, the network still rises,
    // and the request would almost certainly fail.
    Timer { interval: 45000; running: true; onTriggered: root.checkUpdate() }
    Timer { interval: 6 * 3600 * 1000; running: true; repeat: true; onTriggered: root.checkUpdate() }

    readonly property string scriptDir:
        Quickshell.env("HOME") + "/.config/zenith/scripts"

    // capture.sh off calls this IPC so that the panel removes capture mode
    signal cancelCaptureRequested()

    // Which settings tab will open: 0 - pill, 2 - screen, 3 - keys.
    property int settingsTab: 0
    // Open settings on a section by name, not by number: numbers depend
    // from the order in the list of sections, and a new section in the middle would silently take away
    // not there. Empty line—the section is not specified.
    property string settingsSection: ""
    function openSettingsAt(sectionId) {
        root.settingsSection = sectionId;
        if (root.page !== "settings" || !root.expanded) root.togglePage("settings");
    }

    // Rebuild binds_data.lua and reread the Hyprland config
    Process { id: pGenBinds }
    // The script reads settings.json, and writing the file is asynchronous: if you run
    // it immediately after saveCfg(), it managed to read the old combination -
    // and "Apply" did not change anything. We are waiting for the signal to complete the recording.
    property bool bindsPending: false
    function applyBinds() {
        root.bindsPending = true;
        saveCfg();
        bindsFallback.restart();
    }
    function runGenBinds() {
        if (!root.bindsPending) return;
        root.bindsPending = false;
        bindsFallback.stop();
        pGenBinds.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/zenith/scripts/genbinds.sh"];
        pGenBinds.running = true;
    }
    // insurance if for some reason there is no signal about the recording
    Timer { id: bindsFallback; interval: 700; onTriggered: root.runGenBinds() }

    // The combinations live in settings.json, but Hyprland only reads the derived one
    // from it binds_data.lua. The file is located inside ~/.config/hypr, which
    // the installer replaces it entirely - and disappeared with it. Settings when
    // remained in place, so from the outside it looked as if
    // combinations are “not saved”: the Super+/ window shows its own, and pressing
    // factory ones are working. We reassemble the file if it does not exist.
    Process {
        id: pBindsHeal
        running: true
        command: ["sh", "-c",
            "[ -f \"$HOME/.config/hypr/lua/binds_data.lua\" ] "
            + "|| \"$HOME/.config/zenith/scripts/genbinds.sh\""]
    }
    Connections {
        target: cfgFile
        function onSaved() {
            root.runGenBinds();
            if (root.keyboardInputPending) {
                root.keyboardInputPending = false;
                pGenInput.running = false;
                pGenInput.running = true;
            }
        }
    }

    // ---------------------------------------------------------------- palette
    // Themes do not depend on the wallpaper: the color of the entire shell is set by the selected theme, and
    // not a picture on the table. The “default” theme is what it was before: the background is black,
    // and the text and accent are taken from the settings, so manually selected colors
    // are not going anywhere.
    readonly property var themes: Themes.list
    function themeOf(id) { return Themes.of(id); }
    readonly property var theme: themeOf(cfg.themeId)
    readonly property bool themeCustom: cfg.themeId === "default"
    // The only flag for the entire appearance of Nothing. Check cfg.themeId by string
    // in two dozen places would mean searching for them all when renaming the topic.
    readonly property bool themeNothing: cfg.themeId === "nothing"

    // Point size in numbers Nothing. It is calculated based on the font size, not specified
    // number: a person moves the point slider in the settings, and the dot clock
    // must grow along with the rest of the signatures, otherwise the island will spread apart.
    //
    // Three steps - the height of the number in pixels, the same number used to measure
    // plain text. Counted from the point with a shift, and not a fraction from it:
    // there is always a signature next to the number, and the difference between them should
    // stay the same, and not stretch with the slider.
    readonly property real dotHBig:   root.fontSize + 10   // clock in panel
    readonly property real dotHClock: root.fontSize - 1    // clock on the island
    readonly property real dotHSmall: root.fontSize - 3    // numbers with icons
    readonly property real dotHTiny:  root.fontSize - 5    // load summary

    // The color of the lettering over the accent fill. On a light accent with white
    // white can’t see anything - and on the Nothing theme the emphasis is precisely white.
    // Brightness according to Rec. 709: green eye sees much better than blue eye, and average
    // The arithmetic of the three channels is wrong on yellow and blue.
    function fgOn(c) {
        return (0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b) > 0.6
               ? root.colBg : "#ffffff";
    }

    readonly property color colBg:     theme.bg
    // with “default” the text and accent colors are left to the settings
    readonly property color colFg:     themeCustom ? cfg.colFg : theme.fg
    readonly property color colMuted:  Qt.rgba(colFg.r, colFg.g, colFg.b, cfg.mutedAlpha)
    readonly property color colLine:   Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10)
    readonly property color colHover:  Qt.rgba(colFg.r, colFg.g, colFg.b, 0.10)
    readonly property color colOn:     (cfg.colOn && cfg.colOn.length && cfg.colOn !== "theme") ? cfg.colOn : theme.on
    readonly property color colOk:     theme.ok
    readonly property color colCrit:   theme.crit

    // Colors of states that are not in the theme palette. On the theme of Nothing colored
    // there is no highlighting at all: the meaning there is carried by brightness, not shade, and
    // a lone green or blue spot among the black and white looks alien.
    // Red is the only exception, it means "attention" and not
    // decoration, and lives in the palette as colCrit.
    //
    // tint() for those colors for which it is not possible to enter a line in the palette
    // than: they occur in one or two places and mean exactly themselves.
    function tint(c) { return root.themeNothing ? root.colFg : c; }
    // amber “on pause” and “caution” - it occurs often
    readonly property color colWarn: root.tint("#fbbf24")
    readonly property string fontFam:  cfg.fontFam
    // text font and heading font; empty value - common fontFam
    readonly property string fontBody:    cfg.fontBody || cfg.fontFam
    readonly property string fontDisplay: cfg.fontDisplay || cfg.fontFam
    readonly property int fontSize:    cfg.fontSize
    readonly property int iconSize:    cfg.iconSize
    // indentation pitch and small radius: the geometry of the cards is taken into account from these
    readonly property int unit:        cfg.spacingUnit
    readonly property int radiusS:     cfg.smallRadius

    // ---------------------------------------------------------------- metrics
    readonly property int pillH: cfg.pillH      // height of rolled pill

    // Where the island hangs. The opening always goes to the center of the screen: from above -
    // down, bottom - up, left - right, right - left. It comes out on its own
    // itself, because the capsule is pressed to its edge and grows from it.
    readonly property string pillPos: {
        var p = String(cfg.pillPos || "top");
        return (p === "bottom" || p === "left" || p === "right") ? p : "top";
    }
    readonly property bool pillAtTop:    pillPos === "top"
    readonly property bool pillAtBottom: pillPos === "bottom"
    readonly property bool pillAtLeft:   pillPos === "left"
    readonly property bool pillAtRight:  pillPos === "right"
    // in lateral positions, the capsule is positioned in the center of the height, and not at the edge of the screen
    readonly property bool pillSide: pillAtLeft || pillAtRight

    // ------------------------------------------------- moving the island with the mouse
    // Toggle switch in settings; pulling the strip above the clock in open fast
    // settings. At the edge the island clings to its center, in the void -
    // returns to its place: there is nothing to cling to.
    property bool  pillDragging: false
    property real  dragDX: 0            // offset from home location, px
    property real  dragDY: 0
    // the edge that the island will attach to if you let go now
    property string dragEdge: ""

    // We select the edge according to which the center of the capsule is closest to, and only if it
    // already in her lane - a quarter of the screen. Otherwise there is nowhere to let go.
    function edgeAt(cx, cy) {
        var w = root.width, h = root.height;
        var dTop = cy, dBottom = h - cy, dLeft = cx, dRight = w - cx;
        var m = Math.min(dTop, dBottom, dLeft, dRight);
        if (m > Math.min(w, h) * 0.25) return "";
        if (m === dTop)    return "top";
        if (m === dBottom) return "bottom";
        if (m === dLeft)   return "left";
        return "right";
    }

    function dropPill() {
        var edge = root.dragEdge;
        root.pillDragging = false;
        root.dragEdge = "";
        // We remove the displacement with animation: the island moves either to a new edge,
        // or back to your place
        root.dragDX = 0;
        root.dragDY = 0;
        if (edge.length && edge !== root.pillPos) {
            cfg.pillPos = edge;
            root.saveCfg();
        }
        // We collapse and do not open until the cursor leaves and returns.
        // The new edge has a different page layout and an open panel
        // moved along with the island, leaving as they went. So the island first
        // quietly falls into place, and the panel opens by pointing it.
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
        root.collapse();
    }

    // Where exactly is the capsule now? Need a wallpaper carousel: it starts
    // the turn is exactly from the island, so she needs its coordinates.
    property real pillRectX: 0
    property real pillRectY: 0
    property real pillRectW: 0
    property real pillRectH: 0
    readonly property int panelW: cfg.panelW    // open panel width
    readonly property int gap: 5                // gap between pill and windows
    // radius of contact with the edge; outside of the cutout mode there is nothing to adjoin
    readonly property int cornerR: cfg.notchMode ? cfg.notchFlare : 0

    // Single curve: The panel flows rather than jumps.
    // The duration is set by the Motion tab. "Reduce motion" resets them all
    // at once: the movement disappears, rather than accelerates.
    readonly property bool noMotion: cfg.reduceMotion
    readonly property int animMs:   noMotion ? 0 : cfg.animMove
    readonly property int animFade: noMotion ? 0 : cfg.animFade
    readonly property int animHover: noMotion ? 0 : cfg.animHover
    // oscillator flight in fractions: 79% → 0.79 over the target
    readonly property real animBounce: noMotion ? 0 : cfg.animBounce / 100
    // flight for curves OutBack: 100% of the slider - this is noticeable, but not yet
    // rubber rebound, so the share is multiplied rather than taken as is
    readonly property real easeOvershoot: animBounce * 1.7
    readonly property int animFast: Math.round(animMs * 0.52)
    // content change (application list, new network) - short and sharp
    readonly property int animQuick: Math.round(animMs * 0.48)

    // true only while expansion/collapse or page change is in progress.
    // It is necessary that the list growth does not follow a long expansion curve.
    property bool morphing: false
    onExpandedChanged: {
        morphing = true;
        morphTimer.restart();
        // the panel is closed - we show the cards accumulated during this time
        if (!expanded) toastPump.restart();
    }
    onPageChanged:     { morphing = true; morphTimer.restart() }
    // We hold it longer than the animation itself: page height comes with a delay
    // per frame or two, and without a reserve the second step would travel along a “fast” curve.
    Timer { id: morphTimer; interval: root.animMs + 140; onTriggered: root.morphing = false }

    // ------------------------------------------------------------ UI state
    property bool expanded: false
    // "main" | "wifi" | "bt" | "battery" | "launcher"
    // main - Wi-Fi/Bluetooth/sound, track and recording tiles
    // battery - power modes and charge state
    // There is no separate player page: the playing track with buttons and bars
    // lives as a card on the main page, in the same place as everything else.
    property string page: "main"
    // what the media player shows (page "media")
    property string mediaPath: ""
    // height of the player canvas: most of the screen, but not right next to each other
    readonly property int mediaStageH: Math.round((screen ? screen.height : 1080) * 0.58)
    // The player lives in Loader and is not visible from the outside by id, so crop mode
    // keep it here: the button and the hotkey pull the same flag.
    property bool mediaCrop: false
    function mediaCropToggle() { root.mediaCrop = !root.mediaCrop; }

    // ---------------------------------------------------- adding wallpaper
    // "+" on the wallpaper page opens Explorer in selection mode: next
    // the selected picture will not open in the player, but will go to the wallpaper page,
    // where they ask to name it and save it.
    property bool   wallpaperPickMode: false
    property string wallpaperPick: ""       // the chosen path, waiting for the name
    function startWallpaperPick() {
        wallsOpen = false;
        wallpaperPickMode = true;
        togglePage("files");
    }
    function finishWallpaperPick(path) {
        wallpaperPickMode = false;
        collapse();
        wallpaperPick = path;
        openWalls();
    }
    function cancelWallpaperPick() { wallpaperPick = ""; }

    function openMedia(path) {
        if (!cfg.featMedia) return;
        root.mediaCrop = false;
        root.mediaPath = path;
        pageResetTimer.stop();
        root.page = "media";
        root.expanded = true;
        root.holdOpen = true;
    }

    // ------------------------------------------------ full screen windows
    // The pill lives in the Overlay layer and is drawn on top of everything by default.
    // While the active window is maximized to full screen, hide it entirely:
    // Keyboard shortcuts work - they open the panel
    // and the window is shown again.
    property bool fullscreenActive: false

    Process {
        id: pFullscreen
        running: !Compositor.isNiri
        command: ["sh", "-c",
            "hyprctl activewindow -j 2>/dev/null | grep -o '\"fullscreen\": *[0-9]*' | grep -o '[0-9]*$'"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!Compositor.isNiri) root.fullscreenActive = parseInt(text.trim()) > 0;
            }
        }
    }
    Timer { id: fsProbe; interval: 120; onTriggered: pFullscreen.running = true }
    // Hyprland events do not occur on all transitions (for example, when changing
    // windows inside a full-screen layer), so we’re on the safe side with a poll.
    // Survey - only insurance: the main thing comes from Hyprland events, and
    // fsProbe rechecks the state immediately after each one. Every second
    // running hyprctl with two greps cost three processes per second
    // around the clock, and caught only rare missed transitions.
    Timer {
        interval: 5000; running: !Compositor.isNiri; repeat: true; triggeredOnStart: true
        onTriggered: pFullscreen.running = true
    }

    Connections {
        target: Hyprland
        enabled: !Compositor.isNiri
        function onRawEvent(event) {
            var n = String(event.name);
            if (n === "fullscreen" || n === "activewindow" || n === "activewindowv2"
                || n === "closewindow" || n === "openwindow" || n === "workspace"
                || n === "focusedmon")
                fsProbe.restart();
            // reloading the Hyprland config erases everything we used
            if (n === "configreloaded") monReplayTimer.restart();
        }
    }
    // Reloading the config erases not only the monitor settings: speed
    // pointer, overclock and saturation shader live there and leave together
    // with them. We roll everything up in one go, otherwise after any
    // hyprctl reload mouse and color silently returned to factory settings.
    Timer {
        id: monReplayTimer
        interval: 400
        onTriggered: {
            root.monReplay();
            root.applyInput();
            pVibrance.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/zenith/scripts/vibrance.sh set "
                + root.cfg.vibrance];
            pVibrance.running = false;
            pVibrance.running = true;
        }
    }

    // One handler per signal: QML does not allow a second one, so everything that
    // should happen at startup, collected here.
    Component.onCompleted: {
        fsProbe.restart();
        syncGreeterLocale();
        monReplayTimer.restart();
        syncGreeterTheme();
        syncTermTheme();
        root.cornersOn = root.cornersWanted;
        // The first filling of the list of tables: further it is led by onWsRawChanged, and
        // it only fires when there is a change - the starting value it would
        // missed it, and before the first switch there would have been no points at all.
        root.wsList = root.wsRaw;
    }

    // ------------------------------------------------- drag and drop files
    // The source lives directly in the window, and not inside the page: the panel during
    // dragging is collapsed, its contents are destroyed, and the element
    // from inside it would drag the started drag along with it.
    Item {
        id: fileDrag
        width: 1
        height: 1
        visible: false

        property string uri: ""

        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction | Qt.MoveAction
        Drag.proposedAction: Qt.CopyAction
        Drag.mimeData: ({ "text/uri-list": fileDrag.uri,
                          "text/plain": fileDrag.uri.replace("file://", "") })
    }
    Timer {
        id: fileDragStart
        interval: 90        // let the panel move down, then start dragging
        onTriggered: fileDrag.Drag.active = true
    }

    // ------------------------------------------------------ table review
    // For the preview you need two things: window geometry (Hyprland knows it) and
    // wayland-handle (ScreencopyView uses it to take a live frame). Both are lying
    // on HyprlandToplevel, so we collect them in one list.
    property bool overviewOpen: false
    function openOverview() {
        if (Compositor.isNiri) {
            Compositor.refresh();
        } else {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
        root.overviewOpen = true;
    }
    function closeOverview() { root.overviewOpen = false; }

    // Go to the table. With the Lua config, Hyprland parses the query string as
    // Lua code, and the usual "workspace 2" fails with a syntax error -
    // We need a real dispatcher. The old form works in the normal config.
    function gotoWorkspace(id) {
        if (Compositor.isNiri) {
            Compositor.focusWorkspace(id);
        } else if (Hyprland.usingLua) {
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })");
        } else {
            Hyprland.dispatch("workspace " + id);
        }
    }
    function toggleOverview() {
        if (root.overviewOpen) closeOverview(); else openOverview();
    }

    // ------------------------------------------------------------- keys
    // The list of combinations has moved from the settings to its own window: they are rarely edited and
    // for a long time, the list is long, and keeping it in the fifth tab meant every time
    // expand the settings window to fit the largest section.
    property bool keysWindowOpen: false
    function toggleKeysWindow() { root.keysWindowOpen = !root.keysWindowOpen; }

    // ------------------------------------------------------------------ wallpaper
    // Wallpaper carousel is a separate full-screen layer, like an overview of tables:
    // you need to see the picture big, but there is no room for this in the pill.
    property bool wallsOpen: false
    function openWalls() {
        if (!cfg.featThemes) return;
        collapse();
        root.wallsOpen = true;
        // the list will be updated in the background; the screen is still the same, not empty
        root.refreshWalls();
    }
    function closeWalls() { root.wallsOpen = false; }

    // We keep the list of wallpapers here and read it in advance: the carousel should open
    // already with pictures. While the list lived inside her, for the first half a second
    // The screen said “no wallpaper found”.
    property var wallList: []
    property bool wallListReady: false
    Process {
        id: pWallList
        command: ["sh", "-c", root.scriptDir + "/themes.sh list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split("|");
                    if (p.length < 5) continue;
                    rows.push({
                        wName:   p[0],
                        wThumb:  p[1],
                        wActive: p[2] === "yes",
                        wOwn:    p[3] === "yes",
                        wPath:   p[4]
                    });
                }
                root.wallList = rows;
                root.wallListReady = true;
            }
        }
    }
    // Thumbnail of current wallpaper: Desktop layout in Settings shows
    // exactly this, and not a conditional gradient - otherwise you won’t understand how to use the layout
    // the island will be readable against its own background.
    readonly property string currentWallThumb: {
        for (var i = 0; i < wallList.length; i++) {
            if (wallList[i].wActive) return wallList[i].wThumb;
        }
        return "";
    }

    function refreshWalls() {
        pWallList.running = false;
        pWallList.running = true;
        root.refreshLiveWalls();
    }

    // ------------------------------------------------------- live wallpaper
    // Video instead of a picture in the background. List and posters in preparation
    // hypr/scripts/live_wallpaper.sh, plays mpvpaper.
    property var liveList: []
    property bool liveListReady: false
    property string liveDir: ""

    Process {
        id: pLiveDir
        command: ["bash", Quickshell.env("HOME")
                          + "/.config/hypr/scripts/live_wallpaper.sh", "dir"]
        running: true
        stdout: StdioCollector { onStreamFinished: root.liveDir = text.trim() }
    }
    Process {
        id: pLiveList
        command: ["bash", Quickshell.env("HOME")
                          + "/.config/hypr/scripts/live_wallpaper.sh", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = [];
                var lines = text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].trim().split("|");
                    if (p.length < 4) continue;
                    rows.push({
                        wName:   p[0],
                        wThumb:  p[1],          // poster; empty, not ready yet
                        wActive: p[2] === "yes",
                        wOwn:    true,          // live wallpapers are always yours
                        wPath:   p[3]
                    });
                }
                root.liveList = rows;
                root.liveListReady = true;
            }
        }
    }
    function refreshLiveWalls() {
        pLiveList.running = false;
        pLiveList.running = true;
    }
    // live wallpaper folder in Explorer: you need to put the video there
    function openLiveFolder() {
        if (root.liveDir.length === 0) return;
        root.closeWalls();
        root.openFilesAt(root.liveDir);
    }
    Timer {
        // not at the very start: when you log in there is something to do without us
        interval: 4000
        running: true
        onTriggered: root.refreshWalls()
    }
    function toggleWalls() {
        if (root.wallsOpen) closeWalls(); else openWalls();
    }

    readonly property var overviewToplevels: {
        var out = [];
        if (!root.overviewOpen) return out;
        if (Compositor.isNiri) return Compositor.toplevels;
        var all = Hyprland.toplevels ? Hyprland.toplevels.values : [];
        for (var i = 0; i < all.length; i++) {
            var t = all[i];
            if (!t) continue;
            var o = t.lastIpcObject;
            if (!o || !o.at || !o.size) continue;
            if (o.hidden || o.workspace === undefined) continue;
            out.push({
                wayland: t.wayland,
                geo: {
                    x: o.at[0], y: o.at[1], w: o.size[0], h: o.size[1],
                    ws: o.workspace.id, cls: String(o.initialClass || o.class || "")
                }
            });
        }
        return out;
    }

    // Someone has changed the files in the Explorer windows - it’s time for the rest to re-read
    // their list: they look at the same file system.
    signal filesChanged()

    // fromWindow - drag from a separate explorer window: no need to touch the pill
    // and wait for her departure too, the dragging begins immediately.
    function startFileDrag(path, fromWindow) {
        fileDrag.uri = "file://" + path;
        if (fromWindow) { fileDrag.Drag.active = true; return; }
        root.collapse();
        fileDragStart.restart();
    }

    // The height of the list in Explorer is fixed: otherwise the panel would jump on each
    // change folder, adjusting to the number of files.
    readonly property int filesListH: Math.round((screen ? screen.height : 1080) * 0.64)

    // the last folder of the explorer - so that it opens where it was closed
    property string filesDir: Quickshell.env("HOME")
    // Tray icon whose context menu is currently open ("traymenu" page).
    property var trayMenuItem: null
    // While the password is being entered or the launcher is open, the panel does not close when the mouse leaves
    property bool holdOpen: false
    // the window receives the keyboard after the page loads - we return
    // focus on the content, otherwise the arrows and Enter go into emptiness
    onHoldOpenChanged: if (holdOpen) refocusTimer.restart()
    Timer {
        id: refocusTimer
        interval: 60
        onTriggered: if (contentLoader.item) contentLoader.item.forceActiveFocus()
    }

    readonly property bool launcherOpen: expanded && page === "launcher"

    function collapse() {
        expanded = false;
        holdOpen = false;
        // We DO NOT reset the page right away: the panel is still moving down, and the replacement
        // the contents on the “home page” managed to flash. We'll reset when
        // the capsule will actually collapse.
        pageResetTimer.restart();
    }
    Timer {
        id: pageResetTimer
        interval: root.animMs + 40
        onTriggered: if (!root.expanded) { root.page = "main"; root.trayMenuItem = null; }
    }

    // Open page pinned; calling the same page again closes.
    // Which function is responsible for the page. Empty line - the page is always there
    // (main, calendar-of-clock, etc. are checked separately).
    function pageEnabled(name) {
        switch (name) {
            case "launcher":  return cfg.featLauncher;
            case "wifi":      return cfg.featWifi;
            case "bt":        return cfg.featBluetooth;
            case "clip":      return cfg.featClipboard;
            case "notif":     return cfg.featNotifications;
            case "cal":       return cfg.featCalendar;
            case "record":    return cfg.featRecord;
            case "files":     return cfg.featFiles;
            case "media":     return cfg.featMedia;
            case "vault":     return cfg.featVault;
            case "vaultsave": return cfg.featVault;
            case "audio":     return cfg.featAudio;
            case "power":     return cfg.featPowermenu;
            default:          return true;   // main, settings, auth
        }
    }

    // ------------------------------------------------- conductor separately
    // With the setting enabled, the explorer ceases to be a pill page and
    // becomes an ordinary window: Hyprland itself tiles it, it remains on
    // your desktop and transferred between them like any other. Pill
    // At the same time, it does not open and remains in its usual form.
    // There can be as many windows as you like: Super+E in windowed mode every time
    // opens another one, like any normal conductor. Closes every
    // by itself - with a cross or Esc inside it.
    property int filesWindowSeq: 0
    ListModel { id: filesWindows }

    function openFilesWindow(startDir) {
        root.filesWindowSeq++;
        filesWindows.append({ wid: root.filesWindowSeq,
                              startDir: String(startDir || "") });
    }

    // Open Explorer immediately in the desired folder - for example, in the living directory
    // wallpaper from the carousel. In windowed mode this is a new window, otherwise page
    // a pill that reads the directory on boot.
    property string filesStartDir: ""
    function openFilesAt(path) {
        var p = String(path || "");
        if (p.length === 0) return;
        if (cfg.filesWindow) { root.openFilesWindow(p); return; }
        root.filesStartDir = p;
        if (root.page === "files" && root.expanded) root.collapse();
        root.togglePage("files");
    }
    function closeFilesWindow(wid) {
        for (var i = 0; i < filesWindows.count; i++) {
            if (filesWindows.get(i).wid !== wid) continue;
            filesWindows.remove(i);
            return;
        }
    }

    // Open a subpage and pin the panel. Previously the battery page,
    // networks or devices was opened by simply assigning page, panel
    // remained loose and slammed shut as soon as you moved the cursor -
    // the list was out of reach. Return - Esc or back button.
    function openSub(name) {
        pageResetTimer.stop();
        page = name;
        expanded = true;
        holdOpen = true;
    }

    function togglePage(name) {
        if (!pageEnabled(name)) return;   // disabled by the installer - silent
        // Explorer in windowed mode does not touch the pill at all
        if (name === "files" && cfg.filesWindow) { openFilesWindow(); return; }
        if (expanded && page === name) { collapse(); return; }
        pageResetTimer.stop();
        page = name;
        expanded = true;
        holdOpen = true;
    }
    function openLauncher() {
        if (!cfg.featLauncher) return;
        pageResetTimer.stop();
        page = "launcher";
        expanded = true;
        holdOpen = true;
    }
    function closeLauncher() { collapse(); }
    function toggleLauncher() {
        if (launcherOpen) closeLauncher(); else openLauncher();
    }

    // Agents open from the launcher, like an application, with their own line in general
    // list. There is no separate button in quick settings on purpose: people go there
    // behind the switches, and this is the reference that is referred to when about it
    // remembered. Looking for it in the same place as everything else is shorter than remembering
    // another keyboard shortcut.
    // It grows with every discovery: the type of agents subscribed to this and rereads it
    // numbers. Creating a view itself is not good for this - until the page is reset
    // to the main page, reopening will reuse the already created one.
    property int agentsEpoch: 0
    function openAgents() {
        root.agentsEpoch++;
        togglePage("agents");
    }

    // ----------------------------------------------------- screen freeze
    // Path to the full screenshot that scripts/shot.sh shows on top
    // everything while the area is being selected. Empty - no layer.
    property string freezeShot: ""

    // Logical boundaries of the entire screen layout (minimum rectangle,
    // covering all monitors). The freeze frame layer stretches the image over them,
    // filmed in physical resolution - so that it fits on the screen with scale
    // one to one, and not a piece in the corner.
    readonly property rect freezeBounds: {
        var xs = Quickshell.screens;
        if (!xs || xs.length === 0) return Qt.rect(0, 0, 0, 0);
        var minx = Infinity, miny = Infinity, maxx = -Infinity, maxy = -Infinity;
        for (var i = 0; i < xs.length; i++) {
            var s = xs[i];
            minx = Math.min(minx, s.x);
            miny = Math.min(miny, s.y);
            maxx = Math.max(maxx, s.x + s.width);
            maxy = Math.max(maxy, s.y + s.height);
        }
        return Qt.rect(minx, miny, maxx - minx, maxy - miny);
    }

    // The screenshot is placed on the clipboard, and this is not visible on the screen: frame
    // the discharge disappeared - that’s all. The notification is here, not in the script, because
    // that the text is translated along with the rest of the shell.
    Process { id: pShotSay }
    function shotCopied(path: string): void {
        // Use the icon to select the photo itself: the notification shows what exactly was taken,
        // and the miss in the frame can be seen without opening the file.
        var name = String(path).split("/").pop();
        pShotSay.command = ["notify-send", "-a", "Zenith", "-i", String(path),
                            "-h", "int:transient:1",
                            root.tr("Скриншот"),
                            root.tr("В буфере обмена") + " · " + name];
        pShotSay.running = false;
        pShotSay.running = true;
        root.playSound("screenshot");
    }

    // -------------------------------------------------- notificações de eventos do calendário
    Process {
        id: pCalNotifCheck
        property var notifiedIds: ({})
        command: ["python3", "-c", `
import json, os, time
from datetime import datetime
cfg_path = os.path.expanduser("~/.config/zenith/calendar_events.json")
if not os.path.exists(cfg_path):
    print("[]")
    exit(0)
try:
    with open(cfg_path, "r", encoding="utf-8") as f:
        events = json.load(f)
    now = datetime.now()
    due = []
    for ev in events:
        d_str = ev.get("date", "")
        t_str = ev.get("time", "00:00")
        if not d_str: continue
        try:
            ev_dt = datetime.strptime(f"{d_str} {t_str}", "%Y-%m-%d %H:%M")
            diff_min = (ev_dt - now).total_seconds() / 60.0
            if -5 <= diff_min <= 30:
                due.append({
                    "id": ev.get("id"),
                    "title": ev.get("title"),
                    "date": d_str,
                    "time": t_str,
                    "diff": round(diff_min)
                })
        except Exception:
            pass
    print(json.dumps(due))
except Exception:
    print("[]")
`]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var list = JSON.parse(data.trim());
                    if (Array.isArray(list)) {
                        for (var i = 0; i < list.length; i++) {
                            var ev = list[i];
                            var evId = String(ev.id || ev.title);
                            if (!pCalNotifCheck.notifiedIds[evId]) {
                                pCalNotifCheck.notifiedIds[evId] = true;
                                var msg = ev.title + (ev.time ? " às " + ev.time : "");
                                if (ev.diff > 0) msg += " (em " + ev.diff + " min)";
                                pShotSay.command = [
                                    "notify-send", "-a", "Zenith",
                                    "-i", "appointment-soon",
                                    root.isPt ? "Lembrete de Evento" : "Event Reminder",
                                    msg
                                ];
                                pShotSay.running = false;
                                pShotSay.running = true;
                                if (root.cfg.calNotifySound) root.playSound("notification");
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: calNotifTimer
        interval: 60000
        repeat: true
        running: root.cfg.calNotify
        triggeredOnStart: true
        onTriggered: {
            pCalNotifCheck.running = false;
            pCalNotifCheck.running = true;
        }
    }

    // Settings is the only page that comes off the top edge
    // and stands in the center of the screen: there is a lot of content, at the top it was cramped.
    // Pages that come off the top edge and stand centered:
    // There is a lot of content, it is tight at the top.
    // Topics have been removed from here: the list has become narrow and lives right under the pill,
    // like networks and devices. A separate window in the middle of the screen for selecting wallpapers
    // was too heavy a gesture.
    readonly property bool settingsMode:
        expanded && (page === "settings"
                     || page === "files" || page === "media")

    // The “Keys” tab is laid out in two columns, so the window is wider:
    // the vertical list did not fit and went off the bottom edge of the screen.
    property bool wideSettings: false
    readonly property int settingsW: {
        var want = page === "files" ? Math.round((screen ? screen.width : 1920) * 0.78)
                 : page === "media" ? Math.round((screen ? screen.width : 1920) * 0.72)
                 : (wideSettings ? 1300 : 1040);
        var lim = (screen ? screen.width : 1920) - 80;
        return Math.min(want, lim);
    }

    // ------------------------------------------------------------ change of topic
    // hyprpaper changes wallpaper instantly and without transition. Therefore a snapshot of the old
    // wallpaper remains hanging on top of the screen and melts smoothly - from below to this
    // they are now new, and you get an honest crossfade without changing the backend.
    property string themeFadeWall: ""
    property bool   themeFading: false

    FileView {
        id: curWallFile
        path: Quickshell.env("HOME") + "/.config/hypr/wallpaper.conf"
        blockLoading: true
    }

    function startThemeFade() {
        var m = /^\$wallpaper\s*=\s*(.+)$/m.exec(curWallFile.text() || "");
        if (!m) return;
        root.themeFadeWall = "file://" + String(m[1]).trim();
        root.themeFading = true;
    }
    function endThemeFade() { root.themeFading = false; }

    // ------------------------------------------------------------------ media
    // “Sticky” current player: as long as the selected player still exists, we hold on
    // for him, even when during a pause he ceases to be “playing”. Otherwise on
    // pause, the selection jumped to another MPRIS source (for example, a tab
    // browser without a cover) - and the cover/title blinked.
    // We keep the previous choice in a regular object, and not in a property: binding
    // player reads it and immediately writes into it. With the property it was
    // binding loop - Qt cursed in the log and recalculated the selection on each frame
    // playing. A field inside an object does not create dependencies.
    readonly property var stickyBox: ({ p: null })
    readonly property var player: {
        var list = Mpris.players ? Mpris.players.values : [];
        var playing = null, any = null, stickyAlive = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p) continue;
            if (!any) any = p;
            if (p === root.stickyBox.p) stickyAlive = p;
            if (p.isPlaying && !playing) playing = p;
        }
        // the player wins; otherwise the former, if he is still alive; otherwise any
        return playing || stickyAlive || any;
    }
    onPlayerChanged: { if (player) root.stickyBox.p = player; refreshMediaArt(); }
    readonly property bool mediaActive:
        cfg.featPlayer
        && player !== null && player !== undefined
        && String(player.trackTitle).trim().length > 0

    // The cover was blinking: when paused/resumed, MPRIS appears blank for a moment
    // trackArtUrl, and the image in the capsule disappeared. Remember the last one
    // non-empty cover of the current track and show it until the track changes.
    property string mediaArt: ""
    property string mediaArtTrack: ""
    function refreshMediaArt() {
        if (!player) { return; }
        var title = String(player.trackTitle || "");
        var art = String(player.trackArtUrl || "");
        // An empty title flashes momentarily during a pause—such “half-frames”
        // we ignore it so as not to discard the cover into the note.
        if (title.length === 0) return;
        if (title !== root.mediaArtTrack) {
            root.mediaArtTrack = title;
            root.mediaArt = art;           // new track - take what we have
        } else if (art.length > 0) {
            root.mediaArt = art;           // the same track - update only with non-empty
        }
    }
    Connections {
        target: root.player
        ignoreUnknownSignals: true
        function onTrackArtUrlChanged() { root.refreshMediaArt(); }
        function onTrackTitleChanged()  { root.refreshMediaArt(); }
        function onPostTrackChanged()   { root.refreshMediaArt(); }
        // When paused/resumed, the player sometimes retransmits metadata - at the same time
        // re-read the cover so that it does not disappear after the resume.
        function onIsPlayingChanged()   { root.refreshMediaArt(); }
    }

    // ---------------------------------------------------------------- battery
    // Battery via UPower: properties come via D-Bus signals, so
    // The icon changes immediately when charging is connected and disconnected.
    // Previously, /sys was polled here every 20 seconds - hence the delay.
    readonly property var battDev: UPower.displayDevice

    readonly property int batteryPct:
        battDev && battDev.ready ? Math.round(battDev.percentage * 100) : 100

    readonly property bool batteryCharging:
        battDev && battDev.ready && battDev.state === UPowerDeviceState.Charging

    readonly property bool acOnline: !UPower.onBattery

    // Charging - lightning. From the mains without charging - plug.
    // Otherwise, a regular battery with percentage filling (step 10).
    readonly property var battIcons: [
        0xF008E, 0xF007A, 0xF007B, 0xF007C, 0xF007D, 0xF007E,
        0xF007F, 0xF0080, 0xF0081, 0xF0082, 0xF0079]

    // Only the level, without replacing the zipper: in Quick settings the zipper is
    // a separate icon next to it, and the battery itself should show the charge.
    readonly property string batteryLevelIcon:
        String.fromCodePoint(battIcons[Math.max(0, Math.min(10, Math.round(batteryPct / 10)))])

    // Is there a battery at all? On a desktop, hide the charge block entirely.
    //
    // By list of devices, not by summary displayDevice: on desktop
    // it’s also “ready” to the machine, it just returns zero, and the island was honestly drawn
    // “0%” where there is no battery at all.
    //
    // We are looking for the system battery (isLaptopBattery). Battery type carry and
    // mouse and keyboard - their charge has nothing to do with powering the machine, and
    // showing it in the island as a computer charge would be incorrect.
    readonly property bool batteryPresent: {
        var list = UPower.devices ? UPower.devices.values : [];
        for (var i = 0; i < list.length; i++) {
            var d = list[i];
            if (d && d.ready && d.isLaptopBattery) return true;
        }
        return false;
    }

    // ------------------------------------------------------------- car
    // A laptop or PC is a question of hardware, not settings, so don’t ask about
    // than: the battery, the touchpad and the way to control the brightness are simply there or their
    // No. Brightness.sh is being parsed, here is only the result.
    //
    // We take the battery from UPower (it is already connected and monitors the appearance of
    // devices), the rest - a one-time survey at the start: touchpad and monitor in
    // do not appear on a running system.
    property string brightBackend: "none"   // backlight | ddc | none
    property bool   hasTouchpad: false
    property bool   ddcutilPresent: false
    readonly property bool isLaptop: root.batteryPresent
    // On a PC we hide what only applies to a laptop: charge, profiles
    // power supply and touchpad settings. It is more honest to remove empty sections than
    // show eternal zeros.
    readonly property bool showBattery: root.batteryPresent
    readonly property bool showPowerProfiles: root.batteryPresent && root.cfg.featPowerProfiles

    Process {
        id: pMachine
        running: true
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/zenith/scripts/brightness.sh detect"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.slice(text.lastIndexOf("backend="));
                t.trim().split("\n").forEach(function (line) {
                    var p = line.split("=");
                    if (p.length !== 2) return;
                    if (p[0] === "backend")  root.brightBackend  = p[1].trim();
                    if (p[0] === "touchpad") root.hasTouchpad    = p[1].trim() === "1";
                    if (p[0] === "ddcutil")  root.ddcutilPresent = p[1].trim() === "1";
                });
                // The list of screens is needed by the panel itself, not just the tab
                // Display: the brightness track is in quick settings and
                // should be there from the first disclosure, and not after
                // a person once looked into the screen settings.
                root.brightRefresh(false);
            }
        }
    }

    // ---------------------------------------------------------- weather
    // We keep the numbers in lines exactly as the service gave them: round and
    // it’s up to the widget to sign, but here it’s important to distinguish “zero degrees” from
    // “Haven’t asked yet.” An empty line means “no data”.
    property string weatherTemp: ""
    property string weatherFeels: ""
    property string weatherHumidity: ""
    property string weatherPressure: ""
    property string weatherWind: ""
    property string weatherClouds: ""
    property string weatherCond: ""      // Clouds, Rain, Clear …
    property string weatherDesc: ""      // in words, in shell language
    property string weatherIcon: ""      // type code 04d - the icon is taken from it
    property string weatherPlace: ""     // what the city called the service itself
    property string weatherErr: ""       // empty - everything is ok
    property bool   weatherBusy: false

    readonly property bool weatherReady:
        root.weatherErr.length === 0 && root.weatherTemp.length > 0
    // The degree is written the same in both systems; they differ in scale, and
    // I’m not familiar, so the letter is needed only where it is explicitly asked.
    readonly property string weatherUnitLetter:
        root.cfg.weatherUnits === "imperial" ? "F" : "C"
    // The unit of wind speed is also the signature under the number in the circle, so
    // is translated here, and does not remain in Latin on the Russian interface.
    readonly property string weatherWindUnit:
        root.cfg.weatherUnits === "imperial" ? (root.languageCode === "ru" ? "миль/ч" : "mph")
                                             : (root.languageCode === "ru" ? "м/с" : root.languageCode === "tr" ? "m/sn" : "m/s")

    // The weather icon is a font symbol - for topics where there are no dot icons.
    // The code parsing is the same as in DotIcon: the first two digits are the weather itself.
    readonly property string weatherGlyph: {
        var k = String(root.weatherIcon).slice(0, 2);
        return String.fromCodePoint(
              k === "01" ? 0xF0599                        // sun
            : k === "02" ? 0xF0595                        // sun behind the cloud
            : (k === "03" || k === "04") ? 0xF0590         // cloud
            : (k === "09" || k === "10") ? 0xF0597         // rain
            : k === "11" ? 0xF0593                        // thunderstorm
            : k === "13" ? 0xF0598                        // snow
            : k === "50" ? 0xF0591                        // fog
                         : 0xF0590);
    }

    Process {
        id: pWeather
        stdout: StdioCollector {
            onStreamFinished: {
                root.weatherBusy = false;
                // The collector accumulates the output of all runs in a row: take the last one
                // portion, not the beginning of the text.
                var txt = String(text);
                var cut = txt.lastIndexOf("temp=");
                var errCut = txt.lastIndexOf("err=");
                if (errCut > cut) cut = errCut;
                if (cut > 0) txt = txt.slice(cut);

                var got = {};
                txt.trim().split("\n").forEach(function (line) {
                    var i = line.indexOf("=");
                    if (i > 0) got[line.slice(0, i)] = line.slice(i + 1).trim();
                });

                root.weatherErr = got["err"] || "";
                if (root.weatherErr.length) return;

                root.weatherTemp     = got["temp"]     || "";
                root.weatherFeels    = got["feels"]    || "";
                root.weatherHumidity = got["humidity"] || "";
                root.weatherPressure = got["pressure"] || "";
                root.weatherWind     = got["wind"]     || "";
                root.weatherClouds   = got["clouds"]   || "";
                root.weatherCond     = got["cond"]     || "";
                root.weatherDesc     = root.translateWeatherDesc(got["desc"] || "");
                root.weatherIcon     = got["icon"]     || "";
                root.weatherPlace    = got["city"]     || "";
            }
        }
    }

    function translateWeatherDesc(desc) {
        if (!desc) return "";
        if (!root.isPt) return desc;
        var map = {
            "clear sky": "Céu limpo",
            "clear": "Céu limpo",
            "mainly clear": "Predominantemente limpo",
            "partly cloudy": "Parcialmente nublado",
            "overcast": "Nublado",
            "overcast clouds": "Nublado",
            "broken clouds": "Parcialmente nublado",
            "scattered clouds": "Nuvens dispersas",
            "few clouds": "Poucas nuvens",
            "clouds": "Nublado",
            "cloudy": "Nublado",
            "fog": "Nevoeiro",
            "drizzle": "Garoa",
            "light intensity drizzle": "Garoa leve",
            "heavy intensity drizzle": "Garoa forte",
            "rain": "Chuva",
            "light rain": "Chuva fraca",
            "moderate rain": "Chuva moderada",
            "heavy rain": "Chuva forte",
            "heavy intensity rain": "Chuva forte",
            "very heavy rain": "Chuva muito forte",
            "extreme rain": "Chuva extrema",
            "freezing rain": "Chuva congelante",
            "rain showers": "Pancadas de chuva",
            "light intensity shower rain": "Pancadas de chuva leve",
            "shower rain": "Pancadas de chuva",
            "heavy intensity shower rain": "Pancadas de chuva forte",
            "thunderstorm": "Tempestade",
            "thunderstorm with light rain": "Tempestade com chuva fraca",
            "thunderstorm with rain": "Tempestade com chuva",
            "thunderstorm with heavy rain": "Tempestade com chuva forte",
            "snow": "Neve",
            "light snow": "Neve fraca",
            "heavy snow": "Neve forte",
            "mist": "Névoa",
            "haze": "Neblina",
            "smoke": "Fumaça",
            "dust": "Poeira",
            "sand": "Areia"
        };
        var lower = String(desc).toLowerCase().trim();
        return map[lower] || desc;
    }

    function refreshWeather() {
        if (!root.cfg.weatherCity.length) {
            root.weatherErr = "no-city";
            return;
        }
        root.weatherBusy = true;
        pWeather.command = ["sh", "-c",
            root.scriptDir + "/weather.sh \"$1\" \"$2\" \"$3\" \"$4\"", "_",
            String(root.cfg.weatherKey), String(root.cfg.weatherCity),
            String(root.cfg.weatherUnits), ["ru", "tr"].indexOf(root.languageCode) >= 0 ? root.languageCode : (root.isPt ? "pt" : "en")];
        pWeather.running = false;
        pWeather.running = true;
        root.refreshWeatherForecast();
    }

    // ------------------------------------------------ детальный прогноз погоды
    property bool weatherDetailsOpen: false
    property var  weatherForecastData: null
    readonly property var weatherForecast: root.weatherForecastData
    property bool weatherExpanded: true

    Process {
        id: pWeatherForecast
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed && !parsed.err) {
                        root.weatherForecastData = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    function openWeatherDetails() {
        root.weatherDetailsOpen = false;
        root.refreshWeatherForecast();
        root.togglePage("weather");
    }

    function refreshWeatherForecast() {
        pWeatherForecast.command = ["sh", "-c",
            root.scriptDir + "/weather_forecast.sh \"$1\" \"$2\" \"$3\" \"$4\"", "_",
            String(root.cfg.weatherKey), String(root.cfg.weatherCity),
            String(root.cfg.weatherUnits), ["ru", "tr"].indexOf(root.languageCode) >= 0 ? root.languageCode : (root.isPt ? "pt" : "en")];
        pWeatherForecast.running = false;
        pWeatherForecast.running = true;
    }

    // Once every quarter of an hour. More often there is no need: the weather doesn’t change that much, but
    // free key has a limit on calls per minute, which is divided between
    // all the programs in which it was entered.
    Timer {
        interval: 900000
        running: (root.cfg.featWidgets || root.cfg.weatherOnIsland)
                 && (root.cfg.weatherCity.length > 0 || root.cfg.weatherKey.length > 0)
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshWeather()
    }

    // --------------------------------------------------------- load
    // Summary for quick settings on the Nothing theme. Minus means "measure"
    // didn't work": the line is then hidden rather than showing zero. Zero is lying here
    // too convincing - “video card is idle” and “no sensor” by eye
    // indistinguishable.
    property int loadCpu:  -1
    property int loadMem:  -1
    property int loadGpu:  -1
    property int loadTempCpu: -1
    property int loadTempGpu: -1
    property int loadDisk: -1

    // We interview only while the panel is open and only on the topic where this
    // there is a summary. A constant process every two seconds for the sake of numbers, which
    // no one sees, there is no charge: the script wakes up nvidia-smi, and that
    // It wakes up noticeably longer than the file is read.
    readonly property bool loadWanted: root.expanded || root.cfg.systemLoadOnIsland || root.cfg.featWidgets

    Process {
        id: pLoad
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/zenith/scripts/sysload.sh" + ((root.expanded || root.cfg.systemLoadOnIsland || root.cfg.featWidgets) ? "" : " --fast")]
        stdout: StdioCollector {
            onStreamFinished: {
                // The collector accumulates the output of all runs in a row, so we take
                // the last completed line, not the beginning of the text.
                var recs = String(text).trim().split("\n").filter(r => r.indexOf("|") >= 0);
                if (!recs.length) return;
                var a = recs[recs.length - 1].split("|");
                function num(s) {
                    s = String(s || "").trim();
                    return s.length ? (+s) : -1;
                }
                if (root.expanded || root.cfg.systemLoadOnIsland) {
                    root.loadCpu = num(a[0]);
                    root.loadMem = num(a[1]);
                    root.loadGpu = num(a[2]);
                    root.loadTempCpu = num(a[3]);
                    root.loadTempGpu = num(a[4]);
                    root.loadDisk = num(a[5]);
                } else {
                    root.loadMem = num(a[1]);
                    root.loadDisk = num(a[5]);
                }
            }
        }
    }

    Timer {
        interval: root.expanded ? 2000 : 5000
        running: root.loadWanted
        repeat: true
        triggeredOnStart: true
        // Restart via reset: assigning running = true while the process is running
        // has not yet been marked as completed, does nothing, and the readings
        // would freeze in the first picture.
        onTriggered: { pLoad.running = false; pLoad.running = true; }
    }

    // ------------------------------------------------------------- brightness
    // [{ id, name, pct }] - screens whose brightness is generally controlled.
    // An empty list on a PC means “the monitor is not responding via DDC/CI”, and the tab
    // Display says this in words instead of a dead slider.
    property var brightList: []
    property bool brightBusy: false

    Process {
        id: pBrightList
        command: ["sh", "-c", Quickshell.env("HOME") + "/.config/zenith/scripts/brightness.sh list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                text.trim().split("\n").forEach(function (line) {
                    var p = line.split("\t");
                    if (p.length < 3) return;
                    var pct = parseInt(p[2]);
                    if (isNaN(pct)) return;
                    out.push({ id: p[0], name: p[1], pct: pct });
                });
                root.brightList = out;
                root.brightBusy = false;
            }
        }
    }

    function brightRefresh(rescan) {
        if (root.brightBackend === "none") return;
        root.brightBusy = true;
        pBrightList.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/zenith/scripts/brightness.sh "
            + (rescan ? "rescan" : "list")];
        pBrightList.running = false;
        pBrightList.running = true;
    }

    // DDC recording occurs over I2C and takes tens of milliseconds, and the slider
    // sends values for every mouse movement. Without restraint the tire gets clogged
    // in turn, the monitor lags behind the handle and catches up with it a second after
    // letting go. We accumulate the last value and send it no more often than the bus
    // manages to digest.
    Process { id: pBrightSet }
    property string brightPendingId: ""
    property int    brightPendingPct: -1

    Timer {
        id: brightFlush
        // We wait for a pause in movement, rather than sending every N ms. One DDC entry
        // takes tens of milliseconds, the monitor blinks the backlight at it, and
        // a queue of intermediate values turned dragging the slider into
        // flashing with lag. Only what the pen stopped at goes away.
        interval: 180
        repeat: false
        onTriggered: {
            if (root.brightPendingPct < 0) return;
            pBrightSet.command = ["sh", "-c",
                Quickshell.env("HOME") + "/.config/zenith/scripts/brightness.sh set "
                + root.brightPendingId + " " + root.brightPendingPct];
            pBrightSet.running = false;
            pBrightSet.running = true;
            root.brightPendingPct = -1;
        }
    }

    function brightSet(id, pct) {
        pct = Math.max(1, Math.min(100, Math.round(pct)));
        // We show it right away, without waiting for the monitor: the slider must be at hand
        // walk without delay, even when the bus responds slowly.
        var l = root.brightList.slice();
        for (var i = 0; i < l.length; i++)
            if (l[i].id === id) l[i] = { id: id, name: l[i].name, pct: pct };
        root.brightList = l;

        root.brightPendingId = id;
        root.brightPendingPct = pct;
        brightFlush.restart();
    }

    // Details for the Battery page: capacity, wear and current consumption.
    // There are no forecasts of “how much is left” here - UPower is recalculating
    // their jerks, and the figure jumped before our eyes.
    readonly property real batteryHealth:
        battDev && battDev.ready ? Math.round(battDev.healthPercentage) : 0
    readonly property real batteryCapacity:
        battDev && battDev.ready ? battDev.energyCapacity : 0
    // W: positive - charge, negative - discharge
    readonly property real batteryRate:
        battDev && battDev.ready ? battDev.changeRate : 0

    readonly property string batteryIcon: {
        // Charging - lightning. From the mains without charging - a regular battery,
        // differs only in color (green), without a socket icon.
        if (batteryCharging) return String.fromCodePoint(0xF0241);
        var step = Math.max(0, Math.min(10, Math.round(batteryPct / 10)));
        return String.fromCodePoint(battIcons[step]);
    }

    // ---------------------------------------------------------------- polkit
    // Requesting a password when installing packages and other privileged
    // actions are drawn in the pill, and not in a separate agent window.
    property var authFlow: null
    readonly property bool authActive: authFlow !== null && !authFlow.isCompleted

    // The polkit agent is also in Loader: it is disabled by the installer, which means the island is not
    // is registered by the agent and the place remains with the one already installed
    // (hyprpolkitagent, etc.); polkit only allows one per session.
    Loader {
        active: root.cfg.featPolkit
        sourceComponent: PolkitAgent {
            onAuthenticationRequestStarted: {
                root.authFlow = flow;
                pageResetTimer.stop();
                root.page = "auth";
                root.expanded = true;
                root.holdOpen = true;
            }
        }
    }

    Connections {
        target: root.authFlow
        ignoreUnknownSignals: true
        function onIsCompletedChanged() {
            if (root.authFlow && root.authFlow.isCompleted) {
                root.authFlow = null;
                root.collapse();
            }
        }
    }

    // ---------------------------------------------------------------- don't sleep
    // While the toggle switch is on, systemd-inhibit holds the lock: the system does not
    // falls asleep and does not turn off the screen. Quickshell itself kills the process when shutting down.
    property bool keepAwake: false
    Process {
        running: root.keepAwake
        command: ["systemd-inhibit", "--what=idle:sleep:handle-lid-switch",
                  "--who=Zenith", "--why=Keep awake", "sleep", "infinity"]
    }

    // ------------------------------------------------------- sound: devices
    // List of outputs and switching between them. Change device before
    // there was nothing: pavucontrol is not in the system.
    readonly property var audioSinks: {
        var out = [];
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isSink && !n.isStream) out.push(n);
        }
        return out;
    }
    // Список активных аудиопотоков приложений (раздельный микшер)
    readonly property var audioStreams: {
        var out = [];
        var all = Pipewire.nodes ? Pipewire.nodes.values : [];
        for (var i = 0; i < all.length; i++) {
            var n = all[i];
            if (n && n.isStream && n.audio) {
                var props = n.properties || {};
                var name = String(props["application.name"] || props["media.name"] || n.name || "").toLowerCase();
                if (name.indexOf("cava") < 0 && name.indexOf("quickshell") < 0) {
                    out.push(n);
                }
            }
        }
        return out;
    }
    readonly property string sinkName: {
        var n = Pipewire.defaultAudioSink;
        if (!n) return "";
        return String(n.nickname || n.description || n.name || "");
    }
    readonly property string sourceName: {
        var n = Pipewire.defaultAudioSource;
        if (!n) return "";
        return String(n.nickname || n.description || n.name || "");
    }
    function setSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }

    // Warming up the wallpaper thumbnail cache at startup so that the themes page
    // It opened instantly the first time.
    Process {
        running: true
        command: ["sh", "-c", Quickshell.env("HOME")
                  + "/.config/zenith/scripts/thumbs.sh all"]
    }

    // ------------------------------------------------------------ system tray
    readonly property var trayItems: SystemTray.items

    // ---------------------------------------------------------- notifications
    // The pill itself works as a notification daemon: it was not in the system at all,
    // and everything that the programs sent disappeared silently.
    // “Do not disturb” is a state, not a setting: it is toggled by the button in
    // quick settings, but it lives in a file to survive restarts and
    // match what the settings window shows.
    property bool dnd: cfg.notifDnd
    function toggleDnd() { cfg.notifDnd = !cfg.notifDnd; root.saveCfg(); }
    property var  notifCurrent: null         // what is showing now
    ListModel { id: notifModel }             // history
    readonly property var notifications: notifModel
    // The notification daemon lives in Loader: if the feature is disabled by the installer,
    // the server is not created and the island is not registered as a daemon - then
    // The already installed mako/dunst works without a dispute over the bus.
    readonly property bool hasNotifications: cfg.featNotifications
    property var notifServer: notifLoader.item
    Loader {
        id: notifLoader
        active: root.cfg.featNotifications
        sourceComponent: notifServerComp
    }
    // live notifications that have not yet been closed by the program or user
    readonly property var activeNotifications:
        notifServer ? notifServer.trackedNotifications : null

    // Live notification objects by id. Needed so that pressing opens itself
    // reason: messengers have a “default” action, and that’s it
    // unfolds the desired chat - it is impossible to guess it from the outside.
    property var notifObjs: ({})

    Process { id: pFocusApp }
    // We turn the focus to the application: Hyprland itself will scroll to his table,
    // and if there is no window, the script will launch the application.
    function focusApp(hint) {
        var h = String(hint || "").trim();
        if (h.length === 0) return;
        pFocusApp.running = false;
        pFocusApp.command = ["sh", "-c",
            root.scriptDir + "/focusapp.sh \"$1\"", "_", h];
        pFocusApp.running = true;
    }

    // Expanding on hover after clicking on a notification only gets in the way: cursor
    // remains above the pill, and it immediately turns into “Quick
    // settings" - and there is a clock at the top with the caption "Calendar" and its area
    // clicks, so the next click took you to the calendar.
    //
    // Therefore, we reset the targeting only when the cursor leaves the pill:
    // the time was unreliable, because the cursor remains in place.
    property bool hoverExpandArmed: true

    // Clicked on the notification: first we ask the application to show a reason
    // (action “default”), then we go to his window and remove the card.
    //
    // Receives either the notification object itself (the card knows it directly),
    // or id from history. Previously they missed by id: keys in notifObjs
    // were converted to numbers differently, and the “default” action was not called -
    // The application did not open at all.
    function activateNotification(what) {
        var n = null;
        var id = -1;
        if (what !== null && typeof what === "object") {
            n = what;
            id = Number(what.id);
        } else {
            id = Number(what);
            n = root.notifObjs[String(id)] || null;
        }
        var hint = "";
        if (n) {
            hint = String(n.desktopEntry || "") || String(n.appName || "");
            var acts = n.actions || [];
            var used = false;
            for (var i = 0; i < acts.length; i++) {
                if (String(acts[i].identifier) === "default") {
                    acts[i].invoke(); used = true; break;
                }
            }
            // one action without a name - also almost always “open”
            if (!used && acts.length === 1) acts[0].invoke();
        }
        // The update notification does not go to the application, but to the settings:
        // the “Update” button lives there, and it’s strange to look for it after clicking it.
        if (id >= 0 && id === root.updNotifId) {
            root.updNotifId = -1;
            root.dismissToast();
            root.dropNotification(id);
            root.openSettingsAt("system");
            return;
        }

        root.focusApp(hint);
        root.dismissToast();
        if (id >= 0) root.dropNotification(id);
        // do not open under the cursor after clicking - until the cursor
        // won't go off the pill
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
        root.collapse();
    }

    readonly property bool toastActive: notifCurrent !== null && !expanded
    readonly property string notifSummary: notifCurrent ? String(notifCurrent.summary || "") : ""
    readonly property string notifBody:    notifCurrent ? String(notifCurrent.body || "") : ""
    readonly property string notifApp:     notifCurrent ? String(notifCurrent.appName || "") : ""
    readonly property string notifImage:   notifCurrent ? root.notifIconFor(notifCurrent) : ""

    // notify-send -i gives the NAME of the icon from the theme, not the path to the file.
    // Image cannot open such a name and draws a “broken picture” in its place.
    // in a cell. We expand the names through the topic; not found - give back empty,
    // and the card will draw its bell icon.
    function notifIconFor(n) {
        var img = String(n.image || "");
        if (img.length === 0) img = String(n.appIcon || "");
        if (img.length === 0) return "";
        // The icon from the Quickshell theme displays as image://icon/NAME,
        // and if there is no topic in the system, the provider silently returns the checkered
        // a stub with the status Ready - you cannot catch it by its status. Therefore
        // expand the name ourselves: iconPath with the second true returns empty
        // line when there is no icon, and the card draws its own bell.
        if (img.indexOf("image://icon/") === 0)
            return Quickshell.iconPath(img.substring(13).split("?")[0], true);
        // path, file://, data: - we give it as is
        if (img.indexOf("/") >= 0 || img.indexOf(":") >= 0) return img;
        return Quickshell.iconPath(img, true);
    }
    readonly property bool   notifUrgent:
        notifCurrent ? notifCurrent.urgency === NotificationUrgency.Critical : false

    Component {
    id: notifServerComp
    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;

            var app = String(n.appName || "");
            var sum = String(n.summary || "");
            var isTransient = (app === "Zenith"
                               || sum === root.tr("Скриншот")
                               || sum === "Скриншот"
                               || sum === "Screenshot"
                               || sum.indexOf("Скриншот") >= 0
                               || sum.indexOf("Screenshot") >= 0);
            if (n.hints && (n.hints["transient"] === true || n.hints["transient"] === 1 || n.hints["transient"] === "1")) {
                isTransient = true;
            }

            if (!isTransient) {
                notifModel.insert(0, {
                    nId: Number(n.id),
                    nSummary: String(n.summary || ""),
                    nBody: String(n.body || ""),
                    nApp: String(n.appName || ""),
                    nImage: root.notifIconFor(n),
                    nUrgent: n.urgency === NotificationUrgency.Critical,
                    nTime: Qt.formatDateTime(new Date(), "HH:mm")
                });
                while (notifModel.count > 50) notifModel.remove(notifModel.count - 1);
            }

            // The program itself closes the notification when it has lost its meaning:
            // Telegram does this as soon as the message is read in the
            // messenger. Previously, such a card still hung in history -
            // now she goes away with the reins.
            var nid = Number(n.id);
            var objs = root.notifObjs;
            objs[String(nid)] = n;
            root.notifObjs = objs;
            n.closed.connect(function (reason) {
                var o = root.notifObjs;
                delete o[String(nid)];
                root.notifObjs = o;
                if (reason !== NotificationCloseReason.CloseRequested) return;
                root.dropNotification(nid);
            });

            // We show critical ones even in “do not disturb” mode
            if (root.dnd && n.urgency !== NotificationUrgency.Critical) return;

            if (!isTransient && (root.cfg.notifSound !== false)) {
                root.playSound("notification");
            }

            root.enqueueToast(n);
        }
    }
    }

    // Queue of cards. Previously, a notification that arrived while the panel was open
    // or while the previous card is shown, it simply fades into history -
    // and the person did not know about him. Now it is waiting its turn.
    property var toastQueue: []

    function enqueueToast(n) {
        var q = root.toastQueue.slice();
        q.push({ notif: n, at: Date.now() });
        root.toastQueue = q;
        root.pumpToasts();
    }

    function pumpToasts() {
        // occupied by the current card or the panel is open - let's wait
        if (root.notifCurrent !== null || root.expanded) return;
        if (root.toastQueue.length === 0) return;

        var q = root.toastQueue.slice();
        var item = q.shift();
        root.toastQueue = q;

        // We don’t show the rotten ones (more than a minute in line): they are already in history
        if (Date.now() - item.at > 60000) { root.pumpToasts(); return; }

        var n = item.notif;
        root.notifCurrent = n;
        // We respect our application time, but sets the upper and lower limits
        // person: important ones with a zero deadline hang until the answer.
        var crit = n.urgency === NotificationUrgency.Critical;
        var want = crit ? root.cfg.notifCritTimeout : root.cfg.notifTimeout;
        var ms = n.expireTimeout > 0 ? (n.expireTimeout < 100 ? n.expireTimeout * 1000 : n.expireTimeout) : want;
        if (!crit && want > 0 && ms > want) ms = want;
        if (crit && want === 0) ms = 0;
        toastTimer.interval = ms > 0 ? Math.max(1000, ms) : 24 * 60 * 60 * 1000;
        toastTimer.restart();
    }

    Timer { id: toastPump; interval: 260; onTriggered: root.pumpToasts() }

    Timer {
        id: toastTimer
        // if the cursor is on the card, we don’t remove it, we wait for the user’s decision
        onTriggered: {
            if (capsuleHover.hovered) { toastTimer.interval = 1200; restart(); return; }
            root.dismissToast();
        }
    }
    // A cross in history: we remove the line and at the same time tell the program that
    // the notification is closed, otherwise it will remain “unread” on her mind.
    function forgetNotification(index) {
        var e = notifModel.get(index);
        var nid = e ? Number(e.nId) : -1;
        notifModel.remove(index);
        if (nid < 0 || !notifServer) return;
        var live = notifServer.trackedNotifications.values;
        for (var i = 0; i < live.length; i++) {
            if (live[i] && Number(live[i].id) === nid) { live[i].dismiss(); break; }
        }
        if (root.notifCurrent && Number(root.notifCurrent.id) === nid) root.dismissToast();
    }

    // Remove the notification from the history (and from the screen, if it is currently shown)
    function dropNotification(nid) {
        for (var i = 0; i < notifModel.count; i++) {
            if (Number(notifModel.get(i).nId) === nid) { notifModel.remove(i); break; }
        }
        // and from the queue of cards that it might not have reached
        var q = root.toastQueue.filter(function (it) {
            return !it.notif || Number(it.notif.id) !== nid;
        });
        if (q.length !== root.toastQueue.length) root.toastQueue = q;

        if (root.notifCurrent && Number(root.notifCurrent.id) === nid) root.dismissToast();
    }

    function dismissToast() {
        toastTimer.stop();
        root.notifCurrent = null;
        toastPump.restart();
    }
    function clearNotifications() {
        notifModel.clear();
        // We also close active ones - otherwise “Clear” removes only half
        if (!notifServer) return;
        var live = notifServer.trackedNotifications.values;
        for (var i = live.length - 1; i >= 0; i--) {
            if (live[i]) live[i].dismiss();
        }
    }

    // ------------------------------------------------------- password manager
    // The entries are located in ~/.local/share/zenith/vault.enc, encrypted with a password
    // user. The pill keeps the decrypted list and the password itself in memory,
    // while the storage is open, and forgets everything after 15 minutes without asking.
    property bool   vaultUnlocked: false
    property string vaultKey: ""            // password-key, only in memory
    property var    vaultEntries: []        // [{id,label,login,pw,at}]
    property string vaultError: ""
    property bool   vaultBusy: false
    readonly property int vaultIdleMs: 15 * 60 * 1000

    // The vault password entry window keeps it open while it is being used
    Timer {
        id: vaultIdle
        interval: root.vaultIdleMs
        onTriggered: root.lockVault()
    }
    function touchVault() { if (root.vaultUnlocked) vaultIdle.restart(); }

    // It closes immediately, but we keep the key and records until the end of the unfinished
    // saving: otherwise, the edit made a second before blocking was lost.
    property bool vaultLockPending: false
    function finishLockVault() {
        root.vaultLockPending = false;
        root.vaultKey = "";
        root.vaultEntries = [];
    }
    function lockVault() {
        vaultIdle.stop();
        root.vaultUnlocked = false;
        root.vaultError = "";
        if (root.vaultDirty || pVaultSave.running) {
            root.vaultLockPending = true;
            vaultSaveTimer.restart();
            return;
        }
        finishLockVault();
    }

    PamContext {
        id: vaultPam
        // same profile as the lock screen: checks the password
        // user - the one asking for sudo
        config: "swaylock"
        onPamMessage: {
            if (responseRequired) respond(root.vaultKey);
        }
        onCompleted: result => {
            if (result === PamResult.Success) {
                root.vaultLoad();
            } else {
                root.vaultKey = "";
                root.vaultBusy = false;
                root.vaultError = root.tr("Неверный пароль");
            }
        }
    }

    // Open the storage: first PAM confirms the password, then on it
    // the file is decrypted.
    function unlockVault(password) {
        if (root.vaultBusy) return;
        root.vaultError = "";
        root.vaultKey = String(password || "");
        if (root.vaultKey.length === 0) return;
        root.vaultBusy = true;
        if (!vaultPam.start()) {
            root.vaultBusy = false;
            root.vaultKey = "";
            root.vaultError = root.tr("Не удалось проверить пароль");
        }
    }

    Process {
        id: pVaultLoad
        stdinEnabled: true
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (t.length === 0) return;
                try { root.vaultEntries = JSON.parse(t); } catch (e) { root.vaultEntries = []; }
            }
        }
        onExited: code => {
            root.vaultBusy = false;
            if (code === 0) {
                root.vaultUnlocked = true;
                vaultIdle.restart();
                root.vaultError = "";
            } else {
                root.vaultKey = "";
                root.vaultError = code === 2 ? root.tr("Хранилище не открылось")
                                             : root.tr("Ошибка хранилища");
            }
        }
    }
    function vaultLoad() {
        pVaultLoad.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/zenith/scripts/vault.sh load"];
        pVaultLoad.running = true;
        pVaultLoad.write(root.vaultKey + "\n");
        pVaultLoad.stdinEnabled = false;
    }

    Process {
        id: pVaultSave
        stdinEnabled: true
        onExited: code => {
            if (code !== 0) root.vaultError = root.tr("Не удалось сохранить");
            // During the recording, the list could change again - write again
            if (root.vaultDirty) vaultSaveTimer.restart();
            else if (root.vaultLockPending) root.finishLockVault();
        }
    }

    // The recording goes through one process, so consecutive edits are not possible.
    // send "head on". Previously, "Add All" called vaultSave() on each
    // entry: the first call started openssl, the rest saw running === true,
    // nothing was launched, and their write() went to already closed stdin. To disk
    // the first entry was found - hence “passwords are not saved.”
    // Now the edits are accumulated and left in one file.
    property bool vaultDirty: false
    Timer {
        id: vaultSaveTimer
        interval: 120
        onTriggered: root.vaultFlush()
    }
    function vaultSave() {
        if (!root.vaultUnlocked) return;
        touchVault();
        root.vaultDirty = true;
        vaultSaveTimer.restart();
    }
    function vaultFlush() {
        // Not by vaultUnlocked: closing the vault is waiting for this particular entry,
        // and by that time the flag had already been removed.
        if (root.vaultKey.length === 0) return;
        // the previous entry is still running - let's wait and try again
        if (pVaultSave.running) { vaultSaveTimer.restart(); return; }
        root.vaultDirty = false;
        pVaultSave.stdinEnabled = true;
        pVaultSave.command = ["sh", "-c",
            Quickshell.env("HOME") + "/.config/zenith/scripts/vault.sh save"];
        pVaultSave.running = true;
        pVaultSave.write(root.vaultKey + "\n" + JSON.stringify(root.vaultEntries));
        pVaultSave.stdinEnabled = false;
    }

    function vaultAdd(label, login, pw) {
        if (!root.vaultUnlocked) return;
        var a = root.vaultEntries.slice();
        a.unshift({
            id: String(Date.now()) + "-" + Math.floor(Math.random() * 1e6),
            label: String(label || root.tr("Без названия")),
            login: String(login || ""),
            pw: String(pw || ""),
            at: Qt.formatDateTime(new Date(), "dd.MM.yyyy HH:mm")
        });
        root.vaultEntries = a;
        vaultSave();
    }
    function vaultUpdate(id, label, login, pw) {
        var a = root.vaultEntries.slice();
        for (var i = 0; i < a.length; i++) {
            if (a[i].id !== id) continue;
            a[i] = { id: id, label: String(label), login: String(login),
                     pw: String(pw), at: a[i].at };
            break;
        }
        root.vaultEntries = a;
        vaultSave();
    }
    function vaultRemove(id) {
        root.vaultEntries = root.vaultEntries.filter(function (e) { return e.id !== id; });
        vaultSave();
    }
    function vaultHas(pw) {
        for (var i = 0; i < root.vaultEntries.length; i++)
            if (root.vaultEntries[i].pw === pw) return true;
        return false;
    }

    // --- import from browsers
    // browser_pw.py reads profiles of installed browsers and prints
    // found by JSON. It does not save anything: the list is shown in
    // storage, and a person transfers the records using a button.
    property var    browserFound: []      // [{url, login, pw, browser}]
    property bool   browserScanning: false
    property bool   browserScanned: false // was there at least one search in this session
    property string browserError: ""

    function browserScan() {
        if (!root.vaultUnlocked || root.browserScanning) return;
        root.browserError = "";
        root.browserFound = [];
        root.browserScanning = true;
        pBrowserScan.running = true;
    }

    Process {
        id: pBrowserScan
        command: ["python3", root.scriptDir + "/browser_pw.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                var a = [];
                try { a = JSON.parse(text); } catch (e) { a = []; }
                // We do not show already saved ones: the list must consist of
                // what can actually be added.
                root.browserFound = a.filter(function (e) {
                    return String(e.pw || "").length > 0 && !root.vaultHas(String(e.pw));
                });
                root.browserScanning = false;
                root.browserScanned = true;
                root.touchVault();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text.trim().length) root.browserError = text.trim()
        }
        onExited: (code, status) => {
            root.browserScanning = false;
            root.browserScanned = true;
            if (code !== 0 && root.browserError.length === 0)
                root.browserError = root.tr("Не удалось прочитать браузеры");
        }
    }

    // Transfer one found record to storage.
    function browserImport(item) {
        if (!root.vaultUnlocked || !item) return;
        root.vaultAdd(String(item.url || item.browser || root.tr("Из браузера")),
                      String(item.login || ""), String(item.pw || ""));
        root.browserFound = root.browserFound.filter(function (e) {
            return !(e.pw === item.pw && e.login === item.login && e.url === item.url);
        });
    }

    function browserImportAll() {
        if (!root.vaultUnlocked) return;
        var list = root.browserFound.slice();
        for (var i = 0; i < list.length; i++) {
            var e = list[i];
            if (root.vaultHas(String(e.pw))) continue;
            root.vaultAdd(String(e.url || e.browser || root.tr("Из браузера")),
                          String(e.login || ""), String(e.pw || ""));
        }
        root.browserFound = [];
    }

    // --- prompt to save password
    // You can’t (and don’t need to) spy on what a person is typing in someone else’s window.
    // it would be a keylogger). But the password almost always passes through the buffer
    // exchange: from the manager, from the letter, from the generator. Pill notices this
    // line and asks whether to save it.
    property var vaultPrompt: null           // {pw, label}

    function looksLikePassword(s) {
        if (!root.cfg.featVault || !root.cfg.vaultCapture) return false;
        if (!s || s.length < 8 || s.length > 128) return false;
        if (/\s/.test(s)) return false;
        if (/^(https?|ftp|file|magnet):/i.test(s)) return false;
        if (s.indexOf("/") === 0 || s.indexOf("~/") === 0) return false;
        if (/^[0-9]+$/.test(s)) return false;          // numbers, codes, accounts
        if (/^[a-z]+$/.test(s)) return false;          // just a word
        if (/@[^@]+\.[a-z]{2,}$/i.test(s)) return false; // mail
        var classes = 0;
        if (/[a-z]/.test(s)) classes++;
        if (/[A-Z]/.test(s)) classes++;
        if (/[0-9]/.test(s)) classes++;
        if (/[^A-Za-z0-9]/.test(s)) classes++;
        return classes >= 3;
    }

    Process {
        id: pClipWatch
        running: root.cfg.featVault
        // print only the first line: multi-line text cannot be used as a password
        command: ["sh", "-c",
            "wl-paste --type text --watch sh -c "
            + "'printf \"%s\\n\" \"$(wl-paste -n -t text 2>/dev/null | head -1)\"'"]
        stdout: SplitParser {
            onRead: line => {
                var s = String(line);
                if (!root.looksLikePassword(s)) return;
                if (root.vaultUnlocked && root.vaultHas(s)) return;
                if (root.vaultPrompt && root.vaultPrompt.pw === s) return;
                root.vaultPrompt = { pw: s, label: "" };
                pVaultWhere.running = true;
                root.togglePage("vaultsave");
            }
        }
    }
    // whose window is currently active - substitute it as the title of the entry
    Process {
        id: pVaultWhere
        command: ["sh", "-c",
            "if [ -n \"$NIRI_SOCKET\" ] || [ \"${XDG_CURRENT_DESKTOP,,}\" = \"niri\" ]; then "
            + "niri msg --json focused-window 2>/dev/null | jq -r '.app_id // \"\"'; "
            + "else hyprctl activewindow -j 2>/dev/null | jq -r '.initialClass // .class // \"\"'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var c = text.trim();
                if (c.length === 0 || !root.vaultPrompt) return;
                root.vaultPrompt = { pw: root.vaultPrompt.pw,
                                     label: c.charAt(0).toUpperCase() + c.slice(1) };
            }
        }
    }
    // Copy the password to the clipboard. run wl-copy with --sensitive-data to
    // the line has not settled in the cliphist history, and we clear the buffer in a minute.
    Process { id: pVaultCopy }
    function vaultCopy(pw) {
        touchVault();
        pVaultCopy.command = ["sh", "-c",
            "printf '%s' \"$1\" | wl-copy --sensitive-data 2>/dev/null "
            + "|| printf '%s' \"$1\" | wl-copy", "_", String(pw)];
        pVaultCopy.running = true;
        vaultClipClear.restart();
    }
    Process { id: pVaultClip; command: ["sh", "-c", "wl-copy --clear"] }
    Timer { id: vaultClipClear; interval: 60000; onTriggered: pVaultClip.running = true }

    function dismissVaultPrompt() {
        root.vaultPrompt = null;
        if (root.page === "vaultsave") root.collapse();
    }

    // ------------------------------------------------------------------ OSD
    // When you change the volume or brightness, the pill turns into a
    // into the level bar and returns back.
    property string osdKind: ""          // "vol" | "mic" | "bright"
    property real   osdValue: 0          // 0..1
    property bool   osdMuted: false
    readonly property bool osdActive: osdKind.length > 0 && !expanded

    Timer {
        id: osdTimer
        interval: 1700
        onTriggered: root.osdKind = ""
    }
    function showOsd(kind, value, muted) {
        if (!cfg.featOsd) return;
        osdKind = kind;
        osdValue = Math.max(0, Math.min(1, value));
        osdMuted = muted === true;
        osdTimer.restart();
    }

    readonly property string osdIcon: {
        if (osdKind === "bright") return String.fromCodePoint(0xF00DE);       // sun
        if (osdKind === "mic")
            return String.fromCodePoint(osdMuted ? 0xF036D : 0xF036C);        // microphone
        if (osdMuted || osdValue <= 0.001) return String.fromCodePoint(0xF075F);
        if (osdValue < 0.34) return String.fromCodePoint(0xF057F);
        if (osdValue < 0.67) return String.fromCodePoint(0xF0580);
        return String.fromCodePoint(0xF057E);
    }

    // --- we take the volume and microphone from Pipewire: we react to any change,
    //     not only by pressing a multimedia key
    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
    }
    readonly property var sinkAudio:
        Pipewire.defaultAudioSink ? Pipewire.defaultAudioSink.audio : null
    readonly property var srcAudio:
        Pipewire.defaultAudioSource ? Pipewire.defaultAudioSource.audio : null

    property bool osdReady: false        // do not show OSD when shell starts
    Timer { interval: 1500; running: true; onTriggered: root.osdReady = true }

    // Changing the output device (Bluetooth headphones are connected, plugged in
    // jack) rebinds sinkAudio, and onVolumeChanged fires the initial
    // volume of the new device - an OSD with a volume bar would pop up for a moment,
    // although no one touched her. We turn off the OSD for a short window around the switch.
    property bool sinkSwitching: false
    onSinkAudioChanged: { root.sinkSwitching = true; sinkSettleTimer.restart(); }
    Timer { id: sinkSettleTimer; interval: 700; onTriggered: root.sinkSwitching = false }

    Connections {
        target: root.sinkAudio
        enabled: root.sinkAudio !== null
        function onVolumeChanged() {
            if (root.osdReady && !root.sinkSwitching)
                root.showOsd("vol", root.sinkAudio.volume, root.sinkAudio.muted);
        }
        function onMutedChanged() {
            if (root.osdReady && !root.sinkSwitching)
                root.showOsd("vol", root.sinkAudio.volume, root.sinkAudio.muted);
        }
    }
    Connections {
        target: root.srcAudio
        enabled: root.srcAudio !== null
        function onMutedChanged() {
            if (root.osdReady) root.showOsd("mic", root.srcAudio.volume, root.srcAudio.muted);
        }
    }

    // ------------------------------------------------------- power profile
    readonly property string powerScript:
        Quickshell.env("HOME") + "/.config/zenith/scripts/power.sh"

    // "power-saver" | "balanced" | "performance"
    property string powerProfile: "balanced"

    Process {
        id: pPowerGet
        command: ["sh", "-c", root.powerScript + " get"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var s = line.trim();
                if (s.length) root.powerProfile = s;
            }
        }
    }
    Process {
        id: pPowerSet
        onRunningChanged: if (!running) pPowerGet.running = true
    }
    // The power mode is changed by a person and almost always through the panel itself,
    // therefore, when closed, it is enough to check it once every half a minute.
    Timer {
        interval: root.expanded ? 10000 : 30000
        running: true; repeat: true
        onTriggered: pPowerGet.running = true
    }

    // Human name of the current power mode - for the battery tile label
    readonly property string profileLabel:
        powerProfile === "power-saver" ? tr("Экономия")
      : powerProfile === "performance" ? tr("Максимум")
                                       : tr("Баланс")

    function setPowerProfile(name) {
        // reflect immediately, then confirm with the real value from the demon
        root.powerProfile = name;
        pPowerSet.command = ["sh", "-c", root.powerScript + " set \"$1\"", "_", name];
        pPowerSet.running = true;
    }

    // ------------------------------------------------------- desktop
    readonly property int wsId:
        Compositor.isNiri ? Compositor.focusedWorkspace
                          : (Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1)

    // Tables in numerical order are for points in the collapsed island. Special tables
    // (negative) we skip: they are not switched to in a row with the others,
    // and the point under them would lose count.
    readonly property var wsRaw: {
        var out = [];
        if (Compositor.isNiri) {
            var nws = Compositor.workspaces;
            for (var k = 0; k < nws.length; k++)
                if (nws[k] && nws[k].id > 0) out.push(nws[k].id);
            out.sort(function (a, b) { return a - b; });
            return out;
        }
        var all = Hyprland.workspaces ? Hyprland.workspaces.values : [];
        for (var i = 0; i < all.length; i++)
            if (all[i] && all[i].id > 0) out.push(all[i].id);
        out.sort(function (a, b) { return a - b; });
        return out;
    }

    // We keep the list of tables separately and change only when it really becomes
    // to others.
    //
    // The calculation above is recalculated for each Hyprland event - and their
    // one switching, several arrive, and each time it gives a new one
    // array. Repeater judges by the object itself, not its contents, and
    // to a new array, it destroys and recreates all the points at once. Hence
    // blinking when moving to an empty table: the current point had time to be born
    // stripe and immediately disappear along with everything nearby.
    property var wsList: []
    onWsRawChanged: {
        var a = root.wsRaw, b = root.wsList;
        if (a.length === b.length) {
            var same = true;
            for (var i = 0; i < a.length; i++)
                if (a[i] !== b[i]) { same = false; break; }
            if (same) return;
        }
        root.wsList = a;
    }

    // -------------------------------------------------- keyboard layout
    property string kbLayout: (Compositor && Compositor.keyboardLayout) ? Compositor.keyboardLayout : "BR"
    Process {
        id: pKbLayout
        command: ["sh", "-c",
            "hyprctl devices -j | jq -r '.keyboards[]|select(.main==true)|.active_keymap' | head -1"]
        running: !Compositor.isNiri
        stdout: SplitParser {
            onRead: line => {
                var s = line.trim();
                if (!s.length) return;
                Compositor.keyboardLayoutName = s;
                root.kbLayout = Compositor.layoutLabel(s);
            }
        }
    }
    // Hyprland sends activelayout every time you switch Alt+Shift
    Connections {
        target: Hyprland
        enabled: !Compositor.isNiri
        function onRawEvent(ev) {
            if (ev.name === "activelayout") {
                if (ev.data && ev.data.indexOf(",") >= 0) {
                    var parts = ev.data.split(",");
                    var kName = parts.slice(1).join(",").trim();
                    if (kName.length) {
                        Compositor.keyboardLayoutName = kName;
                        root.kbLayout = Compositor.layoutLabel(kName);
                    }
                }
                pKbLayout.running = false;
                pKbLayout.running = true;
            }
        }
    }
    Timer {
        interval: 800
        running: true
        repeat: false
        onTriggered: { pKbLayout.running = false; pKbLayout.running = true; }
    }

    // ------------------------------------------------------------------ watch
    property string timeText: ""
    property string dayText: ""
    property string dateLong: ""
    // Seconds on a separate line. In timeText they appear only if there are
    // asked in the Clock & Date tab, and the opened island on the Nothing topic
    // they are always needed: there is a small number on the side of the large clock, and not
    // part of them. You cannot mix these two cases in one line.
    property string secText: ""
    // The day of the month and whether it is a day off - for the date card on the desktop.
    // We keep it separate from dateLong: it is collected according to the selected format and
    // You can’t pick numbers out of it anymore.
    property string dayNum: ""
    property bool   weekend: false
    // Month with its own list, and not through Qt.formatDateTime: it takes the language from
    // system locale, and shell signatures follow its own setting
    // language - otherwise the English interface would remain Russian for a month.
    property string monthText: ""
    Timer {
        interval: 1000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            var d = new Date();
            // 12-hour format - with AM/PM, 24-hour - without; seconds
            // are added to both if asked in the Clock & Date tab
            var sec = root.cfg.clockSeconds ? ":ss" : "";
            root.timeText = root.cfg.clock12
                ? (hr12 + ":" + mm + secStr + " " + ampm)
                : Qt.formatDateTime(d, "HH:mm" + (root.cfg.clockSeconds ? ":ss" : ""));
            root.secText = Qt.formatDateTime(d, "ss");
            // The date format and the day of the week before it are also from the settings
            root.dateLong = (root.cfg.clockWeekday ? Qt.formatDateTime(d, "dddd") + ", " : "")
                + Qt.formatDateTime(d, root.cfg.clockDateFmt || "d MMMM");
            root.dayText = root.isEn
                ? ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"][d.getDay()]
                : (root.isPt ? ["Dom","Seg","Ter","Qua","Qui","Sex","Sáb"][d.getDay()] : ["Вс","Пн","Вт","Ср","Чт","Пт","Сб"][d.getDay()]);
            root.dayNum = String(d.getDate());
            root.weekend = d.getDay() === 0 || d.getDay() === 6;
            root.monthText = Qt.locale(root.languageCode || "pt_BR").monthName(d.getMonth(), Locale.LongFormat);
        }
    }

    // ------------------------------------------------------------------ Wi-Fi
    readonly property string wifiScript: Quickshell.env("HOME") + "/.config/zenith/scripts/wifi.sh"

    property bool wifiOn: true
    property string wifiSsid: ""
    property int wifiQuality: 0
    property bool wifiBusy: false
    property string wifiError: ""
    property string wifiConnectingSsid: ""
    property bool   wifiConnecting: false

    // ---- Тост «Wi-Fi подключён / отключён» -----------------------------
    // Аналогично Bluetooth-устройствам: при успешном подключении остров
    // показывает карточку с именем сети, значком Wi-Fi и уровнем сигнала.
    property bool   wifiToastShown: false
    property string wifiToastSsid: ""
    property int    wifiToastQuality: 0
    property bool   wifiToastDisconnected: false
    readonly property bool wifiToastActive:
        wifiToastShown && !expanded && !btToastActive && !acToastActive
    property string wifiPrevConnected: ""
    property string wifiLastSsid: ""
    property bool   wifiInitDone: false

    Timer {
        id: wifiInitTimer
        interval: 3500
        running: true
        onTriggered: {
            root.wifiPrevConnected = root.wifiSsid;
            if (root.wifiSsid.length > 0) root.wifiLastSsid = root.wifiSsid;
            root.wifiInitDone = true;
        }
    }

    onWifiSsidChanged: {
        if (!root.wifiInitDone) return;
        var ssid = root.wifiSsid;
        if (ssid.length > 0 && ssid !== root.wifiPrevConnected) {
            root.wifiPrevConnected = ssid;
            root.wifiLastSsid = ssid;
            root.wifiConnecting = false;
            root.wifiConnectingSsid = "";
            root.showWifiToast(ssid, root.wifiQuality, false);
        } else if (ssid.length === 0) {
            root.wifiPrevConnected = "";
            root.wifiConnectingSsid = "";
        }
    }

    onWifiOnChanged: {
        if (!root.wifiInitDone) return;
        if (root.wifiOn && root.wifiSsid.length === 0) {
            root.wifiConnecting = true;
            wifiSettleTimer.begin();
        } else if (!root.wifiOn) {
            root.wifiConnecting = false;
            root.wifiSsid = "";
            root.wifiPrevConnected = "";
            root.wifiConnectingSsid = "";
            wifiSettleTimer.stop();
        }
    }

    function showWifiToast(ssid, quality, isDisconnect) {
        root.wifiToastSsid = ssid;
        root.wifiToastQuality = quality || root.wifiQuality || 0;
        root.wifiToastDisconnected = isDisconnect || false;
        root.wifiToastShown = true;
        if (root.expanded) root.collapse();
        wifiToastTimer.interval = 2500;
        wifiToastTimer.restart();
        root.playSound(isDisconnect ? "disconnect" : "connect");
    }

    function dismissWifiToast() {
        root.wifiToastShown = false;
        wifiToastTimer.stop();
    }
    Timer {
        id: wifiToastTimer
        interval: 2500
        onTriggered: root.dismissWifiToast()
    }

    ListModel { id: wifiModel }
    // we give the model outside: ControlsView is in another file
    readonly property var wifiNetworks: wifiModel

    Process {
        id: pWifiStatus
        command: ["sh", "-c", root.wifiScript + " status"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 3) return;
                root.wifiOn = (p[0] === "on");
                var newSsid = p[1] || "";
                root.wifiQuality = parseInt(p[2]) || 0;
                root.wifiSsid = newSsid;
                if (newSsid.length > 0) {
                    root.wifiLastSsid = newSsid;
                    root.wifiConnecting = false;
                    root.wifiConnectingSsid = "";
                    wifiSettleTimer.stop();
                    wifiSettleTimer.tries = 0;
                }
            }
        }
    }
    // Assigning running = true to a running process does nothing:
    // the survey is silently skipped, and the state freezes until the next time.
    // We restart obviously.
    function refreshWifiStatus() {
        pWifiStatus.running = false;
        pWifiStatus.running = true;
    }
    // The collapsed island shows only the network icon: there is plenty of rare stuff there
    // survey. Frequent is needed when the list of networks is open.
    Timer {
        interval: root.expanded ? 4000 : 15000
        running: true; repeat: true
        onTriggered: root.refreshWifiStatus()
    }

    Process {
        id: pWifiList
        command: ["sh", "-c", root.wifiScript + " list"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 5) return;
                wifiModel.append({
                    connected: p[0] === "yes",
                    ssid: p[1],
                    security: p[2],
                    quality: parseInt(p[3]) || 0,
                    known: p[4] === "yes"
                });
            }
        }
        onRunningChanged: if (!running) root.wifiBusy = false
    }

    Process { id: pWifiScan; command: ["sh", "-c", root.wifiScript + " scan"] }
    Process {
        id: pWifiToggle
        command: ["sh", "-c", root.wifiScript + " toggle"]
        onRunningChanged: if (!running) {
            root.refreshWifiStatus();
            if (root.wifiOn) {
                wifiSettleTimer.begin();
            }
        }
    }
    Process {
        id: pWifiConnect
        onRunningChanged: {
            if (running) return;
            root.wifiBusy = false;
            if (exitCode !== 0) {
                root.wifiError = "Не удалось подключиться";
                root.wifiConnectingSsid = "";
                root.wifiConnecting = false;
            } else {
                root.wifiError = "";
                if (root.wifiConnectingSsid.length > 0) {
                    root.wifiSsid = root.wifiConnectingSsid;
                }
                root.page = "main";
            }
            root.refreshWifiStatus();
            // iwctl returns before the connection is up: immediately after
            // his `iw dev link` was still empty, and the panel showed the connected
            // network without a name. We ask again when the connection is established.
            wifiSettleTimer.begin();
            root.refreshWifiList();
        }
    }

    // The connection does not rise instantly and not in the same amount of time: at one point
    // this is a fraction of a second, for the other it is several. Therefore, after connecting
    // one deferred poll, but several in a row, and they stop as
    // only the network name appeared. Otherwise, the panel showed the connected network
    // without a name until the next general survey - or until a manual scan.
    Timer {
        id: wifiSettleTimer
        interval: 800
        repeat: true
        property int tries: 0
        onTriggered: {
            root.refreshWifiStatus();
            if (root.wifiSsid.length > 0 || ++wifiSettleTimer.tries > 15) {
                root.wifiConnecting = false;
                if (root.wifiSsid.length > 0) {
                    root.wifiConnectingSsid = "";
                }
                wifiSettleTimer.tries = 0;
                wifiSettleTimer.stop();
            }
        }
        function begin() { wifiSettleTimer.tries = 0; wifiSettleTimer.restart(); }
    }

    // Disconnect from the network and forget it. Forgetting is not the same as
    // disconnect: while the network is saved, iwd will connect to it itself the first time
    // opportunity, and “turned off” remains exactly until the next appearance
    // this point in the ether.
    Process { id: pWifiDisconnect }
    function disconnectWifi() {
        pWifiDisconnect.running = false;
        pWifiDisconnect.command = ["sh", "-c", root.wifiScript + " disconnect"];
        pWifiDisconnect.running = true;
        root.wifiConnecting = false;
        root.wifiSsid = "";
        root.wifiPrevConnected = "";
        root.wifiConnectingSsid = "";
        wifiSettleTimer.begin();
    }
    Process { id: pWifiForget }
    function forgetWifi(ssid) {
        if (!ssid || !ssid.length) return;
        if (root.wifiLastSsid === ssid) root.wifiLastSsid = "";
        pWifiForget.running = false;
        pWifiForget.command = ["sh", "-c", root.wifiScript + " forget \"$1\"", "_", String(ssid)];
        pWifiForget.running = true;
        wifiSettleTimer.begin();
        wifiRescanTimer.restart();
    }

    function toggleWifi() {
        if (root.wifiOn) {
            if (root.wifiSsid.length > 0) root.wifiLastSsid = root.wifiSsid;
            root.wifiOn = false;
            root.wifiConnecting = false;
            root.wifiSsid = "";
            root.wifiPrevConnected = "";
            root.wifiConnectingSsid = "";
            wifiSettleTimer.stop();
        } else {
            root.wifiOn = true;
            root.wifiConnecting = true;
            root.wifiConnectingSsid = "";
            wifiSettleTimer.begin();
        }
        pWifiToggle.running = false;
        pWifiToggle.running = true;
    }
    function refreshWifiList() {
        wifiModel.clear();
        root.wifiBusy = true;
        pWifiList.running = true;
    }
    function scanWifi() {
        root.wifiBusy = true;
        pWifiScan.running = true;
        wifiRescanTimer.restart();
    }
    Timer { id: wifiRescanTimer; interval: 2600; onTriggered: root.refreshWifiList() }

    function connectWifi(ssid, password, username, security) {
        root.wifiConnectingSsid = ssid;
        root.wifiBusy = true;
        root.wifiError = "";
        pWifiConnect.command = security === "eap"
            ? ["sh", "-c", root.wifiScript + " connect \"$1\" \"$2\" \"$3\" eap", "_", ssid, password, username]
            : password && password.length
            ? ["sh", "-c", root.wifiScript + " connect \"$1\" \"$2\"", "_", ssid, password]
            : ["sh", "-c", root.wifiScript + " connect \"$1\"", "_", ssid];
        pWifiConnect.running = true;
    }

    // --------------------------------------------------------- screen recording
    // All state is kept by scripts/record.sh: the pill can be restarted
    // right during the recording, and she will pick it back up.
    property bool   recActive: false
    property bool   recPaused: false
    property int    recStarted: 0        // unix start time
    property int    recPausedTotal: 0    // how many seconds did you pause?
    property string recFile: ""
    property string recError: ""
    property int    recNow: 0            // "now" for a timer, ticks once per second

    readonly property int recSeconds:
        recActive ? Math.max(0, recNow - recStarted - recPausedTotal) : 0
    readonly property string recTimeText: {
        var s = recSeconds;
        var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60), x = s % 60;
        var mm = (m < 10 ? "0" : "") + m, ss = (x < 10 ? "0" : "") + x;
        return h > 0 ? h + ":" + mm + ":" + ss : mm + ":" + ss;
    }

    readonly property string recScript: root.scriptDir + "/record.sh"

    // ------------------------------------------------- long work
    // Anything longer than a couple of seconds shows a collapsed island: copying
    // folders of several gigabytes, updating the shell, warming up the thumbnails. Previously
    // they walked in silence, and it was impossible to distinguish work from freezing.
    //
    // Not every job knows percentages, so busyProgress < 0 means
    // “it’s coming, how much is left is unknown”: where there is nothing to count, a strip
    // it just walks from side to side.
    property string busyLabel: ""
    property int    busyProgress: -1
    // icon to the left of the signature: copying has its own, updating has its own
    property string busyGlyph: ""

    function beginBusy(label, glyph, progress) {
        root.busyLabel = label;
        root.busyGlyph = glyph;
        root.busyProgress = progress === undefined ? -1 : progress;
    }
    function endBusy() {
        root.busyLabel = "";
        root.busyGlyph = "";
        root.busyProgress = -1;
    }

    // ------------------------------------------ long file operation
    // The process lives here, and not in the explorer, on purpose: the panel is closed immediately
    // after dragging the files, and both Loader and
    // copying in the middle. Now it survives to the end on its own, and the island
    // shows how much is left.
    property var fileOpQueue: []

    // The second operation, started while the first one is in progress, would have overwritten the command earlier
    // running process and silently disappeared.
    function runFileOp(args, label) {
        if (pFileOp.running) {
            var q = root.fileOpQueue.slice();
            q.push({ args: args, label: label });
            root.fileOpQueue = q;
            return;
        }
        root.beginBusy(label, "󰆏", 0);
        pFileOp.command = args;
        pFileOp.running = true;
    }

    Process {
        id: pFileOp
        stdout: SplitParser {
            onRead: line => {
                var m = /^PROGRESS (\d+)$/.exec(String(line).trim());
                if (m) root.busyProgress = parseInt(m[1], 10);
            }
        }
        onRunningChanged: {
            if (running) return;
            // all open explorers reread the lists: the file has appeared
            // (or disappeared) at the wrong window that started the operation
            root.filesChanged();
            if (root.fileOpQueue.length > 0) {
                var q = root.fileOpQueue.slice();
                var next = q.shift();
                root.fileOpQueue = q;
                root.beginBusy(next.label, "󰆏", 0);
                pFileOp.command = next.args;
                pFileOp.running = true;
                return;
            }
            root.endBusy();
        }
    }

    Process {
        id: pRecStatus
        command: ["sh", "-c", root.recScript + " status"]
        running: true
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p[0] === "idle") {
                    root.recActive = false;
                    root.recPaused = false;
                    return;
                }
                root.recActive = true;
                root.recPaused = (p[0] === "paused");
                root.recStarted = parseInt(p[2]) || 0;
                root.recPausedTotal = parseInt(p[3]) || 0;
                root.recFile = p[4] || "";
            }
        }
    }
    // While recording is not in progress, no one needs the second hand: the timer itself
    // goes to a rare step and stops waking up the processor every second.
    Timer {
        interval: root.recActive ? 1000 : 15000
        running: true; repeat: true; triggeredOnStart: true
        onTriggered: {
            root.recNow = Math.floor(Date.now() / 1000);
            pRecStatus.running = true;
        }
    }

    Process {
        id: pRecCmd
        onRunningChanged: if (!running) pRecStatus.running = true
        stderr: SplitParser {
            onRead: line => {
                var t = line.trim();
                if (!t.length) return;
                root.recError = t === "already" ? root.tr("Запись уже идёт")
                              : t === "no-recorder" ? root.tr("wf-recorder не найден")
                              : t === "failed"  ? root.tr("Не удалось начать запись")
                                                : t;
                recErrorClear.restart();
            }
        }
    }
    Timer { id: recErrorClear; interval: 4000; onTriggered: root.recError = "" }

    // Selecting a screen to record. Multiple monitors (laptop + HDMI) – wf-recorder
    // without -o asks which one to write, and fell in the background. We ask ourselves with a card.
    property bool recPick: false
    property var  recPickMons: []
    readonly property bool recPickActive: recPick && !expanded

    function startRecord() {
        if (root.recActive) return;
        root.recError = "";
        var scr = Quickshell.screens;
        if (scr && scr.length > 1) {
            var list = [];
            for (var i = 0; i < scr.length; i++)
                list.push({ name: scr[i].name,
                            desc: String(scr[i].model || scr[i].name) });
            root.recPickMons = list;
            root.recPick = true;
            if (root.expanded) root.collapse();
            return;
        }
        root.startRecordOn(scr && scr.length ? scr[0].name : "");
    }
    function startRecordOn(output) {
        root.recPick = false;
        root.recError = "";
        pRecCmd.command = ["sh", "-c",
            root.recScript + " start \"$1\" \"$2\" \"$3\" \"$4\" \"$5\" \"$6\"", "_",
            String(root.cfg.recFps), String(root.cfg.recDir),
            root.cfg.recSysAudio ? "1" : "0",
            root.cfg.recMic ? "1" : "0",
            String(root.cfg.recMicDevice),
            String(output)];
        pRecCmd.running = true;
    }
    function cancelRecPick() { root.recPick = false; }
    // We don’t leave the choice card hanging forever if we change our minds.
    Timer { id: recPickTimer; interval: 8000; running: root.recPickActive
            onTriggered: root.cancelRecPick() }
    function stopRecord() {
        if (!root.recActive) return;
        pRecCmd.command = ["sh", "-c", root.recScript + " stop"];
        pRecCmd.running = true;
    }
    function pauseRecord() {
        if (!root.recActive) return;
        pRecCmd.command = ["sh", "-c", root.recScript + " pause"];
        pRecCmd.running = true;
    }
    function toggleRecord() { if (root.recActive) stopRecord(); else startRecord(); }

    // ---------------------------------------------------- voice to text (voxtype)
    // While the right Alt is held down, the island shows an indicator: “Listening...” during
    // entries, “I’m deciphering...” while voxtype is typing the text. Leads the indicator
    // scripts/voxtype.sh (it is triggered by Hyprland when pressing/releasing a key)
    // via IPC voxListening/voxTranscribing/voxDone. Recognition itself and
    // inserting text into the active field is done by voxtype.
    property string voxState: ""     // "" | "listening" | "transcribing"
    readonly property bool voxActive: voxState.length > 0 && !expanded

    // Insurance: if “I’m deciphering...” for some reason did not close (voxtype fell and
    // did not send voxDone) - we hide it ourselves in a few seconds.
    Timer {
        id: voxGuard
        interval: 8000
        running: root.voxState === "transcribing"
        onTriggered: root.voxState = ""
    }

    // list of microphones to select from the recording console
    ListModel { id: micModel }
    readonly property var recMics: micModel
    Process {
        id: pRecMics
        command: ["sh", "-c", root.recScript + " mics"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split("|");
                if (p.length < 2) return;
                micModel.append({ mName: p[0], mDesc: p[1] });
            }
        }
    }
    function refreshMics() {
        micModel.clear();
        pRecMics.running = false;
        pRecMics.running = true;
    }

    Process { id: pMkRecDir }
    function openRecordDir() {
        var d = String(root.cfg.recDir);
        if (d.indexOf("~") === 0) d = Quickshell.env("HOME") + d.slice(1);
        // the folder may not exist yet: create it, otherwise Explorer will show emptiness
        pMkRecDir.command = ["sh", "-c", "mkdir -p \"$1\"", "_", d];
        pMkRecDir.running = true;
        root.filesDir = d;
        root.togglePage("files");
    }

    // -------------------------------------------------------------- Bluetooth
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter ? btAdapter.enabled : false
    readonly property var btDevices: btAdapter ? btAdapter.devices : null
    readonly property var btConnectedDevice: {
        if (!btDevices) return null;
        var list = btDevices.values;
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].connected) return list[i];
        return null;
    }
    readonly property string btConnectedName: {
        if (btConnectedDevice) return btConnectedDevice.name || "Устройство";
        return "";
    }
    // Charge the connected device (headphones). -1 if the battery is not reported.
    readonly property int btConnectedBattery: {
        if (btConnectedDevice && btConnectedDevice.batteryAvailable)
            return Math.round(btConnectedDevice.battery * 100);
        return -1;
    }

    // ---- Toast “headphones connected” --------------------------------------------------
    // After successfully connecting the Bluetooth headset, the island is several
    // seconds, it collapses into a card: on the left is the headphone icon, the device name
    // and the Connected label, on the right is a ring with a charge percentage. Catching the transition
    // name of the connected device from empty to non-empty - this is the moment
    // connections. btPrevConnected keeps what has already been shown so that it is the same
    // the connection did not pop up twice (the name is recalculated for each BlueZ sneeze).
    property string btToastName: ""
    property string btToastType: "earbuds"
    property bool   btToastDisconnected: false
    property bool   btToastLowBatt: false
    property bool   btToastShown: false
    readonly property bool btToastActive: btToastShown && !expanded
    property string btPrevConnected: ""
    property bool   btLowBattNotified: false

    function btLowBattCheck() {
        if (!btConnectedDevice || root.btConnectedBattery < 0) {
            root.btLowBattNotified = false;
            return;
        }
        if (root.btConnectedBattery > 25) {
            root.btLowBattNotified = false;
            return;
        }
        if (root.btConnectedBattery <= 20 && !root.btLowBattNotified && root.btConnectedName.length > 0) {
            root.btLowBattNotified = true;
            root.showBtLowBattToast(root.btConnectedName, root.btConnectedType);
        }
    }

    onBtConnectedBatteryChanged: root.btLowBattCheck()

    onBtConnectedNameChanged: {
        var name = root.btConnectedName;
        if (name.length > 0 && name !== root.btPrevConnected) {
            root.btPrevConnected = name;
            root.btLowBattNotified = false;
            root.showBtToast(name, root.btConnectedType, false);
            root.btLowBattCheck();
        } else if (name.length === 0 && root.btPrevConnected.length > 0) {
            var prev = root.btPrevConnected;
            var prevType = root.btToastType;
            root.btPrevConnected = "";
            root.btLowBattNotified = false;
            root.showBtToast(prev, prevType, true);
        }
    }

    function showBtToast(name, type, isDisconnect) {
        root.btToastName = name;
        root.btToastType = type || "earbuds";
        root.btToastDisconnected = isDisconnect || false;
        root.btToastLowBatt = false;
        root.btToastShown = true;
        // The connection often comes from the expanded Bluetooth menu. While the panel
        // expanded, the toast is not visible (btToastActive requires !expanded) - therefore
        // We collapse it ourselves, and the connection card is shown immediately.
        if (root.expanded) root.collapse();
        btToastTimer.interval = 2500;
        btToastTimer.restart();
        root.playSound(isDisconnect ? "disconnect" : "connect");
    }

    function showBtLowBattToast(name, type) {
        root.btToastName = name;
        root.btToastType = type || "earbuds";
        root.btToastDisconnected = false;
        root.btToastLowBatt = true;
        root.btToastShown = true;
        if (root.expanded) root.collapse();
        btToastTimer.interval = 3500;
        btToastTimer.restart();
        root.playSound("disconnect");
    }

    function dismissBtToast() {
        root.btToastShown = false;
        btToastTimer.stop();
    }
    Timer {
        id: btToastTimer
        interval: 2500
        onTriggered: root.dismissBtToast()
    }

    // ---- Toast “charging connected” ---------------------------------------
    // When connecting the power supply to the laptop, the island for a couple of seconds
    // collapses into the same card: charging icon, “Charging” and charge.
    // The background of the card is a smooth wave radiating from the center. Catching the transition
    // mains power from false to true; only on the laptop (on the desktop the network
    // there is always). Inferior to Bluetooth toast if it is shown.
    property bool acToastShown: false
    readonly property bool acToastActive:
        acToastShown && !expanded && root.isLaptop && !root.btToastActive
    property bool acPrev: root.acOnline
    property string acToastKind: "charge"

    onAcOnlineChanged: {
        if (root.acOnline && !root.acPrev && root.isLaptop) root.showAcToast();
        root.acPrev = root.acOnline;
    }
    function showAcToast(kind) {
        root.acToastKind = kind || "charge";
        root.acToastShown = true;
        if (root.expanded) root.collapse();
        acToastTimer.restart();
        root.playSound(root.acToastKind === "lowbatt" ? "disconnect" : "charge");
    }
    function showBattLowToast() { root.showAcToast("lowbatt"); }
    function dismissAcToast() {
        root.acToastShown = false;
        acToastTimer.stop();
    }
    Timer {
        id: acToastTimer
        interval: root.acToastKind === "lowbatt" ? 3500 : 2300
        onTriggered: root.dismissAcToast()
    }

    // rfkill can keep the adapter softlocked (after
    // previous session, hibernation, kernel). While it is blocked, BlueZ does not give
    // turn on the power, and the tile “clicked” idle. Remove the lock before
    // turning on. rfkill without root removes only soft-block - that's enough.
    Process { id: pBtUnblock; command: ["rfkill", "unblock", "bluetooth"] }
    Process { id: pBtHelper; command: ["sh", "-c", ""] }
    function runBtCmd(args) {
        pBtHelper.command = ["sh", "-c", Quickshell.env("HOME") + "/.config/zenith/scripts/bluetooth.sh " + args];
        pBtHelper.running = true;
    }
    function toggleBt() {
        runBtCmd("toggle");
        if (btAdapter) {
            if (!btAdapter.enabled) {
                pBtUnblock.running = true;
                btPowerOn.restart();           // let rfkill take effect
            } else {
                btAdapter.enabled = false;
            }
        }
    }
    Timer {
        id: btPowerOn
        interval: 250
        onTriggered: if (root.btAdapter) root.btAdapter.enabled = true;
    }
    function scanBt() {
        runBtCmd("scan");
        if (btAdapter && btAdapter.enabled) {
            // without pairable, pairing of the new device did not start, and the headphones
            // stuck in the “connected - disconnected” cycle
            btAdapter.pairable = true;
            btAdapter.discovering = true;
            btScanStop.restart();
        }
    }
    Timer { id: btScanStop; interval: 12000; onTriggered: if (root.btAdapter) root.btAdapter.discovering = false }
    function connectBt(addr) {
        if (!addr) return;
        runBtCmd("connect " + addr);
    }
    function disconnectBt(addr) {
        runBtCmd("disconnect " + (addr || ""));
    }

    // -------------------------------------------------------------------- IPC
    IpcHandler {
        target: "pill"
        // voice input indicator: calls voxtype.sh at different stages
        function voxListening(): void { root.voxState = "listening"; }
        function voxTranscribing(): void { root.voxState = "transcribing"; }
        function voxDone(): void {
            root.voxState = "";
            root.playSound("voice_done");
        }
        function voxUnavailable(): void {
            root.voxState = "";
            root.recError = root.tr("voxtype не установлен");
        }
        function launcher(): void { root.toggleLauncher(); }
        function overview(): void { root.toggleOverview(); }
        // Always Wi-Fi/Bluetooth tiles, even when music is playing
        function controls(): void { root.togglePage("main"); }
        function wifi(): void {
            if (root.expanded && root.page === "wifi") { root.collapse(); return; }
            root.togglePage("wifi");
            root.refreshWifiList(); root.scanWifi();
        }
        function bluetooth(): void {
            if (root.expanded && root.page === "bt") { root.collapse(); return; }
            root.togglePage("bt");
            root.scanBt();
        }
        function testBtToast(name: string, type: string): void {
            root.showBtToast(name || "AirPods Pro", type || "earbuds", false);
        }
        function testBtLowBatt(name: string, type: string): void {
            root.showBtLowBattToast(name || "AirPods Pro", type || "earbuds");
        }
        function testWifiToast(ssid: string, quality: string): void {
            root.showWifiToast(ssid || "Wi-Fi Network", parseInt(quality) || 85, false);
        }
        function settings(): void { root.settingsTab = 0; root.togglePage("settings"); }
        // open the settings window immediately on the desired section: convenient to hang on
        // keyboard shortcut and is indispensable when checking the settings themselves
        function settingsAt(tab: string): void {
            root.settingsTab = parseInt(tab) || 0;
            if (root.page !== "settings" || !root.expanded) root.togglePage("settings");
        }
        function shortcuts(): void { root.toggleKeysWindow(); }
        function clipboard(): void { root.togglePage("clip"); }
        function powermenu(): void { root.togglePage("power"); }
        function weather(): void { root.togglePage("weather"); }
        function weatherClose(): void { if (root.page === "weather") root.collapse(); }
        function smartClose(): string {
            if (!root.cfg.closeZenithFirst) return "disabled";
            var anyOpen = root.expanded || root.overviewOpen || root.wallsOpen || root.keysWindowOpen || root.whatsNewOpen || root.weatherDetailsOpen;
            if (anyOpen) {
                if (root.weatherDetailsOpen) root.weatherDetailsOpen = false;
                else if (root.overviewOpen) root.closeOverview();
                else if (root.wallsOpen) root.closeWalls();
                else if (root.keysWindowOpen) root.closeKeysWindow();
                else if (root.whatsNewOpen) root.dismissWhatsNew();
                else if (root.expanded) root.collapse();
                return "closed_overlay";
            }
            return "none";
        }
        function cancelCapture(): void { root.cancelCaptureRequested(); }
        // Freeze frame for selecting an area, see scripts/shot.sh
        function freeze(path: string): void { root.freezeShot = "file://" + path; }
        function unfreeze(): void { root.freezeShot = ""; }
        function shotCopied(path: string): void { root.shotCopied(path); }
        function collapse(): void { root.collapse(); }
        function notifications(): void { root.togglePage("notif"); }
        function audio(): void { root.togglePage("audio"); }
        function calendar(): void { root.togglePage("cal"); }
        function theme(): void { root.toggleWalls(); }
        function widgets(): void { root.cfg.featWidgets = !root.cfg.featWidgets; root.saveCfg(); }
        function record(): void { root.togglePage("record"); }
        function files(): void { root.togglePage("files"); }
        function filesWin(): void { root.openFilesWindow(""); }
        // Open Explorer immediately in the desired directory. It is necessary that the system
        // could assign it as an inode/directory handler: without the “open” path
        // folder" would always lead to the same directory.
        function filesAt(path: string): void { root.openFilesAt(path); }
        function passwords(): void { root.togglePage("vault"); }
        function agents(): void { root.openAgents(); }
        function media(path: string): void { root.openMedia(path); }
        // toggle area selection in the player (same as the “Crop” button)
        function mediaCrop(): void { root.mediaCropToggle(); }
        function recordToggle(): void { root.toggleRecord(); }
        function dnd(): void { root.toggleDnd(); }
        // Brightness comes from smart_brightness.sh: there is no service for it.
        //
        // In addition to the overlay, we also move the slider itself in quick settings. He
        // reads the list of screens, and it is filled only upon request - from
        // The list of laptop keys was not updated, and the slider remained there,
        // where he was abandoned last time, showing a lie.
        function brightness(pct: string): void {
            var v = parseFloat(pct);
            root.showOsd("bright", v / 100.0, false);

            var l = root.brightList.slice();
            var hit = false;
            for (var i = 0; i < l.length; i++) {
                // The keys control the backlight of the built-in screen - it has
                // list sign “bl:” - and external monitors hang on DDC, and
                // These keys do not reach them.
                if (String(l[i].id).indexOf("bl:") === 0 || l.length === 1) {
                    l[i] = { id: l[i].id, name: l[i].name, pct: Math.round(v) };
                    hit = true;
                }
            }
            if (hit) root.brightList = l;
            // The list has not been compiled yet - let’s collect it: without it, there is no slider at all.
            else if (l.length === 0) root.brightRefresh(false);
        }
        // Power saving mode also dampens movement in the shell: animations -
        // the most expensive thing she does without asking. The setting is the same as on
        // Motion tab, so the mode honestly returns it when exiting.
        function motion(on: string): void {
            root.cfg.reduceMotion = (on !== "on");
            root.saveCfg();
        }
        function features(): void { root.togglePage("features"); }
        function docker(): void { root.togglePage("docker"); }
        function calc(): void { root.togglePage("calc"); }
        function terminals(): void { root.togglePage("terminals"); }
        function tasks(): void { root.togglePage("tasks"); }
        function regex(): void { root.togglePage("regex"); }
        function picker(): void { root.togglePage("picker"); }
        function cheat(): void { root.togglePage("cheat"); }
        function profile(): void { root.togglePage("profile"); }
        function close(): void { root.collapse(); }
    }

    // ----------------------------------------------------------------- window
    // The screen on which the island hangs. The Wayland layer is recreated when changing,
    // so we calculate it carefully: the name from the settings - only if such an output
    // is now connected, otherwise (and in “auto” mode) we go for the focus. If
    // Hyprland has not responded yet, we give null - Quickshell will take the screen itself.
    screen: root.pickScreen

    readonly property var pickScreen: {
        var want = root.cfg.pillScreen;
        if (want && want !== "auto") {
            var all = Quickshell.screens;
            for (var i = 0; i < all.length; i++)
                if (all[i].name === want) return all[i];
        }
        if (Compositor.isNiri) {
            var nm = Compositor.focusedMonitor;
            return (nm && nm.screen) ? nm.screen : null;
        }
        var fm = Hyprland.focusedMonitor;
        return (fm && fm.screen) ? fm.screen : null;
    }

    // We press against three edges: the one towards which remains free
    // the panel opens. Otherwise the layer would take up the entire screen and the exclusiveZone
    // (the place for the island) would be considered from the wrong edge.
    anchors.top:    !root.pillAtBottom
    anchors.bottom: !root.pillAtTop
    anchors.left:   !root.pillAtRight
    anchors.right:  !root.pillAtLeft
    // The height of the window is CONSTANT and equal to the screen.
    //
    // Previously it switched 560 <-> 1080 when docking the panel, and the layer
    // Wayland was recreated right in the middle of the animation: the content kept up
    // collapse and decompose again. This is exactly what looked like a jerk when
    // opening the calendar by clicking on the clock.
    //
    // A constant height does not break anything: as long as the panel is not fixed, input
    // is limited by the capsule mask, and clicks pass through the window as before.
    implicitHeight: root.screen ? root.screen.height : 1080
    // for lateral positions the vertical edge is free, and the width is
    // the window should also set itself
    implicitWidth: root.screen ? root.screen.width : 1920
    color: "transparent"
    // gap between pill and windows
    exclusiveZone: (root.pillHidden || (root.fullscreenActive && !root.expanded))
                   ? 0 : pillH + gap
    WlrLayershell.layer: WlrLayer.Overlay
    // While the window is maximized on top of the screen, the pill is not visible at all.
    // We show it back if the panel was opened using the keys or if
    // you need to show the volume/brightness level.
    visible: !root.fullscreenActive || root.expanded || root.osdActive
    // We catch clicks only where the pill is drawn
    // While the pinned page is open, the entire window accepts input:
    // otherwise clicks on the panel (especially on centered settings)
    // fell past, and the sliders did not react.
    // Is the island hidden right now? Everything for which it is shown at all -
    // open panel, dragging, volume - keeps it on the screen.
    readonly property bool pillHidden: root.cfg.pillAutoHide
                                       && !root.expanded && !root.holdOpen
                                       && !root.osdActive && !root.pillDragging
                                       && !revealHover.hovered && !capsuleHover.hovered

    // Appearing from behind the edge is not a reason to reveal yourself. The island goes straight out
    // under a stationary cursor, and opening on hover worked automatically:
    // a person wanted to see a watch, but received a panel. Cocking the opening
    // again only when the cursor actually moves after that.
    onPillHiddenChanged: {
        if (root.pillHidden) return;
        root.hoverExpandArmed = false;
        capsuleHover.markArmPoint();
    }

    // The strip is at the very edge: the hidden island cannot be caught with the cursor, and
    // there is nothing to return it with - except for a narrow zone that catches the guidance.
    Item {
        id: revealStrip
        visible: root.cfg.pillAutoHide
        anchors.top:    root.pillAtBottom ? undefined : parent.top
        anchors.bottom: root.pillAtBottom ? parent.bottom : undefined
        anchors.left:   root.pillAtRight  ? undefined : parent.left
        anchors.right:  root.pillAtRight  ? parent.right : undefined
        width:  root.pillSide ? 4 : parent.width
        height: root.pillSide ? parent.height : 4
        HoverHandler { id: revealHover }
    }

    Region {
        id: capsuleRegion
        item: capsule
        Region { item: (featuresPillBtn.canShow && featuresPillBtn.opacity > 0.8) ? featuresPillBtn : null; intersection: Intersection.Combine }
        // a hidden island off the screen, and you can’t call it without a stripe
        Region { item: revealStrip; intersection: Intersection.Combine }
    }

    Rectangle {
        id: featuresPillBtn
        readonly property bool canShow: !root.expanded && !root.morphing && !root.overviewOpen && !root.wallsOpen && !root.pillHidden && (capsule.width <= capsule.idleLen + 10)
        visible: canShow && opacity > 0.01
        opacity: canShow ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 160 } }
        z: 9
        anchors.right: capsule.left
        anchors.rightMargin: 8
        anchors.top: capsule.top
        width: Math.max(30, capsule.height)
        height: Math.max(30, capsule.height)
        radius: height / 2
        color: featBtnMa.containsMouse ? Qt.rgba(root.colOn.r, root.colOn.g, root.colOn.b, 0.28) : Qt.rgba(0, 0, 0, 0.65)
        border.color: featBtnMa.containsMouse ? root.colOn : Qt.rgba(1, 1, 1, 0.16)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 140 } }
        Behavior on border.color { ColorAnimation { duration: 140 } }

        Text {
            anchors.centerIn: parent
            text: "󰀻"
            color: featBtnMa.containsMouse ? root.colOn : root.colFg
            font { family: root.fontFam; pixelSize: 13 }
        }

        MouseArea {
            id: featBtnMa
            anchors.fill: parent
            enabled: featuresPillBtn.canShow
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.togglePage("features")
        }
    }
    mask: root.holdOpen ? null : capsuleRegion
    // The launcher takes the keyboard immediately (Exclusive) so that you can
    // print without clicking. OnDemand gives focus only after a mouse click.
    WlrLayershell.keyboardFocus: root.holdOpen ? WlrKeyboardFocus.Exclusive
                                              : WlrKeyboardFocus.None

    readonly property Item activePanel: capsule

    // Click past the docked panel to close it.
    // The areas lie strictly AROUND the capsule, so clicking outside collapses it.
    Repeater {
        model: 4
        MouseArea {
            required property int index
            enabled: root.holdOpen || root.expanded
            visible: enabled
            // 0 - top, 1 - bottom, 2 - left, 3 - right of the capsule
            x: index === 3 ? capsule.x + capsule.width : 0
            y: index === 1 ? capsule.y + capsule.height
             : index >= 2 ? capsule.y : 0
            width:  index < 2 ? root.width
                  : index === 2 ? capsule.x
                                : Math.max(0, root.width - capsule.x - capsule.width)
            height: index === 0 ? capsule.y
                  : index === 1 ? Math.max(0, root.height - capsule.y - capsule.height)
                                : capsule.height
            onClicked: root.collapse()
        }
    }

    // A snapshot of the previous wallpaper: lies below the pill and above the desktop,
    // It doesn’t catch clicks - the window mask still lets them through.
    Image {
        anchors.fill: parent
        z: -5
        // While there is no crossfade, the picture is not needed and should not be in memory:
        // unpacked wallpaper in full screen is ten megabytes, which
        // hung around the clock for the sake of seven hundred milliseconds of transition.
        source: (root.themeFading || opacity > 0.01) ? root.themeFadeWall : ""
        fillMode: Image.PreserveAspectCrop
        // wallpapers can be 75 megapixels: without limit Qt refuses them
        // decode (256 MB limit per image) and the crossfade did not appear
        sourceSize.width: root.screen ? root.screen.width : 1920
        asynchronous: false
        cache: false
        visible: opacity > 0.01
        opacity: root.themeFading ? 1 : 0
        Behavior on opacity {
            NumberAnimation { duration: 700; easing.type: Easing.InOutCubic }
        }
    }

    // Illuminated edge to which the island will attach. While they are dragging across the void,
    // nothing is burning, which means there is nowhere to let go, it will return to its place.
    Repeater {
        model: ["top", "bottom", "left", "right"]
        Rectangle {
            required property string modelData
            readonly property bool side: modelData === "left" || modelData === "right"
            readonly property bool lit: root.pillDragging && root.dragEdge === modelData

            width:  side ? 4 : parent.width
            height: side ? parent.height : 4
            x: modelData === "right" ? parent.width - width : 0
            y: modelData === "bottom" ? parent.height - height : 0
            z: 80
            radius: 2
            color: root.colOn
            opacity: lit ? 0.9 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: 140 } }
        }
    }

    // ------------------------------------------------------------- the pill itself
    Rectangle {
        id: capsule

        // It is pressed to its edge and grows from it - therefore, “opening to
        // center" is obtained by itself, without a separate direction animation.
        anchors.top:    root.pillAtTop    ? parent.top    : undefined
        anchors.bottom: root.pillAtBottom ? parent.bottom : undefined
        anchors.left:   root.pillAtLeft   ? parent.left   : undefined
        anchors.right:  root.pillAtRight  ? parent.right  : undefined
        anchors.horizontalCenter: root.pillSide ? undefined : parent.horizontalCenter
        anchors.verticalCenter:   root.pillSide ? parent.verticalCenter : undefined

        // at the edge - 0, in settings mode - in the center of the screen
        // Outside of cutout mode, the island moves away from the edge on islandGap: it
        // ceases to be a continuation of the edge of the screen and becomes separate
        // capsule hanging next to him.
        readonly property real freeGap: root.cfg.notchMode ? 0 : root.cfg.islandGap
        // The entire hidden island goes off the edge: negative padding
        // takes it outside the window, and nothing remains on the screen.
        readonly property real edgeMargin: root.settingsMode && !root.pillSide
                                           ? Math.max(24, (root.height - targetH) / 2)
                                           : root.pillHidden ? -(targetH + 4) : freeGap
        // at the lateral positions, the horizontal indentation already tears off from the edge
        readonly property real sideMargin: root.settingsMode && root.pillSide
                                           ? Math.max(24, (root.width - width) / 2)
                                           : root.pillHidden ? -(width + 4) : freeGap
        anchors.topMargin:    root.pillAtTop    ? edgeMargin : 0
        anchors.bottomMargin: root.pillAtBottom ? edgeMargin : 0
        anchors.leftMargin:   root.pillAtLeft   ? sideMargin : 0
        anchors.rightMargin:  root.pillAtRight  ? sideMargin : 0
        Behavior on anchors.leftMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }
        Behavior on anchors.rightMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }
        Behavior on anchors.topMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }
        Behavior on anchors.bottomMargin {
            NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic }
        }

        // The rolled island is measured along its edge and across it: at
        // in lateral positions it stands vertically, so the length goes to
        // height, and thickness - width.
        // collapsedW specifies the bottom border, not the width itself: content
        // the collapsed island changes (clock, track, volume splash), and
        // a rigid width would cut it off.
        // Nothing wears the island noticeably longer: there are dots along the edges
        // tables and three indicators at once, and at the common lower limit all this
        // pressed close to the clock.
        readonly property int collapsedMin: root.themeNothing
                ? Math.max(root.cfg.collapsedW, 420) : root.cfg.collapsedW

        // Round to an even number of pixels. The island is in the center of the screen,
        // that is, its x is equal to half the difference in width: for odd or
        // fractional length it falls on half a pixel, and concave corners on the sides
        // - individual elements with their own coordinates - arrive at the same
        // half. A smoothed gray gap remains at the junction, and the right corner
        // begins to read as if glued separately.
        //
        // It never came to this before: the content was narrower than the lower border, and
        // exactly the same number of settings worked. The dot numbers are wider, and
        // the fractional width of the content began to fall out.
        function evenUp(v) { return Math.round(v / 2) * 2; }

        readonly property real idleLen: root.voxActive
                    ? capsule.evenUp(Math.max(voxCapsule.implicitWidth + 40, 240))
                : root.recPickActive
                    ? capsule.evenUp(Math.max(recPickCapsule.implicitWidth + 28, 240))
                : root.btToastActive
                    ? capsule.evenUp(Math.max(btCapsule.implicitWidth + 48, 240))
                : root.wifiToastActive
                    ? capsule.evenUp(Math.max(wifiCapsule.implicitWidth + 48, 240))
                : root.acToastActive
                    ? capsule.evenUp(Math.max(acCapsule.implicitWidth + 48, 240))
                : root.toastActive ? 440
                : root.osdActive ? capsule.evenUp(osdCapsule.implicitWidth + 32)
                : root.pillSide  ? capsule.evenUp(Math.max(vertCapsule.implicitHeight + 30,
                                                           capsule.collapsedMin))
                : root.themeNothing
                    ? capsule.evenUp(Math.max(nothingCapsule.implicitWidth + 28, capsule.collapsedMin))
                    : capsule.evenUp(Math.max(idleCapsule.implicitWidth + 28, capsule.collapsedMin))
        readonly property real idleThick: (root.btToastActive || root.wifiToastActive || root.acToastActive
                    || root.recPickActive || root.voxActive)
                ? root.pillH
                : root.toastActive
                ? toastCapsule.implicitHeight + 24 : root.pillH

        width: root.settingsMode ? root.settingsW
             : (root.expanded && !root.cfg.pillKeepVisible) ? (root.page === "weather" ? Math.min(root.width - 40, 960) : root.panelW)
             : root.pillSide     ? idleThick
                                 : idleLen
        // target height - height is animated towards it and immediately after it
        // centering is calculated so that the movement is one-stage
        // Content height is kept separate: new view when changing page
        // on the first frame it has not yet been decomposed and its implicitHeight is zero.
        // Previously, the capsule had time to collapse to zero and decompose again -
        // hence the jerk when switching, for example, from tiles to the calendar.
        property real contentH: 220

        // The layout of a new page takes several passes: calendar grid
        // out of 42 cells it manages to give intermediate heights. If applied
        // each time, the capsule twitches. We collect them in one step using a timer.
        Timer {
            id: contentSettle
            interval: 24
            onTriggered: capsule.applyContentH()
        }
        function refreshContentH() { contentSettle.restart(); }
        function applyContentH() {
            var it = contentLoader.item;
            if (!it || it.implicitHeight <= 40) return;
            var target = it.implicitHeight + 30;
            // Minor vibrations of the layout do not move the target. Height goes through
            // Behavior, and for every change in the goal it starts an animation
            // again - from the current point and for the full duration. Bye page
            // is further marked, the target manages to change several times, and instead of
            // One smooth growth of the capsule goes in steps. The difference is
            // a few pixels are not visible to the eye, but the restart is visible.
            if (Math.abs(target - capsule.contentH) < 8) return;
            capsule.contentH = target;
        }
        Connections {
            target: contentLoader
            function onItemChanged() { capsule.refreshContentH(); }
        }
        Connections {
            target: contentLoader.item
            ignoreUnknownSignals: true
            function onImplicitHeightChanged() { capsule.refreshContentH(); }
        }

        // The expanded panel is no higher than expandedH: pages can be long, but
        // their height is limited by their own scrolling, and not by the island.
        readonly property real targetH: root.expanded
                ? Math.min(contentH, root.settingsMode ? (root.height - 48) : Math.min(root.height - 48, Math.max(root.cfg.expandedH, 700)))
                : root.pillSide ? idleLen
                                : idleThick
        // No higher than the screen: Side edges have a vertical page layout
        // gave off such a height that the island unfolded in full screen.
        height: Math.min(targetH, root.height - root.gap * 2)

        // Transfer: the capsule is moved from its place on dragDX/dragDY. Bye
        // drag - without animation, so that it follows the cursor exactly; on release
        // the offset is reset to zero and it reaches the edge itself.
        transform: Translate {
            x: root.dragDX
            y: root.dragDY
            Behavior on x {
                enabled: !root.pillDragging
                NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                enabled: !root.pillDragging
                NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
            }
        }

        onXChanged:      root.pillRectX = capsule.x
        onYChanged:      root.pillRectY = capsule.y
        onWidthChanged:  root.pillRectW = capsule.width
        onHeightChanged: root.pillRectH = capsule.height
        Component.onCompleted: {
            root.pillRectX = capsule.x;      root.pillRectY = capsule.y;
            root.pillRectW = capsule.width;  root.pillRectH = capsule.height;
        }

        // While the wallpaper carousel is open, the island is hidden: she grew out of it,
        // and two islands on the screen would look like two panels at once.
        opacity: root.wallsOpen ? 0 : 1
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: root.animFast } }

        color: root.colBg
        // The corners of the pressed edge are cut off, and those of the edge facing the screen are rounded:
        // this way the island looks like it has grown out of the edge rather than being glued to it.
        // In the settings mode, the capsule comes off the edge, and round
        // become all four.
        // The capsule torn from the edge is round on all sides: cut it off
        // The corners are no good, the edge no longer holds it.
        readonly property real edgeR: (root.settingsMode || !root.cfg.notchMode)
                                      ? (root.cfg.islandRadius > 0 ? root.cfg.islandRadius : 26)
                                      : 0
        readonly property real freeR: (root.settingsMode || (root.expanded && !root.cfg.pillKeepVisible))
                ? (root.cfg.islandRadius > 0 && !root.cfg.notchMode ? root.cfg.islandRadius : 26)
                : (root.cfg.islandRadius > 0 && !root.cfg.notchMode
                   ? root.cfg.islandRadius : root.pillH / 2)
        topLeftRadius:     root.pillAtTop || root.pillAtLeft  ? edgeR : freeR
        topRightRadius:    root.pillAtTop || root.pillAtRight ? edgeR : freeR
        bottomLeftRadius:  root.pillAtBottom || root.pillAtLeft  ? edgeR : freeR
        bottomRightRadius: root.pillAtBottom || root.pillAtRight ? edgeR : freeR
        Behavior on topLeftRadius  { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }
        Behavior on topRightRadius { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }

        // Niente bordo, in nessuno stato: e' l'unica differenza di stile che
        // c'era fra pillola e pannello. Un bordo largo 1 viene disegnato
        // *inside* in the rectangular shape, when it was transparent, it flaked
        // passare 1px di sfondo sul lato superiore: da qui l'impressione che
        // la pillola non fosse attaccata al bordo dello schermo e che il fondo
        // cambiasse all'apertura.
        border.width: 0

        // Bounce from the Motion tab lives here: the island changes size according to
        // curve with overshoot, and the slider sets how strongly it
        // passes the target before settling. At zero there is no flight and
        // the curve is normal - the movement simply stops.
        Behavior on width {
            NumberAnimation {
                duration: root.animMs
                easing.type: root.animBounce > 0 ? Easing.OutBack : Easing.InOutCubic
                easing.overshoot: root.easeOvershoot
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: root.morphing ? root.animMs : root.animQuick
                easing.type: root.animBounce > 0 ? Easing.OutBack
                           : root.morphing ? Easing.InOutCubic : Easing.OutCubic
                easing.overshoot: root.easeOvershoot
            }
        }
        Behavior on bottomLeftRadius  { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }
        Behavior on bottomRightRadius { NumberAnimation { duration: root.animMs; easing.type: Easing.InOutCubic } }

        clip: true

        // --- the cursor is tracked over all content
        HoverHandler {
            id: capsuleHover
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            // Where was the cursor when opening on hover was prohibited?
            // The ban is placed after moving the island and after clicking on
            // notification, but it was removed only by leaving the cursor from the island.
            // If the island stood exactly under the stationary cursor (and after
            // transfer to the edge is what happens), there was nothing to leave:
            // the ban remained forever, and the panel could no longer be opened.
            // Therefore, it can also be removed by a meaningful mouse shift.
            property point armPos: Qt.point(-9999, -9999)
            // the starting point is set by those places that prohibit disclosure
            function markArmPoint() {
                capsuleHover.armPos = capsuleHover.hovered
                        ? capsuleHover.point.scenePosition : Qt.point(-9999, -9999);
            }
            onPointChanged: {
                if (root.hoverExpandArmed || !capsuleHover.hovered) return;
                var p = capsuleHover.point.scenePosition;
                if (Math.abs(p.x - capsuleHover.armPos.x)
                    + Math.abs(p.y - capsuleHover.armPos.y) < 12) return;
                root.hoverExpandArmed = true;
                expandTimer.restart();
            }

            onHoveredChanged: {
                // the cursor is on the island again—recalculate the shift from this point
                if (hovered && !root.hoverExpandArmed)
                    capsuleHover.armPos = capsuleHover.point.scenePosition;
                if (hovered) {
                    collapseTimer.stop();
                    expandTimer.restart();
                    rearmTimer.stop();
                } else {
                    expandTimer.stop();
                    collapseTimer.restart();
                    // The cursor has left - we allow expansion again, but not immediately.
                    // When moving to the other edge, the island pops into the frame
                    // from under the cursor, and instant return of resolution
                    // meant that at the new edge it immediately opened under
                    // with the same cursor.
                    rearmTimer.restart();
                }
            }
        }
        // Reveal the tiles. We touch the page only if the panel is still closed:
        // otherwise, hovering would reset the already open list of networks.
        //
        // Tiles always open. Neither the music nor the recording in progress
        // pages are not slipped: the track lives on the card right here, and before
        // recording remote control, one click on the tile - but you don’t have to guess
        // what will open.
        function openPanel() {
            if (!root.expanded) {
                pageResetTimer.stop();
                root.page = "main";
            }
            root.expanded = true;
        }

        Timer {
            id: expandTimer; interval: 0
            onTriggered: {
                if (!capsuleHover.hovered || root.launcherOpen) return;
                if (!root.hoverExpandArmed) return;
                // While the notification is on, hovering does not open the panel:
                // otherwise you won't get to the cross
                if (root.toastActive || root.btToastActive || root.acToastActive || root.recPickActive || root.voxActive) return;
                // When auto-hide by hovering, the island is only shown. He and
                // comes out from behind the edge under this very cursor, so
                // opening next would mean: I wanted to see the time -
                // get a full screen panel. Expands the click.
                if (root.cfg.pillAutoHide) return;
                capsule.openPanel();
            }
        }
        // the cursor should stay to the side, and not just blink past
        Timer {
            id: rearmTimer
            interval: 450
            onTriggered: root.hoverExpandArmed = true
        }
        Timer {
            id: collapseTimer; interval: 180
            onTriggered: {
                if (capsuleHover.hovered || root.holdOpen) return;
                root.collapse();
            }
        }

        // Clicking on a collapsed island expands it. The only way
        // open the panel when auto-hide is enabled, and just convenient -
        // when not: before this the pill did not respond to pressure at all.
        MouseArea {
            anchors.fill: parent
            z: 0
            enabled: !root.expanded && !root.toastActive && !root.pillDragging
                     && !root.osdActive && !root.btToastActive && !root.wifiToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
            cursorShape: Qt.PointingHandCursor
            onClicked: capsule.openPanel()
        }

        // Clicking on the card opens the story. In a separate layer underneath:
        // inside a RowLayout, anchors break the layout.
        // Clicking opens the reason itself: chat, letter, download. Previously card
        // took me to the notification list - I still had to search from there
        // application by hand.
        //
        // z on top of the entire contents of the capsule: while the card is hanging, not a single
        // the area below it should not intercept the click.
        MouseArea {
            anchors.fill: parent
            z: 100
            enabled: root.toastActive
            visible: enabled
            preventStealing: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.notifCurrent) root.activateNotification(root.notifCurrent)
        }

        // ------------------------------------------ collapsed: notification
        RowLayout {
            id: toastCapsule
            // Above the card click area: it itself does not intercept clicks
            // (it's just text and icons), but the cross remains inside
            // accessible - otherwise it would be covered by a transparent area.
            z: 110
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 16
            anchors.rightMargin: 14
            anchors.topMargin: 12
            spacing: 12
            visible: root.toastActive && !root.btToastActive && !root.wifiToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            // program icon, if sent
            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                Layout.alignment: Qt.AlignTop
                radius: 10
                color: root.notifUrgent ? Qt.rgba(1, 0.27, 0.27, 0.18)
                                        : Qt.rgba(1, 1, 1, 0.08)

                Image {
                    id: toastIcon
                    anchors.fill: parent
                    anchors.margins: 5
                    source: root.notifImage
                    // not Ready means it hasn’t opened: it’s better to have your own
                    // icon than a checkered rectangle "broken picture"
                    visible: source != "" && status === Image.Ready
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: !toastIcon.visible
                    text: String.fromCodePoint(root.notifUrgent ? 0xF0026 : 0xF009A)
                    color: root.notifUrgent ? root.colCrit : root.colFg
                    font { family: root.fontFam; pixelSize: root.iconSize - 1 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        Layout.fillWidth: true
                        text: root.notifSummary
                        color: root.colFg
                        elide: Text.ElideRight
                        font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                    }
                    Text {
                        text: root.notifApp
                        color: root.colMuted
                        font { family: root.fontFam; pixelSize: root.fontSize - 5 }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    // “Show text in card” from settings: disabled -
                    // Only the application and title are visible
                    visible: root.notifBody.length > 0 && root.cfg.notifPreview
                    text: root.notifBody
                    color: root.colMuted
                    wrapMode: Text.WordWrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    // The specification allows a subset of markup in the body
                    // (<b>, <i>, <u>, <a>), and we declare our support for it in
                    // bodyMarkupSupported. PlainText showed tags as is -
                    // Telegram sent “<b>Pasha brother</b>” directly in text.
                    textFormat: Text.StyledText
                    font { family: root.fontFam; pixelSize: root.fontSize - 3 }
                }
            }

            // close the toast
            Text {
                Layout.alignment: Qt.AlignTop
                text: "×"
                color: closeMa.containsMouse ? root.colFg : root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize + 2 }
                Behavior on color { ColorAnimation { duration: 150 } }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismissToast()
                }
            }
        }

        // ---------------------------------- collapsed: headphones connected
        // On the left is the headphone icon, in the center is Connected and the device name,
        // on the right is a ring with a charge percentage. Appears for a few seconds
        // when connecting a Bluetooth headset (btToastActive).
        RowLayout {
            id: btCapsule
            z: 110
            // Centered and across the width of the content - without stretching across the entire pill,
            // otherwise the name and ring would move apart at the edges with a large gap.
            anchors.centerIn: parent
            spacing: 11
            visible: root.btToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            // Headphones icon: SVG with white fill, over dark pill
            // visible as is - without repainting the effect, which is invisible
            // the source did not update the texture and left empty space.
            Image {
                Layout.preferredWidth: 22
                Layout.preferredHeight: 22
                Layout.alignment: Qt.AlignVCenter
                // The icon is slightly to the left: increase the gap to the text (capsule
                // is centered, so the icon moves to the left edge).
                Layout.rightMargin: 8
                source: Quickshell.env("HOME") + "/.config/zenith/assets/earbuds.svg"
                sourceSize.width: 44
                sourceSize.height: 44
                fillMode: Image.PreserveAspectFit
                smooth: true
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                // Raise the text slightly relative to the center of the pill -
                // transform so as not to change the line layout.
                transform: Translate { y: -2 }

                Text {
                    text: root.tr("Подключено")
                    color: root.colMuted
                    // We omit only this line - the name remains in place.
                    transform: Translate { y: 2 }
                    font { family: root.fontFam; pixelSize: root.fontSize - 4 }
                }
                Text {
                    // We limit the width so that a long name does not stretch
                    // pill without edge; the short one occupies exactly its width.
                    Layout.maximumWidth: 220
                    text: root.btToastName
                    color: root.colFg
                    elide: Text.ElideRight
                    font { family: root.fontFam; pixelSize: root.fontSize + 1; bold: true }
                }
            }

            // Charge ring. A pale outline over the entire circle, on top of which is an arc from
            // top clockwise, filled to a fraction of the charge. When
            // cards, the arc is drawn with animation from zero to the current one
            // percent; BlueZ does not report the battery immediately, and when it arrives,
            // the arc plays out the rest. In the center is the percentage.
            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                // More air between the name and the ring; the ring is slightly to the right.
                Layout.leftMargin: 64

                // Кольцо заряда при наличии батареи
                Canvas {
                    id: btRing
                    anchors.fill: parent
                    visible: !root.btToastDisconnected && root.btConnectedBattery >= 0

                    readonly property real level:
                        root.btConnectedBattery >= 0 ? root.btConnectedBattery / 100 : 0
                    property real fill: 0
                    readonly property real lineW: 3.5

                    onFillChanged: requestPaint()
                    onLevelChanged: {
                        if (!root.btToastActive) return;
                        btRingAnim.stop();
                        btRingAnim.from = btRing.fill;
                        btRingAnim.to = btRing.level;
                        btRingAnim.start();
                    }

                    NumberAnimation {
                        id: btRingAnim
                        target: btRing; property: "fill"
                        duration: 900; easing.type: Easing.OutCubic
                    }
                    function play() {
                        btRingAnim.stop();
                        btRing.fill = 0;
                        btRingAnim.from = 0;
                        btRingAnim.to = btRing.level;
                        btRingAnim.start();
                    }
                    Connections {
                        target: root
                        function onBtToastActiveChanged() {
                            if (root.btToastActive) btRing.play();
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (width <= 0 || height <= 0) return;
                        var c = (root.btConnectedBattery >= 0 && root.btConnectedBattery <= 20)
                                ? root.colCrit
                                : root.colOn;
                        var r = (Math.min(width, height) - lineW) / 2;
                        var cx = width / 2, cy = height / 2;
                        // pale outline all around
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.22);
                        ctx.stroke();

                        // arc of charge from the top point clockwise
                        if (fill > 0) {
                            var start = -Math.PI / 2;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, start, start + 2 * Math.PI * fill);
                            ctx.strokeStyle = c;
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: String(root.btConnectedBattery)
                        color: root.btConnectedBattery <= 20 ? root.colCrit : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 6; bold: true }
                    }
                }

                // Иконка без батареи
                Rectangle {
                    anchors.fill: parent
                    visible: !root.btToastDisconnected && root.btConnectedBattery < 0
                    radius: 14
                    color: Qt.rgba(1, 1, 1, 0.10)
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF00AF)
                        color: root.colFg
                        font { family: root.fontFam; pixelSize: 14 }
                    }
                }

                // Индикатор отключения
                Rectangle {
                    anchors.fill: parent
                    visible: root.btToastDisconnected
                    radius: 14
                    color: Qt.rgba(1, 0, 0, 0.12)
                    Text {
                        anchors.centerIn: parent
                        text: String.fromCodePoint(0xF00B2)
                        color: root.colCrit
                        font { family: root.fontFam; pixelSize: 14 }
                    }
                }
            }
        }

        // ---------------------------------- свёрнутое: Wi-Fi подключение
        // Слева иконка Wi-Fi, по центру статус (Подключено / Отключено) и имя сети,
        // справа кружок с качеством сигнала или иконка состояния.
        RowLayout {
            id: wifiCapsule
            z: 110
            anchors.centerIn: parent
            spacing: 11
            visible: root.wifiToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Item {
                Layout.preferredWidth: 26
                Layout.preferredHeight: 26
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 4

                Text {
                    anchors.centerIn: parent
                    text: root.wifiToastDisconnected ? "󰤮"
                        : root.wifiToastQuality > 66 ? "󰤨"
                        : root.wifiToastQuality > 33 ? "󰤥" : "󰤟"
                    color: root.wifiToastDisconnected ? root.colCrit : root.colFg
                    font { family: root.fontFam; pixelSize: 22 }
                }
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 0
                transform: Translate { y: -2 }

                Text {
                    text: root.wifiToastDisconnected ? root.tr("Отключено") : root.tr("Подключено")
                    color: root.wifiToastDisconnected ? root.colCrit : root.colMuted
                    transform: Translate { y: 2 }
                    font { family: root.fontFam; pixelSize: root.fontSize - 4 }
                }
                Text {
                    Layout.maximumWidth: 220
                    text: root.wifiToastSsid
                    color: root.colFg
                    elide: Text.ElideRight
                    font { family: root.fontFam; pixelSize: root.fontSize + 1; bold: true }
                }
            }

            // Правая часть: кольцо качества связи или иконка состояния
            Item {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 48

                // Кольцо качества связи (как btRing у наушников)
                Canvas {
                    id: wifiRing
                    anchors.fill: parent
                    visible: !root.wifiToastDisconnected && root.wifiToastQuality >= 0

                    readonly property real level:
                        root.wifiToastQuality >= 0 ? root.wifiToastQuality / 100 : 0
                    property real fill: 0
                    readonly property real lineW: 3.5

                    onFillChanged: requestPaint()
                    onLevelChanged: {
                        if (!root.wifiToastActive) return;
                        wifiRingAnim.stop();
                        wifiRingAnim.from = wifiRing.fill;
                        wifiRingAnim.to = wifiRing.level;
                        wifiRingAnim.start();
                    }

                    NumberAnimation {
                        id: wifiRingAnim
                        target: wifiRing; property: "fill"
                        duration: 900; easing.type: Easing.OutCubic
                    }
                    function play() {
                        wifiRingAnim.stop();
                        wifiRing.fill = 0;
                        wifiRingAnim.from = 0;
                        wifiRingAnim.to = wifiRing.level;
                        wifiRingAnim.start();
                    }
                    Connections {
                        target: root
                        function onWifiToastActiveChanged() {
                            if (root.wifiToastActive) wifiRing.play();
                        }
                    }

                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.reset();
                        if (width <= 0 || height <= 0) return;
                        var c = (root.wifiToastQuality >= 0 && root.wifiToastQuality <= 25)
                                ? root.colCrit
                                : root.colOn;
                        var r = (Math.min(width, height) - lineW) / 2;
                        var cx = width / 2, cy = height / 2;

                        ctx.lineWidth = lineW;
                        ctx.lineCap = "round";

                        // бледный контур
                        ctx.beginPath();
                        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                        ctx.strokeStyle = Qt.rgba(c.r, c.g, c.b, 0.22);
                        ctx.stroke();

                        // дуга качества связи
                        if (fill > 0) {
                            var start = -Math.PI / 2;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, start, start + 2 * Math.PI * fill);
                            ctx.strokeStyle = c;
                            ctx.stroke();
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: String(root.wifiToastQuality)
                        color: root.wifiToastQuality <= 25 ? root.colCrit : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 6; bold: true }
                    }
                }

                // Индикатор отключения
                Rectangle {
                    anchors.fill: parent
                    visible: root.wifiToastDisconnected
                    radius: 14
                    color: Qt.rgba(1, 0, 0, 0.12)
                    Text {
                        anchors.centerIn: parent
                        text: "󰤮"
                        color: root.colCrit
                        font { family: root.fontFam; pixelSize: 14 }
                    }
                }
            }
        }

        // ---- collapsed: charging connected ------------------------------
        // The background of the card is the same charge wave as on the battery button in quick
        // settings (ControlsView.ChargeWave): two running sinusoids in color
        // charge, filled to the battery level. Draws below the content (z below
        // capsules with z:110) and trimmed with a pill clip; goes until the card is on
        // screen.
        Canvas {
            id: acWave
            anchors.fill: parent
            z: 1
            visible: root.acToastActive
            property color tint: root.acToastKind === "lowbatt" ? root.colCrit : root.colOk
            property real level: root.batteryPct / 100
            property real phase: 0
            onPhaseChanged: requestPaint()
            onLevelChanged: requestPaint()
            onTintChanged: requestPaint()

            Timer {
                interval: 45
                running: root.acToastActive && acWave.visible
                repeat: true
                onTriggered: acWave.phase += 0.16
            }

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                if (width <= 0 || height <= 0) return;

                // Clip for pill rounding: the capsule has a rectangular clip, and
                // without this, the wave crawled out into the rounded corners translucent
                // sharp corners. We take the radii from the capsule itself.
                var mr = Math.min(width, height) / 2;
                var tl = Math.min(capsule.topLeftRadius, mr);
                var tr = Math.min(capsule.topRightRadius, mr);
                var br = Math.min(capsule.bottomRightRadius, mr);
                var bl = Math.min(capsule.bottomLeftRadius, mr);
                ctx.beginPath();
                ctx.moveTo(tl, 0);
                ctx.arcTo(width, 0, width, height, tr);
                ctx.arcTo(width, height, 0, height, br);
                ctx.arcTo(0, height, 0, 0, bl);
                ctx.arcTo(0, 0, width, 0, tl);
                ctx.closePath();
                ctx.clip();

                // Keep the level away from the edges: there is a wave at the very top
                // would be cut off and look like an even strip.
                var base = height * (1 - Math.max(0.12, Math.min(0.92, level)));
                var amp = 3.2;

                for (var w = 0; w < 2; w++) {
                    var off = w === 0 ? 0 : Math.PI * 0.7;
                    var k = w === 0 ? 0.055 : 0.041;
                    ctx.beginPath();
                    ctx.moveTo(0, height);
                    for (var x = 0; x <= width; x += 3) {
                        var y = base + amp * Math.sin(k * x + phase + off)
                                     + amp * 0.5 * Math.sin(k * 1.9 * x - phase * 0.7);
                        if (x === 0) ctx.lineTo(0, y); else ctx.lineTo(x, y);
                    }
                    ctx.lineTo(width, height);
                    ctx.closePath();
                    ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, w === 0 ? 0.16 : 0.11);
                    ctx.fill();
                }
            }
        }

        // Charging icon, “Charging” and percentage - one line in the center
        // pills, without ring.
        RowLayout {
            id: acCapsule
            z: 110
            anchors.centerIn: parent
            spacing: 8
            visible: root.acToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.acToastKind === "lowbatt" ? String.fromCodePoint(0xF008E)
                                                      : String.fromCodePoint(0xF0241)
                color: root.acToastKind === "lowbatt" ? root.colCrit : root.colOk
                font { family: root.fontFam; pixelSize: root.iconSize + 3 }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.acToastKind === "lowbatt" ? root.tr("Низкий заряд батареи")
                                                      : root.tr("Заряжается")
                color: root.acToastKind === "lowbatt" ? root.colCrit : root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.batteryPct + "%"
                color: root.acToastKind === "lowbatt" ? root.colCrit : root.colOk
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }
        }

        // ---- collapsed: select screen for recording -------------------------
        // Several monitors - we ask which one to write: recording icon,
        // signature and a chip for each screen. Clicking on the chip starts recording
        // exactly this exit; × cancels. z higher than the other capsules - card
        // interactive, clicks should reach the chips.
        RowLayout {
            id: recPickCapsule
            z: 130
            anchors.centerIn: parent
            spacing: 9
            visible: root.recPickActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: String.fromCodePoint(0xF044A)
                color: root.colCrit
                font { family: root.fontFam; pixelSize: root.iconSize + 2 }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.tr("Записать экран")
                color: root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }
            Repeater {
                model: root.recPickMons
                delegate: Rectangle {
                    required property var modelData
                    Layout.alignment: Qt.AlignVCenter
                    radius: 9
                    implicitWidth: chipTxt.implicitWidth + 20
                    implicitHeight: 26
                    color: chipMa.containsMouse ? root.colOn : Qt.rgba(1, 1, 1, 0.10)
                    Behavior on color { ColorAnimation { duration: 120 } }

                    Text {
                        id: chipTxt
                        anchors.centerIn: parent
                        text: modelData.name
                        color: chipMa.containsMouse ? "#ffffff" : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 2; bold: true }
                    }
                    MouseArea {
                        id: chipMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.startRecordOn(modelData.name)
                    }
                }
            }
            Text {
                Layout.alignment: Qt.AlignVCenter
                text: "×"
                color: pickCloseMa.containsMouse ? root.colFg : root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize + 2 }
                MouseArea {
                    id: pickCloseMa
                    anchors.fill: parent
                    anchors.margins: -6
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelRecPick()
                }
            }
        }

        // ---- collapsed: voice input (voxtype) ------------------------
        // While the button/key is pressed - “Listening...” with a pulsating point; after
        // releasing while voxtype is typing the text - “I’m deciphering...”.
        RowLayout {
            id: voxCapsule
            z: 120
            anchors.centerIn: parent
            spacing: 10
            visible: root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: String.fromCodePoint(0xF036C)   // microphone
                color: root.voxState === "listening" ? root.colCrit : root.colOn
                font { family: root.fontFam; pixelSize: root.iconSize + 3 }

                // soft pulsing while we listen
                SequentialAnimation on opacity {
                    running: root.voxState === "transcribing"
                    loops: Animation.Infinite
                    NumberAnimation { from: 1.0; to: 0.35; duration: 500; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.35; to: 1.0; duration: 500; easing.type: Easing.InOutSine }
                }
                onVisibleChanged: if (!visible) opacity = 1
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.voxState === "transcribing" ? root.tr("Расшифровываю…")
                                                       : root.tr("Слушаю…")
                color: root.colFg
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }

            MicWaveBars {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 48
                Layout.preferredHeight: 18
                visible: root.voxState === "listening"
                active: root.voxState === "listening" && root.voxActive
                barColor: root.colCrit
                barCount: 9
                gap: 2.5
            }
        }

        // ------------------------------------------- collapsed: level (OSD)
        RowLayout {
            id: osdCapsule
            anchors.centerIn: parent
            height: root.pillH
            spacing: 12
            visible: root.osdActive && !root.toastActive && !root.btToastActive && !root.wifiToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
            opacity: visible ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            Text {
                text: root.osdIcon
                color: root.osdMuted ? root.colMuted : root.colFg
                // Fixed width: volume, microphone, and sun glyphs
                // of different widths, which is why the pill twitched when changing levels.
                Layout.preferredWidth: mOsdIcon.width + 4
                horizontalAlignment: Text.AlignHCenter
                font { family: root.fontFam; pixelSize: root.iconSize }
                Behavior on color { ColorAnimation { duration: 160 } }
            }

            Rectangle {
                Layout.preferredWidth: 150
                Layout.preferredHeight: 5
                Layout.alignment: Qt.AlignVCenter
                radius: 3
                color: Qt.rgba(1, 1, 1, 0.16)

                Rectangle {
                    width: parent.width * (root.osdMuted ? 0 : root.osdValue)
                    height: parent.height
                    radius: 3
                    color: root.osdKind === "bright" ? root.colWarn : root.colOn
                    Behavior on width {
                        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
                    }
                    Behavior on color { ColorAnimation { duration: 160 } }
                }
            }

            Text {
                Layout.preferredWidth: mBatt.width
                horizontalAlignment: Text.AlignRight
                text: root.osdMuted ? "—" : Math.round(root.osdValue * 100) + "%"
                color: root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            }
        }

        // Width standards: the numbers in the pill rank according to the widest
        // option, so the capsule does not stretch or contract while moving.
        TextMetrics {
            id: mClock
            font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            // The standard for the widest version of EXACTLY the current format:
            // with seconds the line is longer, and space for it is reserved
            // old - the clock overlapped with the neighbors, and the island stood end-to-end.
            text: (root.cfg.clock12 ? "12:00" : "00:00")
                  + (root.cfg.clockSeconds ? ":00" : "")
                  + (root.cfg.clock12 ? " PM" : "")
        }
        TextMetrics {
            id: mBatt
            font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            text: "100%"
        }
        TextMetrics {
            id: mBattIcon
            font { family: root.fontFam; pixelSize: root.iconSize }
            // charge glyphs are monospaced among themselves, one sample is enough
            text: String.fromCodePoint(0xF0079)
        }
        TextMetrics {
            id: mOsdIcon
            font { family: root.fontFam; pixelSize: root.iconSize }
            // the widest level glyph used
            text: String.fromCodePoint(0xF057E)
        }
        TextMetrics {
            id: mWs
            font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            text: "10"
        }

        // ---------------------------------------------------- rolled up: peace
        RowLayout {
            id: idleCapsule
            anchors.centerIn: parent
            height: root.pillH
            spacing: 14
            // On the Nothing theme, the collapsed island is arranged differently - it is collected
            // nothingCapsule, and this layout entirely gives way to it.
            visible: !root.themeNothing && !root.expanded && !root.osdActive && !root.toastActive && !root.btToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
            // Transparency, not visible: the hidden layout has an implicitWidth
            // equal to zero, and the island would calculate its length by emptiness.
            opacity: root.pillSide ? 0 : (visible ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            // ------------------------------------------------ plays media
            // The player is no longer a separate state of the pill: cover, title and
            // the stripes simply stand to the left of the day of the week, and the clock, table and charge
            // remain in place. So the pill is not “replaced” with music.
            RowLayout {
                id: mediaSeg
                spacing: 9
                visible: root.mediaActive
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.animFast } }

                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignVCenter
                    radius: 6
                    color: Qt.rgba(1, 1, 1, 0.08)
                    // Rectangle clip is rectangular - the corners of the cover are from it
                    // spicy. We round the image itself with a mask along the radius:
                    // hidden Image source + mask, and draws MultiEffect.
                    Image {
                        id: capsuleArt
                        anchors.fill: parent
                        source: root.mediaArt
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 56
                        visible: false
                        layer.enabled: true
                    }
                    Item {
                        id: capsuleArtMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        Rectangle { anchors.fill: parent; radius: 6; color: "#ffffff" }
                    }
                    MultiEffect {
                        anchors.fill: parent
                        source: capsuleArt
                        maskEnabled: true
                        maskSource: capsuleArtMask
                        visible: capsuleArt.status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: capsuleArt.status !== Image.Ready
                        text: "󰝚"
                        color: root.colMuted
                        font { family: root.fontFam; pixelSize: 11 }
                    }
                }

                Text {
                    Layout.maximumWidth: 150
                    Layout.alignment: Qt.AlignVCenter
                    text: root.player ? root.player.trackTitle : ""
                    color: root.colFg
                    elide: Text.ElideRight
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                }

                WaveBars {
                    Layout.preferredWidth: 26
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    barColor: root.colFg
                    active: root.player ? root.player.isPlaying : false
                }

                // separator - so that the track is read separately from the clock
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 2
                    color: Qt.rgba(1, 1, 1, 0.14)
                }
            }

            // a lot of work is going on - an icon, a signature and a stripe to the left of the date
            RowLayout {
                spacing: 7
                visible: root.busyLabel.length > 0

                Text {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.busyGlyph
                    color: root.colOn
                    font { family: root.fontFam; pixelSize: root.fontSize - 2 }
                }

                Text {
                    Layout.maximumWidth: 130
                    Layout.alignment: Qt.AlignVCenter
                    text: root.busyLabel
                    color: root.colFg
                    elide: Text.ElideMiddle
                    font { family: root.fontFam; pixelSize: root.fontSize - 2 }
                }

                // A strip, not percentages in numbers: the island is already narrow, but the exact
                // No one needs a number here - what matters is that things are moving.
                Rectangle {
                    id: busyTrack
                    Layout.preferredWidth: 34
                    Layout.preferredHeight: 4
                    Layout.alignment: Qt.AlignVCenter
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.16)
                    clip: true

                    readonly property bool unknown: root.busyProgress < 0

                    Rectangle {
                        id: busyFill
                        // While the percentages are unknown, a short period goes
                        // back and forth: a bar to zero would read “nothing”
                        // is not happening”, and complete – as “already ready”.
                        width: busyTrack.unknown ? parent.width * 0.4
                             : parent.width * Math.min(100, root.busyProgress) / 100
                        height: parent.height
                        radius: parent.radius
                        color: root.colOn
                        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

                        SequentialAnimation on x {
                            running: busyTrack.unknown && busyTrack.visible
                            loops: Animation.Infinite
                            NumberAnimation { from: 0; to: busyTrack.width - busyFill.width
                                              duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: busyTrack.width - busyFill.width; to: 0
                                              duration: 900; easing.type: Easing.InOutSine }
                        }
                        onXChanged: if (!busyTrack.unknown) x = 0
                    }
                }

                // separator - so that the work is read separately from the clock
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    Layout.alignment: Qt.AlignVCenter
                    Layout.leftMargin: 2
                    color: Qt.rgba(1, 1, 1, 0.14)
                }
            }

            // recording in progress - flashing dot and timer to the left of the date
            RowLayout {
                spacing: 6
                visible: root.recActive

                Rectangle {
                    Layout.preferredWidth: 9
                    Layout.preferredHeight: 9
                    Layout.alignment: Qt.AlignVCenter
                    radius: 5
                    color: root.recPaused ? root.colWarn : root.colCrit
                    // When paused, the dot lights up evenly; when recording, it pulsates.
                    SequentialAnimation on opacity {
                        running: root.recActive && !root.recPaused
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 620; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                    }
                    onVisibleChanged: if (!visible) opacity = 1
                }
                Text {
                    text: root.recTimeText
                    color: root.recPaused ? root.colWarn : root.colCrit
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                }
            }

            // Weather before the date: icon and degrees. Widgets on this wallpaper
            // there is no theme, and the island is the only place where the weather is generally
            // visible, that's why it's here and not just on Nothing.
            Item {
                id: idleWthContainer
                visible: root.weatherReady && root.cfg.weatherOnIsland
                implicitWidth: idleWthRow.implicitWidth
                implicitHeight: idleWthRow.implicitHeight
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: idleWthRow
                    anchors.fill: parent
                    spacing: 5

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.weatherGlyph
                        color: idleWthMa.containsMouse ? root.colOn : root.colFg
                        font { family: root.fontFam; pixelSize: root.iconSize - 1 }
                    }
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.weatherTemp + "°"
                        color: idleWthMa.containsMouse ? root.colOn : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                    }

                    // separator - so that the weather is read separately from the date
                    Rectangle {
                        Layout.preferredWidth: 1
                        Layout.preferredHeight: 14
                        Layout.alignment: Qt.AlignVCenter
                        Layout.leftMargin: 3
                        color: Qt.rgba(1, 1, 1, 0.14)
                    }
                }

                MouseArea {
                    id: idleWthMa
                    anchors.fill: parent
                    anchors.rightMargin: 4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openWeatherDetails()
                }
            }

            Text {
                text: root.dayText
                color: root.colMuted
                font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
            }
            Text {
                text: root.timeText
                color: root.colFg
                Layout.preferredWidth: mClock.width
                horizontalAlignment: Text.AlignHCenter
                font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
            }

            // number of the current desktop: scrolls when changing
            FlipText {
                value: String(root.wsId)
                textColor: root.colFg
                fontFam: root.fontFam
                pixelSize: root.fontSize - 1
                minWidth: mWs.width
                Layout.alignment: Qt.AlignVCenter
            }

            // current layout: scrolls with Alt+Shift
            FlipText {
                value: root.kbLayout
                textColor: root.kbLayout === "RU" ? root.tint("#7FB3FF") : root.colMuted
                fontFam: root.fontFam
                pixelSize: root.fontSize - 2
                Layout.alignment: Qt.AlignVCenter
            }

            // System Load on island (CPU% / RAM%)
            RowLayout {
                visible: root.cfg.systemLoadOnIsland && (root.loadCpu >= 0 || root.loadMem >= 0)
                spacing: 5
                Layout.alignment: Qt.AlignVCenter

                Text {
                    text: "󰍛 " + (root.loadCpu >= 0 ? root.loadCpu + "%" : "—")
                    color: root.loadCpu > 80 ? root.colCrit : root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 3; bold: true }
                }

                Text {
                    visible: root.loadMem >= 0
                    text: "󰘚 " + root.loadMem + "%"
                    color: root.loadMem > 85 ? root.colCrit : root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 3; bold: true }
                }
            }

            // Space is reserved for the widest option (“100%”), otherwise
            // the pill would breathe at every percent. But previously the reference
            // the width hung on the number itself, and the entire stock accumulated between
            // icon and numbers - at “48%” there was a gaping hole. Now the width
            // holds the container, and the couple inside stands close in the center.
            Item {
                // without a battery there is no block at all: on a desktop machine this is not
                // “zero percent” and “nothing to show”
                visible: root.batteryPresent
                Layout.preferredWidth: root.batteryPresent
                                       ? mBattIcon.width + battPair.spacing + mBatt.width : 0
                Layout.preferredHeight: root.pillH
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    id: battPair
                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: root.batteryIcon
                        color: root.batteryCharging || root.acOnline ? root.colOk
                             : root.batteryPct <= 15 ? root.colCrit
                             : root.colFg
                        font { family: root.fontFam; pixelSize: root.iconSize }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    Text {
                        text: root.batteryPct + "%"
                        color: root.colMuted
                        font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                    }
                }
            }
        }

        // ------------------------------------------ collapsed: Nothing
        // The clock is located exactly in the center of the island, the tables are on the left, the state
        // cars are on the right. This is not a RowLayout: in a row the clock would move away from
        // center every time a new table point appears on the left or
        // On the right, the charge percentage disappears. Here the edges are separated by anchors,
        // and the same place is reserved for them - the clocks stand firmly.
        Item {
            id: nothingCapsule
            // Stretched over the entire length of the island, rather than compressed by content.
            // Pressed to his width, he stood up in the middle of the pill, and when
            // longer than the contents, the table points were not at the left
            // edges, and somewhere in the middle, along with the rest.
            //
            // implicitWidth remains: it is used to calculate, in short
            // how long the island can no longer be compressed.
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            height: root.pillH
            visible: root.themeNothing && (!root.expanded || (root.cfg.pillKeepVisible && !root.settingsMode)) && !root.btToastActive && !root.wifiToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
                     && !root.osdActive && !root.toastActive
            opacity: root.pillSide ? 0 : (visible ? 1 : 0)
            Behavior on opacity { NumberAnimation { duration: root.animFast } }

            // gap between the clock and the outer groups
            readonly property real armGap: 22

            // Space for table points: five slots of six pixels, gaps
            // between them and a surcharge on the current table - it spreads into a strip
            // and wider than others.
            readonly property int wsSlots: 5
            readonly property real wsReserve:
                nothingCapsule.wsSlots * 6
                + (nothingCapsule.wsSlots - 1) * nLeft.spacing
                + (17 - 6)
            // Both groups get the width of the larger of them: without this, the hours
            // would be considered the center of an empty space rather than an island.
            readonly property real arm:
                Math.max(nLeft.implicitWidth, nRight.implicitWidth)
            implicitWidth: nClock.implicitWidth + 2 * (nothingCapsule.arm + nothingCapsule.armGap)

            // ------------------------------------------- left: tables
            RowLayout {
                id: nLeft
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                // The recording is more important than the tables and therefore comes first: while it’s in progress
                // shooting, you need to know about this before anything else.
                Rectangle {
                    Layout.preferredWidth: 7
                    Layout.preferredHeight: 7
                    Layout.alignment: Qt.AlignVCenter
                    radius: 4
                    visible: root.recActive
                    color: root.recPaused ? root.colWarn : root.colCrit
                    SequentialAnimation on opacity {
                        running: root.recActive && !root.recPaused
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 620; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0;  duration: 620; easing.type: Easing.InOutSine }
                    }
                    onVisibleChanged: if (!visible) opacity = 1
                }

                // Table points. Current - short white bar: table number
                // on the island no one read it as a number anyway, all that matters is
                // “which one out of how many”, and these are the dots
                // directly, without reading.
                //
                // Space for five tables is reserved for them, even when they are
                // less. Hyprland starts and clears tables on the go, and from
                // the number of points depended on the length of the entire island: the clock stands according to its
                // center, the right group is pressed to its edge - and on each
                // When the fourth table opened, the entire island was rearranged. Bye
                // there are no more than five tables, nothing changes now.
                Item {
                    Layout.preferredWidth: Math.max(wsRow.implicitWidth,
                                                    nothingCapsule.wsReserve)
                    Layout.preferredHeight: 6
                    Layout.alignment: Qt.AlignVCenter

                    RowLayout {
                        id: wsRow
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: nLeft.spacing

                Repeater {
                    model: root.wsList

                    Rectangle {
                        required property var modelData
                        readonly property bool here: modelData === root.wsId
                        // We keep the width with our property: Behavior is not hung
                        // to the attached Layout.*, and the spreading of the point into
                        // a strip without animation - just a substitution of the picture.
                        property real len: here ? 17 : 6

                        // The animation starts after the dot is placed on
                        // place. Otherwise, the appearance of a new table is lost
                        // like an exit lane - and this is not a change, it’s
                        // the first frame, and there is no reason to show it with movement.
                        property bool settled: false
                        Component.onCompleted: settled = true

                        Layout.preferredWidth: len
                        Layout.preferredHeight: 6
                        Layout.alignment: Qt.AlignVCenter
                        radius: 3
                        color: root.colFg
                        opacity: here ? 1 : (wsMa.containsMouse ? 0.6 : 0.3)

                        Behavior on len {
                            enabled: settled
                            NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
                        }
                        Behavior on opacity {
                            enabled: settled
                            NumberAnimation { duration: root.animFast }
                        }

                        MouseArea {
                            id: wsMa
                            anchors.fill: parent
                            // the six pixel point cannot be hit with the mouse,
                            // therefore the target is wider than the point itself
                            anchors.margins: -5
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.gotoWorkspace(modelData)
                        }
                    }
                }
                    }
                }

                // The weather is right behind the points. Icon and degrees, without city and
                // words: a person already knows the city, but the description in words is
                // The island does not fit - it is in the card on the wallpaper.
                RowLayout {
                    Layout.leftMargin: 6
                    spacing: 5
                    visible: root.weatherReady && root.cfg.weatherOnIsland

                    DotIcon {
                        Layout.alignment: Qt.AlignVCenter
                        code: root.weatherIcon
                        size: root.dotHClock
                        color: islWthMa2.containsMouse ? root.colOn : root.colFg
                    }
                    // Degrees in regular font. The points are left to the clock and
                    // tables - what should be typed on this topic
                    // them. The degree sign in a dot grid comes out square
                    // a circle of four dots, and it should be smooth.
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.weatherTemp + "°"
                        color: islWthMa2.containsMouse ? root.colOn : root.colFg
                        font { family: root.fontFam; pixelSize: root.fontSize }
                    }

                    MouseArea {
                        id: islWthMa2
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openWeatherDetails()
                    }
                }
            }

            // --------------------------------------------- center: clock
            DotText {
                id: nClock
                anchors.centerIn: parent
                value: root.timeText
                size: root.dotHClock
                // The boldness of a dot digit is the density of dots, not
                // line thickness: there is nothing to draw with except them. The clearance is narrowed to
                // tenth, the dots almost close together, and the number is readable
                // dense and bright white.
                //
                // So it catches up in saturation with the large clock in the panel, not
                // growing up after them: there the same figure is twice as high, and
                // It looks bright simply because of its size.
                gapRatio: 0.1
                color: root.colFg
            }

            // ------------------------------- right: network, sound, charge
            RowLayout {
                id: nRight
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                // The cable displaces the antenna: communication goes through it, and the icon
                // Wi-Fi over a working cable would only be confusing.
                //
                // The cable is drawn as a figure, not taken from the font: network tree
                // in Nerd Font it comes with a crossbar wider than the squares themselves, and on
                // in this size it is read as a stripe across the icon.
                // The size is set via Layout.*, not width/height: in
                // in the layout, the width of the element does not solve anything, it puts it
                // the layout itself is by preferred, and without it by implicit.
                // Hence the icon remained the same, no matter how much he
                // enter width.
                LanGlyph {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: root.iconSize - 6
                    Layout.preferredHeight: root.iconSize - 6
                    visible: root.wiredOn
                    color: root.colFg
                }
                Text {
                    Layout.alignment: Qt.AlignVCenter
                    visible: !root.wiredOn
                    text: root.wifiOn ? (root.wifiQuality > 66 ? "󰤨"
                                       : root.wifiQuality > 33 ? "󰤥" : "󰤟") : "󰤮"
                    color: root.wifiOn ? root.colFg : root.colMuted
                    font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                }

                // The layout is right behind the network. In letters, not dots: dotted
                // the grid knows the numbers, but “RU” would have to be drawn on it
                // separately for the sake of two signs.
                //
                // The current one is in full brightness, the second one is dimmed: with their color
                // There’s no getting around this topic, but the difference needs to be clear.
                //
                // FlipText, not a regular inscription: the layout is switched
                // blindly, in the middle of typing, and the confirmation needs to be noticed
                // out of the corner of my eye. Substitution of a letter without movement is imperceptible - here
                // it turns over, just like in a regular island.
                FlipText {
                    Layout.alignment: Qt.AlignVCenter
                    value: root.kbLayout
                    textColor: root.colFg
                    fontFam: root.fontFam
                    pixelSize: root.fontSize - 4
                    bold: true
                }

                // System load in Nothing capsule
                RowLayout {
                    visible: root.cfg.systemLoadOnIsland && (root.loadCpu >= 0 || root.loadMem >= 0)
                    spacing: 4
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: "󰍛 " + (root.loadCpu >= 0 ? root.loadCpu + "%" : "—")
                        color: root.loadCpu > 80 ? root.colCrit : root.colMuted
                        font { family: root.fontFam; pixelSize: root.fontSize - 4; bold: true }
                    }
                    Text {
                        visible: root.loadMem >= 0
                        text: "󰘚 " + root.loadMem + "%"
                        color: root.loadMem > 85 ? root.colCrit : root.colMuted
                        font { family: root.fontFam; pixelSize: root.fontSize - 4; bold: true }
                    }
                }

                RowLayout {
                    spacing: 6

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: !root.sinkAudio ? String.fromCodePoint(0xF075F)
                            : root.sinkAudio.muted ? String.fromCodePoint(0xF075F)
                            : root.sinkAudio.volume < 0.34 ? String.fromCodePoint(0xF057F)
                            : root.sinkAudio.volume < 0.67 ? String.fromCodePoint(0xF0580)
                                                           : String.fromCodePoint(0xF057E)
                        color: (root.sinkAudio && root.sinkAudio.muted)
                               ? root.colMuted : root.colFg
                        font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                    }

                    DotText {
                        Layout.alignment: Qt.AlignVCenter
                        value: root.sinkAudio
                               ? String(Math.round(root.sinkAudio.volume * 100)) : "0"
                        size: root.dotHSmall
                        color: (root.sinkAudio && root.sinkAudio.muted)
                               ? root.colMuted : root.colFg
                    }
                }

                // There is no charge on a desktop machine - there is this pair
                // no at all, not “zero percent.”
                RowLayout {
                    spacing: 6
                    visible: root.batteryPresent

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.batteryIcon
                        color: root.batteryPct <= 15 && !root.acOnline
                               ? root.colCrit : root.colFg
                        font { family: root.fontFam; pixelSize: root.iconSize - 2 }
                    }

                    DotText {
                        Layout.alignment: Qt.AlignVCenter
                        value: String(root.batteryPct)
                        size: root.dotHSmall
                        color: root.batteryPct <= 15 && !root.acOnline
                               ? root.colCrit : root.colFg
                    }
                }
            }
        }

            // Column text: each letter on its own line. Turned on
            // 90° text would have to be read with a tilted head, otherwise
            // the vertical island remains legible.
            component VertText: Column {
                id: vt
                property string value: ""
                property color textColor: root.colFg
                property real size: root.fontSize
                property bool bold: false
                property int maxChars: 16

                spacing: -2
                Repeater {
                    model: String(vt.value).slice(0, vt.maxChars).split("")
                    Text {
                        required property string modelData
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData === " " ? "·" : modelData
                        color: vt.textColor
                        font {
                            family: root.fontFam
                            pixelSize: vt.size
                            bold: vt.bold
                        }
                    }
                }
            }

            // ------------------------------------- vertical island
            // At the side edges, the contents stand in a column and are NOT rotated:
            // rotated text can only be read with a tilted head. Therefore
            // here is its own set - short values that fit into the thickness
            // islands: clock in two lines, table, layout, charge.
            ColumnLayout {
                id: vertCapsule
                anchors.centerIn: parent
                width: root.pillH
                spacing: 7
                visible: (!root.expanded || (root.cfg.pillKeepVisible && !root.settingsMode)) && !root.btToastActive && !root.wifiToastActive && !root.acToastActive && !root.recPickActive && !root.voxActive
                opacity: root.pillSide ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.animFast } }

                // Music plays: cover and equalizer. As thick as the name
                // the islands won’t fit, and the rotated text is unreadable -
                // therefore it is shown as a caption on hover.
                Item {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 22
                    Layout.preferredHeight: mediaCol.implicitHeight
                    visible: root.mediaActive

                ColumnLayout {
                    id: mediaCol
                    anchors.fill: parent
                    spacing: 5

                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 22
                        Layout.preferredHeight: 22
                        radius: 7
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Image {
                            id: vertArt
                            anchors.fill: parent
                            source: root.mediaArt
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 64
                            visible: false
                            layer.enabled: true
                        }
                        Item {
                            id: vertArtMask
                            anchors.fill: parent
                            visible: false
                            layer.enabled: true
                            Rectangle { anchors.fill: parent; radius: 7; color: "#ffffff" }
                        }
                        MultiEffect {
                            anchors.fill: parent
                            source: vertArt
                            maskEnabled: true
                            maskSource: vertArtMask
                            visible: vertArt.status === Image.Ready
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: vertArt.status !== Image.Ready
                            text: "󰝚"
                            color: root.colMuted
                            font { family: root.fontFam; pixelSize: 11 }
                        }
                    }

                    // track title in a column: short but readable
                    VertText {
                        Layout.alignment: Qt.AlignHCenter
                        value: root.player ? String(root.player.trackTitle || "") : ""
                        textColor: root.colFg
                        size: root.fontSize - 3
                        bold: true
                        maxChars: 10
                    }

                    // The same equalizer as in horizontal view, only
                    // rotated: the stripes are abstract, you don’t need to read them.
                    Item {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.preferredWidth: 16
                        Layout.preferredHeight: 28
                        WaveBars {
                            anchors.centerIn: parent
                            width: 28
                            height: 14
                            rotation: -90
                            barColor: root.colFg
                            active: root.player ? root.player.isPlaying : false
                        }
                    }

                }

                    // Clicking opens the player, hovering shows the title:
                    // the signature draws the root, so the text remains straight.
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            var t = root.player ? String(root.player.trackTitle || "") : "";
                            if (t.length === 0) return;
                            var p = mapToItem(null, width / 2, height / 2);
                            root.showTip(t, p.x, p.y);
                        }
                        onExited: root.hideTip(root.player
                                               ? String(root.player.trackTitle || "") : "")
                        onClicked: root.togglePage("media")
                    }
                }

                // Screen recording in progress
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 8
                    Layout.preferredHeight: 8
                    radius: 4
                    visible: root.recActive
                    color: root.recPaused ? root.colWarn : root.colCrit
                }

                // The line separates the music from the constant part - as in
                // in horizontal form it stands between cava and the day of the week.
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 14
                    Layout.preferredHeight: 1
                    visible: root.mediaActive
                    color: Qt.rgba(1, 1, 1, 0.18)
                }

                // day of the week in a column
                VertText {
                    Layout.alignment: Qt.AlignHCenter
                    value: root.dayText
                    textColor: root.colMuted
                    size: root.fontSize - 2
                    bold: true
                }

                // hours: hours and minutes in separate lines
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.timeText.split(":")[0] || ""
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: (root.timeText.split(":")[1] || "").replace(/[^0-9]/g, "")
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize; bold: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: String(root.wsId)
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 1; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.kbLayout
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 4; bold: true }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.cfg.systemLoadOnIsland && (root.loadCpu >= 0 || root.loadGpu >= 0)
                    text: (root.loadCpu >= 0 ? "C" + root.loadCpu + "%" + (root.loadTempCpu >= 0 ? "/" + root.loadTempCpu + "°" : "") : "")
                          + (root.loadGpu >= 0 ? " G" + root.loadGpu + "%" + (root.loadTempGpu >= 0 ? "/" + root.loadTempGpu + "°" : "") : "")
                    color: root.colFg
                    font { family: root.fontFam; pixelSize: root.fontSize - 5 }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.batteryPresent
                    text: root.batteryIcon
                    color: root.batteryCharging || root.acOnline ? root.colOk
                         : root.batteryPct <= 15 ? root.colCrit : root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 1 }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.batteryPresent
                    text: root.batteryPct
                    color: root.colMuted
                    font { family: root.fontFam; pixelSize: root.fontSize - 4 }
                }
            }

        // ------------------------------------------------------- transfer handle
        // Bar above the content: pull it, not the entire panel - otherwise
        // any movement on the tiles would drag the island. Visible only when
        // transfer is allowed and quick settings are open.
        Item {
            id: dragHandle
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16
            z: 60
            visible: root.cfg.pillDrag && root.expanded && root.page === "main"
                     && !root.settingsMode

            Rectangle {
                anchors.centerIn: parent
                width: 46
                height: 4
                radius: 2
                color: root.pillDragging ? root.colOn
                     : (handleMa.containsMouse ? Qt.rgba(1, 1, 1, 0.45)
                                               : Qt.rgba(1, 1, 1, 0.18))
                Behavior on color { ColorAnimation { duration: 140 } }
            }

            MouseArea {
                id: handleMa
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                cursorShape: root.pillDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                property real pressX: 0
                property real pressY: 0

                onPressed: mouse => {
                    var p = mapToItem(null, mouse.x, mouse.y);
                    handleMa.pressX = p.x;
                    handleMa.pressY = p.y;
                    root.pillDragging = true;
                }
                onPositionChanged: mouse => {
                    if (!root.pillDragging) return;
                    var p = mapToItem(null, mouse.x, mouse.y);
                    root.dragDX = p.x - handleMa.pressX;
                    root.dragDY = p.y - handleMa.pressY;
                    root.dragEdge = root.edgeAt(capsule.x + root.dragDX + capsule.width / 2,
                                                capsule.y + root.dragDY + capsule.height / 2);
                }
                onReleased: root.dropPill()
                onCanceled: root.dropPill()
            }
        }

        // --------------------------------------------------- open panel
        Loader {
            id: contentLoader
            z: 10
            parent: capsule
            anchors.top: parent ? parent.top : undefined
            anchors.topMargin: 15
            anchors.horizontalCenter: parent.horizontalCenter
            // The width is taken from the TARGET panel, not from the animated capsule:
            // otherwise the content would overflow across the width on every frame
            // folded and looked like smeared paint.
            width: (root.settingsMode ? root.settingsW : (root.page === "weather" ? Math.min(root.width - 40, 960) : root.panelW)) - 30
            // While the screen selection card (or toast) is shown, the content
            // do not draw the opened panel: when starting recording from quick settings
            // the panel collapses, and its contents are otherwise visible for a couple more frames
            // behind the card, the screens “flashed.”
            active: (root.expanded || capsule.height > root.pillH + 4)
                    && !root.recPickActive && !root.btToastActive
                    && !root.acToastActive && !root.voxActive
            visible: !root.recPickActive && !root.btToastActive && !root.acToastActive && !root.voxActive
            // without this, the keyboard did not reach the page content:
            // Loader itself did not have focus, and forceActiveFocus() inside the view
            // didn't lead to anything
            focus: true
            onLoaded: if (item) item.forceActiveFocus()
            // Esc closes any page: if the view itself has not processed it
            // (or processed only on a subpage), the event pops up here.
            // First we ask the species if there is somewhere for him to return: from the list
            // networks or devices Escape should lead to tiles, not
            // slam the entire panel.
            Keys.onEscapePressed: {
                var it = contentLoader.item;
                if (it && typeof it.goBack === "function" && it.goBack()) return;
                root.collapse();
            }
            opacity: root.expanded ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: root.expanded ? root.animFast : 90; easing.type: Easing.OutCubic }
            }

            sourceComponent: root.page === "launcher" ? launcherComp
                           : root.page === "features" ? featuresComp
                           : root.page === "docker"   ? dockerComp
                           : root.page === "calc"     ? calcComp
                           : root.page === "terminals" ? terminalsComp
                           : root.page === "tasks"     ? tasksComp
                           : root.page === "regex"     ? regexComp
                           : root.page === "picker"    ? pickerComp
                           : root.page === "cheat"     ? cheatComp
                           : root.page === "profile"   ? profileComp
                           : root.page === "settings" ? settingsComp
                           : root.page === "clip"     ? clipComp
                           : root.page === "power"    ? powerComp
                           : root.page === "notif"    ? notifComp
                           : root.page === "audio"    ? audioComp
                           : root.page === "cal"      ? calComp
                           : root.page === "record"   ? recordComp
                           : root.page === "files"    ? filesComp
                           : root.page === "media"    ? mediaComp
                           : root.page === "auth"     ? authComp
                           : root.page === "vault"    ? vaultComp
                           : root.page === "vaultsave" ? vaultSaveComp
                           : root.page === "agents"   ? agentsComp
                           : root.page === "weather"  ? weatherComp
                                                      : controlsComp
        }

        Component { id: controlsComp; ControlsView { sys: root } }
        Component { id: launcherComp; LauncherView { sys: root } }
        Component { id: featuresComp; FeaturesView { sys: root } }
        Component { id: dockerComp;   DockerView   { sys: root } }
        Component { id: calcComp;     CalcView     { sys: root } }
        Component { id: terminalsComp; TerminalsView { sys: root } }
        Component { id: tasksComp;     TaskManagerView { sys: root } }
        Component { id: regexComp;     RegexView { sys: root } }
        Component { id: pickerComp;    PickerView { sys: root } }
        Component { id: cheatComp;     CheatView { sys: root } }
        Component { id: profileComp;   ProfileView { sys: root } }
        Component { id: settingsComp; SettingsView { sys: root; tab: root.settingsTab } }
        Component { id: clipComp;     ClipboardView { sys: root } }
        Component { id: powerComp;    PowerView { sys: root } }
        Component { id: notifComp;    NotificationsView { sys: root } }
        Component { id: audioComp;    AudioView { sys: root } }
        Component { id: calComp;      CalendarView { sys: root } }
        Component { id: recordComp;   RecordView { sys: root } }
        Component { id: filesComp;    FilesView { sys: root } }
        Component { id: mediaComp;    MediaView { sys: root } }
        Component { id: authComp;     AuthView { sys: root } }
        Component { id: vaultComp;     VaultView { sys: root } }
        Component { id: vaultSaveComp; VaultSaveView { sys: root } }
        Component { id: agentsComp;    AgentsView { sys: root } }
        Component { id: weatherComp;   WeatherView { sys: root } }
    }

    // ------------------------------------------------------- general tooltip
    // The settings panel is cut off by a capsule (clip), and the signature extending beyond it
    // left edge, it just disappeared there. Therefore, the tooltip draws the root itself:
    // the view tells the text and the point from which to expand to the left.
    property string tipText: ""
    property real   tipX: 0
    property real   tipY: 0
    function showTip(text, x, y) { root.tipText = text; root.tipX = x; root.tipY = y; }
    function hideTip(text) { if (root.tipText === text) root.tipText = ""; }

    Rectangle {
        id: globalTip
        z: 200
        visible: opacity > 0.01
        opacity: root.tipText.length > 0 ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 130 } }

        width: globalTipText.implicitWidth + 20
        height: 26
        radius: 13
        x: Math.max(6, root.tipX - width - 10)
        y: root.tipY - height / 2
        color: Qt.rgba(0.04, 0.04, 0.05, 0.98)
        border.color: root.colLine
        border.width: 1

        scale: root.tipText.length > 0 ? 1 : 0.92
        transformOrigin: Item.Right
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

        Text {
            id: globalTipText
            anchors.centerIn: parent
            text: root.tipText
            color: root.colFg
            font { family: root.fontFam; pixelSize: 11 }
        }
    }

    // ------------------------------------ smooth connection to the edge of the screen
    // Two concave corners on the sides: transition from edge to pill without a step.
    // Concave abutment corners: cling to the same edge as the island and
    // stand on both sides of it. The shape is selected according to the edge: for vertical
    // islands are the same quarter circle, only unfolded - the fill should
    // press against the edge of the screen and the end of the capsule.
    NotchCorner {
        id: notchBefore
        // “before” the island: to the left of it, and at the side edges - above it
        side: root.pillSide ? (root.pillAtLeft ? "right" : "left") : "left"
        fill: root.colBg
        r: root.cornerR
        transform: Scale {
            origin.y: root.cornerR / 2
            yScale: root.pillSide ? -1 : (root.pillAtBottom ? -1 : 1)
        }
        // We round: the corner is a separate element with its own coordinates, and on
        // Half a pixel from the capsule, it diverges from it in a smoothed gray gap.
        x: root.pillAtLeft  ? 0
         : root.pillAtRight ? parent.width - width
                            : Math.round(capsule.x) - width
        y: root.pillSide ? capsule.y - height
         : root.pillAtBottom ? parent.height - height : 0
        // The corners go away with the island: in the settings it comes off
        // edges, and hides entirely on the wallpaper carousel.
        opacity: root.cornersOn ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.animFast } }
    }
    NotchCorner {
        id: notchAfter
        // “after” the island: to the right of it, and at the side edges - below it
        side: root.pillSide ? (root.pillAtLeft ? "right" : "left") : "right"
        fill: root.colBg
        r: root.cornerR
        transform: Scale {
            origin.y: root.cornerR / 2
            yScale: root.pillSide ? 1 : (root.pillAtBottom ? -1 : 1)
        }
        // Here the fractionality accumulates twice - from x capsule and from its width, -
        // therefore, it was the right corner that moved away more noticeably than the left.
        x: root.pillAtLeft  ? 0
         : root.pillAtRight ? parent.width - width
                            : Math.round(capsule.x + capsule.width)
        y: root.pillSide ? capsule.y + capsule.height
         : root.pillAtBottom ? parent.height - height : 0
        opacity: root.cornersOn ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: root.animFast } }
    }
}

// Overview of desktops - a separate full-screen layer: there is no pill here
// what, but the entire keyboard is needed.
LazyLoader {
    activeAsync: root.overviewOpen

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.overviewOpen ? WlrKeyboardFocus.Exclusive
                                                       : WlrKeyboardFocus.None
        visible: root.overviewOpen

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.55)
            opacity: root.overviewOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 160 } }
        }

        // An overview of tables is created immediately and lives with the shell.
        // Lazy loading didn’t work here: the layer pops up using Super+Tab, and
        // giving away its creation at the moment of pressing means risking yourself
        // clicking for a couple of megabytes. Heavy window previews are already only alive
        // while the layer is open.
        OverviewView {
            anchors.fill: parent
            sys: root
        }
    }
}

// Wallpaper is also its own full-screen layer: the carousel opens in the center
// screen, but she needs the entire keyboard (arrows, Enter, Esc).
LazyLoader {
    // We assemble the layer in advance - as soon as the list of wallpapers is read. Otherwise the first
    // the discovery took three hundred cards to create, and half a second the screen
    // was empty.
    activeAsync: root.wallsOpen || root.wallListReady

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.wallsOpen ? WlrKeyboardFocus.Exclusive
                                                    : WlrKeyboardFocus.None
        // the window lives all the time, but is shown only when opened
        visible: root.wallsOpen || wallsFade.opacity > 0.01

        Rectangle {
            id: wallsFade
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.62)
            opacity: root.wallsOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animMs } }
        }

        // Opens up from the island: the point of growth is the edge where it hangs,
        // so the carousel looks like an unfolded pill and not a separate one
        // a window coming from the side.
        // Wallpaper carousel. The layer above it is already lazy (LazyLoader above builds
        // it only when the list of wallpapers is read), and the pictures themselves are loaded
        // as the show progressed, the second level of laziness only broke the opening.
        WallpapersView {
            anchors.fill: parent
            sys: root
        }
    }
}

// Keys (Super + /) - their own full-screen layer, not a tiled window:
// unfolds from the island in the center of the screen and folds back in the same way.
LazyLoader {
    activeAsync: root.keysWindowOpen

    PanelWindow {
        anchors { top: true; bottom: true; left: true; right: true }
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.keysWindowOpen ? WlrKeyboardFocus.Exclusive
                                                         : WlrKeyboardFocus.None
        visible: root.keysWindowOpen || keysScrim.opacity > 0.01

        Rectangle {
            id: keysScrim
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.62)
            opacity: root.keysWindowOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: root.animMs } }
        }

        // clicking past the card closes it - like a review of tables and a wallpaper carousel
        MouseArea {
            anchors.fill: parent
            onClicked: root.keysWindowOpen = false
        }

        // The card starts exactly in the geometry of the capsule and grows to its
        // size in the center: it turns out to be an unfolded island, not a window,
        // coming from outside.
        Rectangle {
            id: keysCard
            readonly property real fullW: Math.min(1280, parent.width - 80)
            readonly property real fullH: Math.min(940, parent.height - 80)

            color: root.colBg
            clip: true
            x: root.keysWindowOpen ? (parent.width - fullW) / 2 : root.pillRectX
            y: root.keysWindowOpen ? (parent.height - fullH) / 2 : root.pillRectY
            width:  root.keysWindowOpen ? fullW : Math.max(8, root.pillRectW)
            height: root.keysWindowOpen ? fullH : Math.max(8, root.pillRectH)
            radius: root.keysWindowOpen ? 26 : Math.min(width, height) / 2

            Behavior on x      { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on y      { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on width  { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on height { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }
            Behavior on radius { NumberAnimation { duration: root.animMs; easing.type: Easing.OutQuint } }

            // There is no scrolling: the list is laid out in three columns and in its entirety
            // fits into a card, and it itself takes up almost the entire screen.
            // They look at the combination for a second, in the middle of other work -
            // searching for it with the wheel takes longer than remembering it yourself.
            SetKeys {
                id: keysBody
                anchors.fill: parent
                anchors.margins: 26
                sys: root
                // the content appears after the card: in the first frames
                // it's still the size of a pill, and the list doesn't fit into it
                opacity: root.keysWindowOpen ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.animMs } }
            }
        }
    }
}

// "What's new" screen after the update. A separate layer on top of everything: his
// show once and it should intercept the keyboard.
PanelWindow {
    visible: root.whatsNewOpen
    anchors { top: true; bottom: true; left: true; right: true }
    screen: root.screen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.whatsNewOpen ? WlrKeyboardFocus.Exclusive
                                                   : WlrKeyboardFocus.None

    Loader {
        anchors.fill: parent
        active: root.whatsNewOpen
        sourceComponent: WhatsNewView {
            sys: root
            lines: root.whatsNew
        }
    }
}


// Explorer in a separate window. Lives at the ShellRoot level, not inside
// pills: a window cannot be a child of another window.
Instantiator {
    model: filesWindows

    FloatingWindow {
        required property var model
        title: "Zenith · " + root.tr("Проводник")
        color: root.colBg
        minimumSize.width: 720
        minimumSize.height: 460
        visible: true
        // cross in the title - the window should also leave the list
        onVisibleChanged: if (!visible) root.closeFilesWindow(model.wid)

        FilesView {
            anchors.fill: parent
            anchors.margins: 15
            sys: root
            // folder from which the window opened (empty - home)
            dir: model.startDir
            // in windowed mode you need to close your window, not the pill
            windowMode: true
            windowId: model.wid
        }
    }
}

// Freeze frame for highlighting the area of ​​the screenshot.
//
// The usual “select an area and remove” selects on the live screen, and remove what
// what closes at the first movement of the mouse - a menu, a tooltip,
// the auto-completion list has nothing to do with it: while you are pulling the frame, there is nothing left to remove.
// Therefore, shot.sh first captures the entire screen, displays the image with this
// layer on top of everything, and only then starts the selection. Final frame
// is removed from the frozen layer, so there is no need to trim the source file -
// otherwise ImageMagick would also be needed.
//
// ---------------------------------------------------- desktop widgets
// Cards on the wallpaper: date, weather, clock. They have a common layout for topics, and
// your own style: on Nothing the numbers are in dots, on the rest in regular font.
// The card itself selects it - the layer only needs to know whether widgets are enabled.
//
// Bottom layer: above the wallpaper, but below the windows. On Overlay they would hang on top
// everything, including full-screen video, and this is a desktop decoration, not
// shell.
//
// The input area is empty. Cards do not catch anything with the mouse: intercept clicks
// on the desktop would mean taking them away from the windows and from the wallpaper itself, and pressing
// // Janela de previsão detalhada do tempo
PanelWindow {
    id: weatherDetailsWin
    visible: false
    anchors { top: true; bottom: true; left: true; right: true }
    screen: root.screen
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.weatherDetailsOpen ? WlrKeyboardFocus.Exclusive
                                                         : WlrKeyboardFocus.None

    // Escurecimento de fundo ao clicar fecha
    Rectangle {
        id: weatherScrim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.65)
        opacity: root.weatherDetailsOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        MouseArea {
            anchors.fill: parent
            onClicked: root.weatherDetailsOpen = false
        }
    }

    WeatherDetailsView {
        id: weatherDetailsView
        focus: root.weatherDetailsOpen
        Keys.onEscapePressed: root.weatherDetailsOpen = false
        width: implicitWidth
        height: implicitHeight
        anchors.horizontalCenter: parent.horizontalCenter
        y: (parent.height - height) / 2 + (root.weatherDetailsOpen ? 0 : 28)
        sys: root
        forecastData: root.weatherForecastData
        scale: root.weatherDetailsOpen ? 1.0 : 0.92
        opacity: root.weatherDetailsOpen ? 1.0 : 0.0
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack; easing.overshoot: 1.15 } }
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 200 } }
    }
}

PanelWindow {
    id: widgetsWin

    visible: root.cfg.featWidgets
    screen: root.screen
    anchors { top: true; left: true }
    implicitWidth:  widgets.implicitWidth + 56
    implicitHeight: widgets.implicitHeight + 56
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: widgets }

    WidgetsView {
        id: widgets
        sys: root
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 28
        // below the island: it stands in the center of the top edge and to the left
        // the corner is not enough, but the reserve is needed for its concave corner
        anchors.topMargin: 28
    }
}

// Layer on each screen, not just one on root.screen: grim removes the entire layout
// one picture, and each window shows its own piece of it, moving the picture to
// the beginning of your screen.
Variants {
    model: root.freezeShot !== "" ? Quickshell.screens : []

    PanelWindow {
        id: freezeWin
        required property var modelData

        screen: freezeWin.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "black"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        // The frame is just showing. The entire keyboard and mouse are taken out
        // selection: with a non-empty input area, clicks would go to this layer,
        // and there would be nothing to pull the frame with.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {}

        Image {
            // grim removes the layout in physical pixels, and the surfaces
            // screens - logical (at a scale of 200%, half as many). Draw
            // pixel-to-pixel frame is not possible: visible on a scaled screen
            // if there was only the upper left corner - the screen seemed to be “zoomed”, and remove
            // the whole screen didn't work. Therefore, we stretch the entire frame to
            // logical boundaries of the layout and move it to the beginning of your screen -
            // it turns out exactly 1:1 with what is on the screen, at any scale.
            x: root.freezeBounds.x - freezeWin.modelData.x
            y: root.freezeBounds.y - freezeWin.modelData.y
            width: root.freezeBounds.width
            height: root.freezeBounds.height
            source: root.freezeShot
            fillMode: Image.Stretch
            smooth: true
            // The file is temporary and new every time, but the name may be repeated -
            // the cache would give the previous snapshot.
            cache: false
        }
    }
}

}
