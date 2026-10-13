import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

// System. To the left of the machine characteristics there is a live poll: memory, load,

// temperature and number of processes. We poll once every two seconds with one command

// — separate processes for each row would cost more than the data itself.

ColumnLayout {
    id: page

    property var sys

    property string osName: ""
    property string kernel: ""
    property string wm: ""
    property string cpuName: ""
    property string gpuName: ""
    property string host: ""
    property string uptime: ""
    property string currentUser: ""
    property string userFull: ""

    // live indicators

    property real memUsed: 0      // GiB

    property real memTotal: 0
    property real swapUsed: 0
    property real swapTotal: 0
    property real load1: 0
    property int  procs: 0
    property real tempCpu: -1
    property real tempGpu: -1
    property real diskUsed: 0
    property real diskTotal: 0
    property real selfMb: 0       // how much does the shell itself take, MiB


    function stepName(st) {
        return st === "download"      ? page.sys.tr("скачивание")
             : st === "selfupdate"    ? page.sys.tr("обновление обновлятора")
             : st === "backup"        ? page.sys.tr("сохранение настроек")
             : st === "install"       ? page.sys.tr("установка")
             : st === "greeter"       ? page.sys.tr("экран входа")
             : st === "restore"       ? page.sys.tr("возврат настроек")
             : st === "voxtype_model" ? page.sys.tr("скачивание голосовой модели")
             : st === "restart"       ? page.sys.tr("перезапуск")
             : page.sys.tr("подготовка");
    }

    // reset button is cocked and waiting for confirmation

    property bool armed: false
    Timer { id: disarm; interval: 4000; onTriggered: page.armed = false }

    Layout.fillWidth: true
    spacing: 12

    Component.onCompleted: { pInfo.running = true; pLive.running = true; }

    Process {
        id: pInfo
        command: ["sh", "-c",
            "wm_ver=\"\"; " +
            "if [ -n \"$NIRI_SOCKET\" ] || [ \"${XDG_CURRENT_DESKTOP,,}\" = \"niri\" ]; then " +
            "  wm_ver=\"niri $(niri --version 2>/dev/null | awk '{print $2}')\"; " +
            "else " +
            "  wm_ver=\"${XDG_CURRENT_DESKTOP:-Hyprland} $(hyprctl version -j 2>/dev/null | sed -n 's/.*\\\"tag\\\": *\\\"\\([^\\\"]*\\)\\\".*/\\1/p')\"; " +
            "fi; " +
            "printf '%s\\n' \"$(. /etc/os-release 2>/dev/null; echo $PRETTY_NAME)\" " +
            "\"$(uname -r)\" \"$wm_ver\" " +
            "\"$(sed -n 's/^model name[ \\t]*: //p' /proc/cpuinfo | head -1)\" " +
            "\"$(lspci 2>/dev/null | sed -n 's/.*VGA compatible controller: //p' | head -1)\" " +
            "\"$(cat /etc/hostname 2>/dev/null || hostname)\" \"$(whoami)\" \"$(getent passwd $(whoami) 2>/dev/null | cut -d: -f5 | cut -d, -f1)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                var a = text.split("\n");
                page.osName  = (a[0] || "").trim();
                page.kernel  = (a[1] || "").trim();
                page.wm      = (a[2] || "").trim();
                page.cpuName = (a[3] || "").trim();
                page.gpuName = (a[4] || "").trim();
                page.host    = (a[5] || "").trim();
                page.currentUser = (a[6] || "").trim();
                page.userFull    = (a[7] || "").trim();
            }
        }
    }

    // We take the temperature from hwmon by chip name, and not from thermal_zone:

    // on this machine the only zone is acpitz and it shows six

    // degrees. From hwmon it is clear whose sensor it is, and it can be signed.

    Process {
        id: pLive
        command: ["sh", "-c",
            // memory | swap | loading | processes | CPU | video | disk | uptime | the shell itself

            "free -k | awk '/^Mem:/{printf \"%s %s|\", $3, $2} /^Swap:/{printf \"%s %s|\", $3, $2}'; " +
            "awk '{printf \"%s|\", $1}' /proc/loadavg; " +
            "ls -d /proc/[0-9]* | wc -l | tr -d '\\n'; printf '|'; " +
            "for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); " +
            "case $n in k10temp|coretemp|zenpower|cpu_thermal|acpitz_cpu) " +
            "cat $h/temp1_input 2>/dev/null | tr -d '\\n'; break;; esac; done; printf '|'; " +
            // Video: first hwmon, like the processor. Proprietary driver

            // Nvidia doesn’t always place the sensor there, so if it’s empty -

            // we ask nvidia-smi. It gives degrees as an integer, and hwmon

            // - thousandths, so we multiply.

            "gpu=''; for h in /sys/class/hwmon/hwmon*; do n=$(cat $h/name 2>/dev/null); " +
            "case $n in amdgpu|nouveau|radeon|i915|nvidia) " +
            "gpu=$(cat $h/temp1_input 2>/dev/null); break;; esac; done; " +
            "if [ -z \"$gpu\" ] && command -v nvidia-smi >/dev/null 2>&1; then " +
            "c=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1); " +
            "[ -n \"$c\" ] && gpu=$((c * 1000)); fi; " +
            "printf '%s|' \"$gpu\"; " +
            "df -k --output=used,size / | tail -1 | tr -s ' ' | sed 's/^ //' | tr -d '\\n'; printf '|'; " +
            "uptime -p | tr -d '\\n'; printf '|'; " +
            // the shell itself: sh is run from it, so its PID is PPID

            "awk '/VmRSS/{printf \"%s\", $2}' /proc/$PPID/status; printf '@'"]
        stdout: StdioCollector {
            onStreamFinished: {
                // The collector accumulates the output of all runs in a row, so we take

                // last completed entry, not the beginning of the text: without

                // This testimony forever remained a snapshot of the first survey.

                var recs = text.split("@").filter(r => r.indexOf("|") > 0);
                if (!recs.length) return;
                var a = recs[recs.length - 1].trim().split("|");
                var mem = (a[0] || "").trim().split(/\s+/);
                var swp = (a[1] || "").trim().split(/\s+/);
                var dsk = (a[6] || "").trim().split(/\s+/);
                page.memUsed  = (+mem[0] || 0) / 1048576;
                page.memTotal = (+mem[1] || 0) / 1048576;
                page.swapUsed  = (+swp[0] || 0) / 1048576;
                page.swapTotal = (+swp[1] || 0) / 1048576;
                page.load1  = +a[2] || 0;
                page.procs  = +a[3] || 0;
                // sensors give thousandths of a degree

                page.tempCpu = (+a[4] > 0) ? (+a[4] / 1000) : -1;
                page.tempGpu = (+a[5] > 0) ? (+a[5] / 1000) : -1;
                page.diskUsed  = (+dsk[0] || 0) / 1048576;
                page.diskTotal = (+dsk[1] || 0) / 1048576;
                page.uptime = (a[7] || "").trim();
                page.selfMb = (+a[8] || 0) / 1024;
            }
        }
    }

    // We restart the survey via reset: assigning running = true when

    // the process has not yet been marked as completed, does nothing - indications

    // froze in the first photo.

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: { pLive.running = false; pLive.running = true; }
    }

    Process { id: pOpen; property string url: ""; command: ["xdg-open", pOpen.url] }

    // ------------------------------------------------------------- System User


    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 54
        radius: 14
        color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.05)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 17
                color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.20)
                border.color: page.sys.colOn
                border.width: 1.5

                Text {
                    anchors.centerIn: parent
                    text: "󰌽"
                    color: page.sys.colOn
                    font { family: page.sys.fontFam; pixelSize: 18 }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft
                spacing: 1

                RowLayout {
                    spacing: 8
                    Text {
                        text: page.currentUser || Quickshell.env("USER") || "user"
                        color: page.sys.colFg
                        font { family: page.sys.fontDisplay; pixelSize: page.sys.fontSize + 1; bold: true }
                    }
                    Rectangle {
                        implicitWidth: sessBadge.implicitWidth + 8
                        implicitHeight: 16
                        radius: 8
                        color: Qt.rgba(page.sys.colOn.r, page.sys.colOn.g, page.sys.colOn.b, 0.18)
                        Text {
                            id: sessBadge
                            anchors.centerIn: parent
                            text: (page.sys && page.sys.isPt) ? "Usuário Ativo" : "Active User"
                            color: page.sys.colOn
                            font { family: page.sys.fontFam; pixelSize: 9; bold: true }
                        }
                    }
                }

                Text {
                    text: (page.currentUser || Quickshell.env("USER") || "user") + "@" + (page.host || "nixos") + (page.userFull && page.userFull !== page.currentUser ? (" (" + page.userFull + ")") : "")
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
                }
            }

            Item { Layout.fillWidth: true }

            Glyph {
                glyph: String.fromCodePoint(0xF0004)   // account-check
                color: page.sys.colOn
                fontFam: page.sys.fontFam
                size: 18
            }
        }
    }


    // ------------------------------------------------------------- load

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Сейчас") }

        component Meter: ColumnLayout {
            property string label: ""
            property string value: ""
            property real frac: 0
            property color tint: page.sys.colOn

            Layout.fillWidth: true
            spacing: 6

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: label
                    color: page.sys.colFg
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
                Text {
                    text: value
                    color: page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 2 }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.10)
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, frac))
                    height: parent.height
                    radius: parent.radius
                    color: tint
                    Behavior on width { NumberAnimation { duration: page.sys.animFade } }
                }
            }
        }

        // The readings are system-wide, not shell-based: they include the browser,

        // messengers and everything else. How long does Zenith itself take?

        // a separate line below, otherwise six gigabytes are read as her fault.

        Meter {
            label: page.sys.tr("Оперативная память системы")
            value: page.memUsed.toFixed(1) + " / " + page.memTotal.toFixed(1) + " GiB"
            frac: page.memTotal > 0 ? page.memUsed / page.memTotal : 0
        }

        Meter {
            visible: page.swapTotal > 0
            label: page.sys.tr("Подкачка")
            value: page.swapUsed.toFixed(1) + " / " + page.swapTotal.toFixed(1) + " GiB"
            frac: page.swapTotal > 0 ? page.swapUsed / page.swapTotal : 0
        }

        Meter {
            label: page.sys.tr("Диск /")
            value: page.diskUsed.toFixed(0) + " / " + page.diskTotal.toFixed(0) + " GiB"
            frac: page.diskTotal > 0 ? page.diskUsed / page.diskTotal : 0
        }

        Meter {
            visible: page.tempCpu >= 0
            label: page.sys.tr("Температура процессора")
            value: page.tempCpu.toFixed(0) + " °C"
            // scale up to 100 °C: above 80 the bar becomes alarming

            frac: page.tempCpu / 100
            tint: page.tempCpu >= 80 ? page.sys.colCrit : page.sys.colOn
        }

        Meter {
            visible: page.tempGpu >= 0
            label: page.sys.tr("Температура видео")
            value: page.tempGpu.toFixed(0) + " °C"
            frac: page.tempGpu / 100
            tint: page.tempGpu >= 85 ? page.sys.colCrit : page.sys.colOn
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 18

            Text {
                text: page.sys.tr("Нагрузка") + ": " + page.load1.toFixed(2)
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                text: "Zenith: " + page.selfMb.toFixed(0) + " MiB"
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                text: page.sys.tr("Процессов") + ": " + page.procs
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Item { Layout.fillWidth: true }
        }
    }

    // ------------------------------------------------------------- car

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Машина") }

        component Fact: RowLayout {
            property string k: ""
            property string v: ""

            Layout.fillWidth: true
            visible: v.length > 0
            spacing: 12

            Text {
                text: k
                color: page.sys.colMuted
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: v
                color: page.sys.colFg
                elide: Text.ElideRight
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
            }
        }

        Fact { k: (page.sys && page.sys.isPt) ? "Usuário" : "User"; v: page.currentUser || Quickshell.env("USER") || "user" }
        Fact { k: page.sys.tr("Система");    v: page.osName }
        Fact { k: page.sys.tr("Ядро");       v: page.kernel }
        Fact { k: page.sys.tr("Композитор"); v: page.wm }
        Fact { k: page.sys.tr("Процессор");  v: page.cpuName }
        Fact { k: page.sys.tr("Видео");      v: page.gpuName }
        Fact { k: page.sys.tr("Имя машины"); v: page.host }
        Fact { k: page.sys.tr("Аптайм");     v: page.uptime }
        Fact { k: page.sys.tr("Оболочка");   v: "Zenith " + page.sys.version }
    }

    // ------------------------------------------------------------- reset

    SetCard {
        sys: page.sys

        SetLabel { sys: page.sys; text: page.sys.tr("Сброс") }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
                Layout.fillWidth: true
                text: page.armed
                      ? page.sys.tr("Нажмите ещё раз — все настройки вернутся к заводским.")
                      : page.sys.tr("Вернуть все настройки к заводским. Сочетания клавиш останутся как есть.")
                color: page.armed ? page.sys.colCrit : page.sys.colMuted
                wrapMode: Text.WordWrap
                font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 4 }
            }

            Rectangle {
                // Width according to the inscription, but not narrower than before: “Exactly reset” and

                // “Reset all” are of different lengths, and in English both are longer -

                // The 140 selected by eye could no longer accommodate them.

                Layout.preferredWidth: Math.max(140, resetLabel.implicitWidth + 24)
                Layout.preferredHeight: 32
                radius: 10
                color: page.armed
                       ? Qt.rgba(page.sys.colCrit.r, page.sys.colCrit.g, page.sys.colCrit.b,
                                 resetMa.containsMouse ? 0.40 : 0.26)
                       : (resetMa.containsMouse
                          ? Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.14)
                          : Qt.rgba(page.sys.colFg.r, page.sys.colFg.g, page.sys.colFg.b, 0.06))
                border.width: page.armed ? 1 : 0
                border.color: page.sys.colCrit
                Behavior on color { ColorAnimation { duration: page.sys.animFade } }

                Text {
                    id: resetLabel
                    anchors.centerIn: parent
                    text: page.armed ? page.sys.tr("Точно сбросить") : page.sys.tr("Сбросить всё")
                    color: page.armed ? page.sys.colFg : page.sys.colMuted
                    font { family: page.sys.fontBody; pixelSize: page.sys.fontSize - 3 }
                }

                MouseArea {
                    id: resetMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // Two-click reset: one accidental mouse movement does not

                    // should erase all configured shell.

                    onClicked: {
                        if (page.armed) { page.sys.resetCfg(); page.armed = false; }
                        else { page.armed = true; disarm.restart(); }
                    }
                }
            }
        }
    }

}
