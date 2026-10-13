pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// One common spectrum flow for the entire shell.
//
// Previously, each WaveBars raised their cava. While the process has started
// (several hundred milliseconds), the stripes rotated the synthetic plug -
// therefore, when the capsule was opened, the “looped” one first flashed into the player
// wave and only then did the real spectrum appear.
//
// Now cava is alone, lives while someone is watching, and gives away the spectrum to
// high resolution: any WaveBars averages it to its barCount and
// From the very first frame it shows real sound.
Singleton {
    id: src

    // Total spectrum resolution: divisible by both 7 (capsule) and 22 (player)
    // smooth enough so that averaging does not “eat up” individual bands.
    readonly property int resolution: 32

    // levels 0..1, length == resolution
    property var levels: []

    // true, as soon as the first real frame from cava arrived
    property bool hasCava: false

    // ------------------------------------------------------- viewer registration
    property int consumers: 0

    function acquire() { consumers += 1; }
    function release() { if (consumers > 0) consumers -= 1; }

    // We don’t extinguish cava right away: on pause or when jumping between screens
    // the process must survive the break, otherwise the same start lag returns.
    Timer {
        id: linger
        interval: 20000
        running: src.consumers === 0 && cava.running
        onTriggered: cava.running = false
    }

    onConsumersChanged: if (consumers > 0) cava.running = true

    Component.onCompleted: {
        var a = [];
        for (var i = 0; i < resolution; i++) a.push(0);
        levels = a;
    }

    Process {
        id: cava
        // -1 = infinite output; ascii mode gives numbers 0..100 through ';'
        command: ["sh", "-c",
            "command -v cava >/dev/null || exit 1; " +
            "cfg=$(mktemp); " +
            // channels=mono is required: in stereo cava requires an even number
            // bands and with our seven fell silently - hence the “dead” equalizer.
            // Higher sensitivity and monstercat + less antialiasing - stripes
            // They respond more sharply and jump to the music more noticeably.
            "printf '[general]\\nbars=%d\\nframerate=60\\nsensitivity=140\\n" +
            "[output]\\nchannels=mono\\nmethod=raw\\nraw_target=/dev/stdout\\ndata_format=ascii\\nascii_max_range=100\\n" +
            "[smoothing]\\nnoise_reduction=0.45\\nmonstercat=2.2\\n' " +
            src.resolution + " > \"$cfg\"; " +
            "exec cava -p \"$cfg\""]
        running: false
        stdout: SplitParser {
            onRead: line => {
                var parts = line.trim().split(";");
                var a = [];
                for (var i = 0; i < src.resolution; i++) {
                    var v = parseInt(parts[i]);
                    // slight acceleration: quiet places also give noticeable movement
                    a.push(isNaN(v) ? 0 : Math.min(1, (v / 100) * 1.25));
                }
                src.levels = a;
                src.hasCava = true;
            }
        }
    }
}
