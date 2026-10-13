import QtQuick

// Live equalizer.
//
// The spectrum itself does not count: it takes the total flow from CavaSource and averages it
// to your barCount. Thanks to this, the capsule opens into the player immediately
// shows real sound - cava is already spinning for the sake of stripes in the capsule,
// to start again and there is nothing more to flash as a stub.
//
// If there is no cava in the system, use a soft synthetic wave so that the capsule does not
// looked dead. Once the cava is installed, it will pick itself up.
Item {
    id: wave

    property color barColor: "#ffffff"
    property bool  active: true
    property int   barCount: 7
    property real  gap: 2

    // levels 0..1 for each band
    property var levels: []

    // ------------------------------------------------------------- real
    // As long as the bands are visible and sound, we keep the overall cava alive.
    onActiveChanged: active ? CavaSource.acquire() : CavaSource.release()
    Component.onDestruction: if (active) CavaSource.release()

    // Averaging the total spectrum to barCount bands.
    function resample(src) {
        var n = src.length;
        if (n === 0) return;
        var a = [];
        for (var i = 0; i < wave.barCount; i++) {
            var from = Math.floor(i * n / wave.barCount);
            var to   = Math.max(from + 1, Math.floor((i + 1) * n / wave.barCount));
            var sum = 0;
            for (var j = from; j < to; j++) sum += src[j];
            a.push(sum / (to - from));
        }
        wave.levels = a;
    }

    Connections {
        target: CavaSource
        enabled: wave.active && CavaSource.hasCava
        function onLevelsChanged() { wave.resample(CavaSource.levels); }
    }

    Component.onCompleted: {
        var a = [];
        for (var i = 0; i < barCount; i++) a.push(0.2);
        levels = a;
        if (active) CavaSource.acquire();
        // The first frame is immediate, without waiting for the next packet from cava:
        // otherwise, upon opening, the starting level of 0.2 would have blinked.
        if (CavaSource.hasCava) resample(CavaSource.levels);
    }

    // -------------------------------------------------------------- spare
    Timer {
        // 30 fps: at 90 ms the waveform is noticeably stepped
        interval: 33
        running: wave.active && !CavaSource.hasCava
        repeat: true
        onTriggered: {
            var a = [];
            var t = Date.now() / 260;
            for (var i = 0; i < wave.barCount; i++) {
                // two asynchronous sine waves -> the wave looks lively, not strict
                var v = 0.45 + 0.34 * Math.sin(t + i * 0.85)
                             + 0.18 * Math.sin(t * 1.7 + i * 1.9);
                a.push(Math.max(0.08, Math.min(1, v)));
            }
            wave.levels = a;
        }
    }

    // fade when pause
    Timer {
        interval: 33
        running: !wave.active
        repeat: true
        onTriggered: {
            var a = [];
            var changed = false;
            for (var i = 0; i < wave.levels.length; i++) {
                var v = Math.max(0.08, wave.levels[i] * 0.92);
                if (Math.abs(v - wave.levels[i]) > 0.001) changed = true;
                a.push(v);
            }
            if (changed) wave.levels = a;
        }
    }

    Row {
        anchors.fill: parent
        spacing: wave.gap

        Repeater {
            model: wave.barCount
            Rectangle {
                required property int index
                width: (wave.width - wave.gap * (wave.barCount - 1)) / wave.barCount
                radius: width / 2
                color: wave.barColor
                opacity: 0.55 + 0.45 * height / Math.max(1, wave.height)
                // Power curve (0.6) raises average values: quiet
                // the places are still visible, but on the music the bands confidently strike almost
                // at full height, and not huddled to the bottom.
                height: Math.max(2,
                    Math.pow(Math.min(1, wave.levels[index] || 0.06), 0.6) * wave.height)
                anchors.verticalCenter: parent.verticalCenter

                // Frames arrive every ~33 ms, and the curve is longer - movement
                // turns out continuous, without jerks between values.
                Behavior on height {
                    NumberAnimation { duration: 90; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}
