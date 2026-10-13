import QtQuick

// Takes away keyboard focus for a field that just appeared.
//
// The layer does not receive the keyboard in the first frame: until the composer gives it away,
// forceActiveFocus() silently does nothing, and the first clicks fly away
// nowhere - the panel opened faster than focus came to it. Therefore
// repeat each frame until focus is achieved.
//
// It is placed next to the field and runs itself:
//
//     FocusGrabber { target: input }
//
// The goal can also be calculated - a regular binding, it will be recalculated:
//
//     FocusGrabber { target: view.sys.vaultUnlocked ? search : pw }
Timer {
    id: grab

    property Item target: null
    // half a second at 60 Hz. There is nothing to wait further: if there is still no focus,
    // someone else is holding it, and it would be wrong to take it away by force
    property int maxTries: 30

    property int tries: 0

    interval: 16
    repeat: true
    triggeredOnStart: true
    running: true

    onTriggered: {
        var t = grab.target;
        if (!t || t.activeFocus || grab.tries++ > grab.maxTries) {
            grab.stop();
            return;
        }
        // Focus is not given to an invisible target - we wait until it appears, but the counter
        // it’s still going: this timer shouldn’t hang here forever.
        if (t.visible) t.forceActiveFocus();
    }
}
