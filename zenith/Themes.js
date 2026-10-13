.pragma library

// There is only one topic table for the entire system.
//
// It is in a separate file because it has two readers and they are in different
// processes: the shell itself and the lock screen. It runs separately
// does not reach the settings of the pill and reads settings.json itself - but without
// of the general table he would have had to keep his own copy of the flowers, and it would have sold out
// with the shell on the first edit.
//
// Themes do not depend on the wallpaper: the color is set by the selected theme, not the picture on it.
// table. The “default” theme is what it was originally: the background is black, and the text and
// the accent is taken from the settings, so manually selected colors will not go anywhere
// disappear.

// There are two topics, and this is not a trimmed list, but the whole list.
//
// Previously there were eight of them: pink, tea, amber, ice, lilac,
// gray They differed in one thing - the shade of accent - and the choice between them
// came down to the choice of color, which is already adjusted with the sliders below on that
// same page. The shell has two real appearances: normal, where it has its own color
// each, and Nothing, where there is no color at all.
//
// The settings left over from the removed themes do not break anyone: of() on
// the unfamiliar name gives away the first theme.
var list = [
    { id: "default",  name: "Default",     bg: "#000000", fg: "#ffffff", on: "#3b82f6", ok: "#22c55e", crit: "#ef4444" },
    // Nothing is not just a palette, but a different appearance of the shell: dotted numbers,
    // table points instead of numbers, load summary, cards on wallpaper. For
    // themeNothing is responsible for the appearance, and this line is for the colors.
    //
    // The accent here is white on purpose. Nothing has no color accent at all:
    // distinguished by brightness, not hue, and the only color is red -
    // reserved for recording and low battery. Put blue here
    // would mean ruining the whole idea.
    { id: "nothing",  name: "Nothing",     bg: "#000000", fg: "#ffffff", on: "#ffffff", ok: "#ffffff", crit: "#d71921" }
];

// Unknown name - first topic: settings could come from a version where
// there was such a topic, and there is no need to fall because of it.
function of(id) {
    for (var i = 0; i < list.length; i++)
        if (list[i].id === id) return list[i];
    return list[0];
}
