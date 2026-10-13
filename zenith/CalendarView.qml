import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Calendário completo com navegação por mês, marcação de eventos (pontos),
// visualização de eventos diários, adição de eventos (+ Adicionar Evento),
// exclusão, sincronização do Google Agenda (iCal) e restauração de backup.
Item {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    focus: true
    Component.onCompleted: {
        forceActiveFocus();
        pLoadEvents.running = true;
        pLoadLinks.running = true;
    }
    Keys.onEscapePressed: {
        if (view.showSettingsModal) view.showSettingsModal = false;
        else if (view.showAddModal) view.showAddModal = false;
        else view.sys.page = "main";
    }
    Keys.onLeftPressed:  view.shift(-1)
    Keys.onRightPressed: view.shift(1)

    readonly property date today: new Date()
    property int viewYear:  today.getFullYear()
    property int viewMonth: today.getMonth()          // 0..11

    function pad2(n) { return (n < 10 ? "0" : "") + n; }
    function toDateStr(d) {
        return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate());
    }

    property string selectedDateStr: toDateStr(today)
    property var allEvents: []
    property bool isSyncing: false
    property bool showAddModal: false
    property bool showSettingsModal: false
    property var calendarLinks: []
    property string statusMsg: ""

    function shift(delta) {
        var m = viewMonth + delta;
        var y = viewYear;
        while (m < 0)  { m += 12; y--; }
        while (m > 11) { m -= 12; y++; }
        viewMonth = m; viewYear = y;
    }
    function toToday() {
        viewYear = today.getFullYear();
        viewMonth = today.getMonth();
        selectedDateStr = toDateStr(today);
    }

    readonly property var monthsPt: ["Janeiro","Fevereiro","Março","Abril","Maio","Junho",
                                     "Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"]
    readonly property var monthsEn: ["January","February","March","April","May","June",
                                     "July","August","September","October","November","December"]
    readonly property var monthsRu: ["Janeiro","Fevereiro","Março","Abril","Maio","Junho",
                                     "Julho","Agosto","Setembro","Outubro","Novembro","Dezembro"]

    readonly property var dowPt: ["Seg","Ter","Qua","Qui","Sex","Sáb","Dom"]
    readonly property var dowEn: ["Mo","Tu","We","Th","Fr","Sa","Su"]
    readonly property var dowRu: ["Seg","Ter","Qua","Qui","Sex","Sáb","Dom"]

    // Dicionário de eventos indexados por YYYY-MM-DD
    readonly property var eventsMap: {
        var map = {};
        for (var i = 0; i < allEvents.length; i++) {
            var ev = allEvents[i];
            var dt = String(ev.date || "").trim();
            if (!dt) continue;
            if (!map[dt]) map[dt] = [];
            map[dt].push(ev);
        }
        return map;
    }

    readonly property var eventsForSelectedDate: {
        return eventsMap[selectedDateStr] || [];
    }

    // 42 células da grade de 6 semanas
    readonly property var cells: {
        var first = new Date(viewYear, viewMonth, 1);
        var lead = (first.getDay() + 6) % 7;
        var start = new Date(viewYear, viewMonth, 1 - lead);
        var out = [];
        for (var i = 0; i < 42; i++) {
            var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i);
            var dStr = toDateStr(d);
            var evs = view.eventsMap[dStr] || [];
            out.push({
                day: d.getDate(),
                dateStr: dStr,
                inMonth: d.getMonth() === viewMonth,
                isToday: d.getFullYear() === today.getFullYear()
                         && d.getMonth() === today.getMonth()
                         && d.getDate() === today.getDate(),
                isSelected: dStr === view.selectedDateStr,
                weekend: i % 7 >= 5,
                eventCount: evs.length,
                hasEvents: evs.length > 0
            });
        }
        return out;
    }

    // Processos do Backend (calendar_sync.py)
    Process {
        id: pLoadEvents
        command: ["python3", Quickshell.env("HOME") + "/.config/zenith/scripts/calendar_sync.py", "list"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data.trim());
                    if (parsed && Array.isArray(parsed.events)) {
                        view.allEvents = parsed.events;
                    } else if (Array.isArray(parsed)) {
                        view.allEvents = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: pSync
        command: ["python3", Quickshell.env("HOME") + "/.config/zenith/scripts/calendar_sync.py", "sync"]
        onExited: {
            view.isSyncing = false;
            pLoadEvents.running = true;
            view.statusMsg = (view.sys && view.sys.isPt) ? "Sincronizado com sucesso!" : "Synchronized!";
            msgTimer.restart();
        }
    }

    Process {
        id: pImportBackup
        command: ["python3", Quickshell.env("HOME") + "/.config/zenith/scripts/calendar_sync.py", "import"]
        onExited: {
            pLoadEvents.running = true;
            view.statusMsg = (view.sys && view.sys.isPt) ? "Backup restaurado com sucesso!" : "Backup restored!";
            msgTimer.restart();
        }
    }

    Process {
        id: pAddEventAction
        onExited: {
            pLoadEvents.running = true;
            view.showAddModal = false;
        }
    }

    Process {
        id: pDeleteEventAction
        onExited: pLoadEvents.running = true
    }

    Timer {
        id: msgTimer
        interval: 3500
        onTriggered: view.statusMsg = ""
    }

    function syncCalendar() {
        view.isSyncing = true;
        pSync.running = true;
    }

    function addEvent(title, date, time, desc, allDay) {
        var args = [
            "python3", Quickshell.env("HOME") + "/.config/zenith/scripts/calendar_sync.py", "add",
            "--title", title,
            "--date", date,
            "--time", time || "00:00",
            "--desc", desc || ""
        ];
        if (allDay) args.push("--all-day");
        pAddEventAction.command = args;
        pAddEventAction.running = true;
    }

    function deleteEvent(id) {
        pDeleteEventAction.command = [
            "python3", Quickshell.env("HOME") + "/.config/zenith/scripts/calendar_sync.py", "delete",
            "--id", id
        ];
        pDeleteEventAction.running = true;
    }

    Process {
        id: pLoadLinks
        command: ["python3", Quickshell.env("HOME") + "/.config/zenith/scripts/calendar_sync.py", "links_list"]
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data.trim());
                    if (Array.isArray(parsed)) view.calendarLinks = parsed;
                } catch (e) {}
            }
        }
    }

    Process {
        id: pAddLink
        onExited: {
            pLoadLinks.running = true;
            pSync.running = true;
            view.statusMsg = (view.sys && view.sys.isPt) ? "Calendário vinculado e sincronizado!" : "Calendar linked!";
            msgTimer.restart();
        }
    }

    Process {
        id: pDeleteLink
        onExited: {
            pLoadLinks.running = true;
            view.statusMsg = (view.sys && view.sys.isPt) ? "Vínculo removido!" : "Link removed!";
            msgTimer.restart();
        }
    }

    function loadLinks() {
        pLoadLinks.running = false;
        pLoadLinks.running = true;
    }

    function addLink(name, url) {
        if (!url || !url.trim().length) return;
        pAddLink.command = [
            "python3", Quickshell.env("HOME") + "/.config/zenith/scripts/calendar_sync.py", "links_add",
            "--name", name || "Google Agenda",
            "--url", url.trim()
        ];
        pAddLink.running = false;
        pAddLink.running = true;
    }

    function deleteLink(id) {
        pDeleteLink.command = [
            "python3", Quickshell.env("HOME") + "/.config/zenith/scripts/calendar_sync.py", "links_delete",
            "--id", id
        ];
        pDeleteLink.running = false;
        pDeleteLink.running = true;
    }

    component NavBtn: Rectangle {
        property string sym: ""
        signal pressedAction()

        Layout.preferredWidth: 32
        Layout.preferredHeight: 32
        radius: 10
        color: navMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
        Behavior on color { ColorAnimation { duration: 150 } }

        Text {
            anchors.centerIn: parent
            text: parent.sym
            color: view.sys.colMuted
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 1 }
        }
        MouseArea {
            id: navMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.pressedAction()
        }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: SetScroll { sys: view.sys }

        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                var max = Math.max(0, flick.contentHeight - flick.height);
                flick.contentY = Math.max(0, Math.min(max, flick.contentY - d));
            }
        }

        ColumnLayout {
            id: col
            width: flick.width
            spacing: 12

            // Top Header: Navegação de Mês/Ano e Botões de Ação
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                NavBtn { sym: "‹"; onPressedAction: view.shift(-1) }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: (view.sys && view.sys.isPt ? view.monthsPt : (view.sys && view.sys.isEn ? view.monthsEn : view.monthsRu))[view.viewMonth]
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize + 3; bold: true }
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: view.viewYear
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                    }
                }

                NavBtn { sym: "›"; onPressedAction: view.shift(1) }
            }

            // Dias da semana
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: view.sys && view.sys.isPt ? view.dowPt : (view.sys && view.sys.isEn ? view.dowEn : view.dowRu)
                    Text {
                        required property int index
                        required property string modelData
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: index >= 5 ? Qt.rgba(1, 0.42, 0.42, 0.55) : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
                    }
                }
            }

            // Grade do mês (42 células com marcações de eventos)
            GridLayout {
                Layout.fillWidth: true
                columns: 7
                rowSpacing: 4
                columnSpacing: 4

                Repeater {
                    model: view.cells

                    Rectangle {
                        id: cell
                        required property var modelData

                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: 10

                        color: cell.modelData.isSelected
                               ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.28)
                               : (cell.modelData.isToday
                                  ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                                  : (cellMa.containsMouse && cell.modelData.inMonth
                                     ? Qt.rgba(1, 1, 1, 0.08) : "transparent"))

                        border.color: cell.modelData.isSelected
                                      ? view.sys.colOn
                                      : (cell.modelData.isToday ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.6) : "transparent")
                        border.width: cell.modelData.isSelected ? 1.5 : 1
                        Behavior on color { ColorAnimation { duration: 140 } }

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 2

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: cell.modelData.day
                                color: !cell.modelData.inMonth ? Qt.rgba(1, 1, 1, 0.20)
                                     : cell.modelData.isSelected ? "#ffffff"
                                     : cell.modelData.isToday  ? view.sys.colOn
                                     : cell.modelData.weekend  ? Qt.rgba(1, 0.42, 0.42, 0.85)
                                                               : view.sys.colFg
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize - 2
                                    bold: cell.modelData.isToday || cell.modelData.isSelected
                                }
                            }

                            // Ponto indicador de evento(s)
                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                width: 4; height: 4; radius: 2
                                visible: cell.modelData.hasEvents && cell.modelData.inMonth
                                color: cell.modelData.isSelected ? "#ffffff" : view.sys.colOn
                            }
                        }

                        MouseArea {
                            id: cellMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                view.selectedDateStr = cell.modelData.dateStr;
                            }
                        }
                    }
                }
            }

            // Barra de ferramentas: Hoje, Sincronizar Google, Restaurar Backup
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                // Botão "Hoje"
                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: todayTxt.implicitWidth + 16
                    radius: 10
                    visible: view.viewMonth !== view.today.getMonth() || view.viewYear !== view.today.getFullYear()
                    color: todayMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: todayTxt
                        anchors.centerIn: parent
                        text: (view.sys && view.sys.isPt) ? "Hoje" : view.sys.tr("Сегодня")
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                    }
                    MouseArea {
                        id: todayMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.toToday()
                    }
                }

                Item { Layout.fillWidth: true }

                // Sincronizar Google Agenda
                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: syncTxt.implicitWidth + 16
                    radius: 10
                    color: syncMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: view.sys.colLine
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: view.isSyncing ? "󰔟" : "󰑐"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 12 }
                        }
                        Text {
                            id: syncTxt
                            text: view.isSyncing
                                  ? ((view.sys && view.sys.isPt) ? "Sincronizando…" : "Syncing…")
                                  : ((view.sys && view.sys.isPt) ? "Google Agenda" : "Google Sync")
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    MouseArea {
                        id: syncMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: !view.isSyncing
                        onClicked: view.syncCalendar()
                    }
                }

                // Restaurar Backup
                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: bkTxt.implicitWidth + 16
                    radius: 10
                    color: bkMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: view.sys.colLine
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            text: "󰉋"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 12 }
                        }
                        Text {
                            id: bkTxt
                            text: (view.sys && view.sys.isPt) ? "Backup" : "Backup"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    MouseArea {
                        id: bkMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: pImportBackup.running = true
                    }
                }

                // Configurações do Calendário
                Rectangle {
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 32
                    radius: 10
                    color: calSetMa.containsMouse || view.showSettingsModal ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.06)
                    border.color: view.showSettingsModal ? view.sys.colOn : view.sys.colLine
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "󰒓"
                        color: view.showSettingsModal ? view.sys.colOn : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: 13 }
                    }

                    MouseArea {
                        id: calSetMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.showSettingsModal = !view.showSettingsModal;
                            if (view.showSettingsModal) view.loadLinks();
                        }
                    }
                }
            }

            // Painel de Configurações do Calendário
            Rectangle {
                visible: view.showSettingsModal
                Layout.fillWidth: true
                radius: 14
                color: Qt.rgba(0.06, 0.06, 0.09, 0.96)
                border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.5)
                border.width: 1
                implicitHeight: calSetCol.implicitHeight + 24

                ColumnLayout {
                    id: calSetCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 12

                    // Cabeçalho da Configuração
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: (view.sys && view.sys.isPt) ? "CONFIGURAÇÕES DO CALENDÁRIO" : "CALENDAR SETTINGS"
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            width: 22; height: 22; radius: 11
                            color: Qt.rgba(1, 1, 1, 0.08)
                            Text { anchors.centerIn: parent; text: "󰅖"; color: view.sys.colMuted; font.pixelSize: 11 }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.showSettingsModal = false
                            }
                        }
                    }

                    // Seção 1: Vincular Google Agenda / ICS
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6

                        Text {
                            text: (view.sys && view.sys.isPt) ? "Vincular Calendário Externo (Google Agenda / ICS)" : "Link External Calendar (Google / ICS)"
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            TextField {
                                id: linkNameIn
                                Layout.preferredWidth: 130
                                placeholderText: (view.sys && view.sys.isPt) ? "Nome (ex: Pessoal)" : "Name"
                                text: "Google Agenda"
                                color: view.sys.colFg
                                placeholderTextColor: view.sys.colMuted
                                selectionColor: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 11 }
                                leftPadding: 10; rightPadding: 10; topPadding: 8; bottomPadding: 8
                                background: Rectangle {
                                    radius: 8
                                    color: Qt.rgba(0.08, 0.08, 0.11, 0.95)
                                    border.color: linkNameIn.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                                    border.width: 1
                                }
                            }

                            TextField {
                                id: linkUrlIn
                                Layout.fillWidth: true
                                placeholderText: (view.sys && view.sys.isPt) ? "URL do Feed ICS secreto do Google Agenda…" : "Secret Google Calendar ICS URL…"
                                color: view.sys.colFg
                                placeholderTextColor: view.sys.colMuted
                                selectionColor: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 11 }
                                leftPadding: 10; rightPadding: 10; topPadding: 8; bottomPadding: 8
                                background: Rectangle {
                                    radius: 8
                                    color: Qt.rgba(0.08, 0.08, 0.11, 0.95)
                                    border.color: linkUrlIn.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.15)
                                    border.width: 1
                                }
                            }

                            Rectangle {
                                Layout.preferredHeight: 32
                                Layout.preferredWidth: linkBtnTxt.implicitWidth + 18
                                radius: 8
                                color: linkMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4) : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25)
                                border.color: view.sys.colOn
                                border.width: 1

                                Text {
                                    id: linkBtnTxt
                                    anchors.centerIn: parent
                                    text: (view.sys && view.sys.isPt) ? "Vincular" : "Link"
                                    color: "#ffffff"
                                    font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                                }
                                MouseArea {
                                    id: linkMa
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        view.addLink(linkNameIn.text, linkUrlIn.text);
                                        linkUrlIn.text = "";
                                    }
                                }
                            }
                        }

                        // Lista de Calendários Vinculados
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            visible: view.calendarLinks.length > 0

                            Repeater {
                                model: view.calendarLinks
                                Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 30
                                    radius: 8
                                    color: Qt.rgba(1, 1, 1, 0.04)
                                    border.color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        spacing: 8

                                        Text { text: "󰸗"; color: view.sys.colOn; font.pixelSize: 12 }
                                        Text {
                                            text: modelData.name || "Calendário"
                                            color: view.sys.colFg
                                            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.url || ""
                                            color: view.sys.colMuted
                                            font { family: view.sys.fontFam; pixelSize: 10 }
                                            elide: Text.ElideMiddle
                                        }

                                        Rectangle {
                                            Layout.preferredWidth: 20
                                            Layout.preferredHeight: 20
                                            radius: 10
                                            color: delLMa.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.3) : "transparent"
                                            Text { anchors.centerIn: parent; text: "󰆴"; color: "#ff6b6b"; font.pixelSize: 11 }
                                            MouseArea {
                                                id: delLMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: view.deleteLink(modelData.id)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Divisor
                    Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1, 1, 1, 0.08) }

                    // Seção 2: Preferências de Notificação
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: (view.sys && view.sys.isPt) ? "Notificações de Eventos" : "Event Notifications"
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                        }

                        // Toggle Notificar Eventos
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: (view.sys && view.sys.isPt) ? "Notificar eventos próximos no sistema" : "Notify upcoming events"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }

                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 20
                                radius: 10
                                color: (view.sys && view.sys.cfg.calNotify) ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.16)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    width: 14; height: 14; radius: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: (view.sys && view.sys.cfg.calNotify) ? parent.width - width - 3 : 3
                                    color: "#ffffff"
                                    Behavior on x { NumberAnimation { duration: 140 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (view.sys && view.sys.cfg) {
                                            view.sys.cfg.calNotify = !view.sys.cfg.calNotify;
                                            view.sys.saveCfg();
                                        }
                                    }
                                }
                            }
                        }

                        // Antecedência (Minutos)
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: (view.sys && view.sys.isPt) ? "Avisar com antecedência de:" : "Remind before:"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }

                            Item { Layout.fillWidth: true }

                            Repeater {
                                model: [5, 10, 15, 30]
                                Rectangle {
                                    required property int modelData
                                    Layout.preferredHeight: 24
                                    Layout.preferredWidth: minChipTxt.implicitWidth + 14
                                    radius: 12
                                    readonly property bool selected: (view.sys && view.sys.cfg.calNotifyMinutes === modelData)
                                    color: selected ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.3) : Qt.rgba(1, 1, 1, 0.06)
                                    border.color: selected ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.1)
                                    border.width: 1

                                    Text {
                                        id: minChipTxt
                                        anchors.centerIn: parent
                                        text: modelData + " min"
                                        color: selected ? view.sys.colFg : view.sys.colMuted
                                        font { family: view.sys.fontFam; pixelSize: 10; bold: selected }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (view.sys && view.sys.cfg) {
                                                view.sys.cfg.calNotifyMinutes = modelData;
                                                view.sys.saveCfg();
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Toggle Som de Notificação
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                Layout.fillWidth: true
                                text: (view.sys && view.sys.isPt) ? "Emitir som ao notificar evento" : "Play notification sound"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }

                            Rectangle {
                                Layout.preferredWidth: 38
                                Layout.preferredHeight: 20
                                radius: 10
                                color: (view.sys && view.sys.cfg.calNotifySound) ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.16)
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    width: 14; height: 14; radius: 7
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: (view.sys && view.sys.cfg.calNotifySound) ? parent.width - width - 3 : 3
                                    color: "#ffffff"
                                    Behavior on x { NumberAnimation { duration: 140 } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (view.sys && view.sys.cfg) {
                                            view.sys.cfg.calNotifySound = !view.sys.cfg.calNotifySound;
                                            view.sys.saveCfg();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Mensagem de feedback de status
            Text {
                Layout.fillWidth: true
                visible: view.statusMsg.length > 0
                text: view.statusMsg
                color: view.sys.colOk
                horizontalAlignment: Text.AlignHCenter
                font { family: view.sys.fontFam; pixelSize: 11; bold: true }
            }

            // Divisor
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Qt.rgba(1, 1, 1, 0.08)
                Layout.topMargin: 4
                Layout.bottomMargin: 4
            }

            // Seção de Eventos do Dia Selecionado
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: (view.sys && view.sys.isPt) ? "EVENTOS DE " + view.selectedDateStr : "EVENTS FOR " + view.selectedDateStr
                        color: view.sys.colMuted
                        font {
                            family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                            bold: true; letterSpacing: 0.5
                        }
                    }
                    Text {
                        text: view.eventsForSelectedDate.length + ((view.sys && view.sys.isPt) ? " evento(s)" : " event(s)")
                        color: view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 12 }
                    }
                }

                Item { Layout.fillWidth: true }

                // Botão "+ Adicionar Evento"
                Rectangle {
                    id: addBtnRect
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 140
                    radius: 10
                    color: addMa.containsMouse
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.38)
                           : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                    border.color: view.sys.colOn
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: "󰐕"
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 13 }
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: (view.sys && view.sys.isPt) ? "Adicionar Evento" : "Add Event"
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: addMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.showAddModal = !view.showAddModal
                    }
                }
            }

            // Formulário Modal de Criação de Evento
            Rectangle {
                visible: view.showAddModal
                Layout.fillWidth: true
                radius: 14
                color: Qt.rgba(0.06, 0.06, 0.09, 0.96)
                border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.5)
                border.width: 1
                implicitHeight: formCol.implicitHeight + 24

                ColumnLayout {
                    id: formCol
                    anchors.fill: parent
                    anchors.margins: 14
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: (view.sys && view.sys.isPt) ? "NOVO EVENTO" : "NEW EVENT"
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: view.selectedDateStr
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    TextField {
                        id: fTitle
                        Layout.fillWidth: true
                        placeholderText: (view.sys && view.sys.isPt) ? "Título do evento (ex: Reunião, Dentista)…" : "Event title…"
                        color: "#ffffff"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.45)
                        selectionColor: view.sys.colOn
                        selectedTextColor: "#ffffff"
                        selectByMouse: true
                        font { family: view.sys.fontFam; pixelSize: 12 }
                        leftPadding: 12; rightPadding: 12; topPadding: 10; bottomPadding: 10
                        background: Rectangle {
                            radius: 10
                            color: Qt.rgba(0.12, 0.12, 0.16, 0.95)
                            border.color: fTitle.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.16)
                            border.width: fTitle.activeFocus ? 1.5 : 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        TextField {
                            id: fDate
                            Layout.fillWidth: true
                            text: view.selectedDateStr
                            placeholderText: "YYYY-MM-DD"
                            color: "#ffffff"
                            placeholderTextColor: Qt.rgba(1, 1, 1, 0.45)
                            selectionColor: view.sys.colOn
                            selectedTextColor: "#ffffff"
                            selectByMouse: true
                            font { family: view.sys.fontFam; pixelSize: 12 }
                            leftPadding: 12; rightPadding: 12; topPadding: 10; bottomPadding: 10
                            background: Rectangle {
                                radius: 10
                                color: Qt.rgba(0.12, 0.12, 0.16, 0.95)
                                border.color: fDate.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.16)
                                border.width: fDate.activeFocus ? 1.5 : 1
                            }
                        }

                        TextField {
                            id: fTime
                            Layout.preferredWidth: 110
                            text: "12:00"
                            placeholderText: "HH:MM"
                            color: "#ffffff"
                            placeholderTextColor: Qt.rgba(1, 1, 1, 0.45)
                            selectionColor: view.sys.colOn
                            selectedTextColor: "#ffffff"
                            selectByMouse: true
                            font { family: view.sys.fontFam; pixelSize: 12 }
                            leftPadding: 12; rightPadding: 12; topPadding: 10; bottomPadding: 10
                            background: Rectangle {
                                radius: 10
                                color: Qt.rgba(0.12, 0.12, 0.16, 0.95)
                                border.color: fTime.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.16)
                                border.width: fTime.activeFocus ? 1.5 : 1
                            }
                        }
                    }

                    TextField {
                        id: fDesc
                        Layout.fillWidth: true
                        placeholderText: (view.sys && view.sys.isPt) ? "Descrição ou notas (opcional)…" : "Description / notes…"
                        color: "#ffffff"
                        placeholderTextColor: Qt.rgba(1, 1, 1, 0.45)
                        selectionColor: view.sys.colOn
                        selectedTextColor: "#ffffff"
                        selectByMouse: true
                        font { family: view.sys.fontFam; pixelSize: 11 }
                        leftPadding: 12; rightPadding: 12; topPadding: 10; bottomPadding: 10
                        background: Rectangle {
                            radius: 10
                            color: Qt.rgba(0.12, 0.12, 0.16, 0.95)
                            border.color: fDesc.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.16)
                            border.width: fDesc.activeFocus ? 1.5 : 1
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            Layout.preferredHeight: 28
                            Layout.preferredWidth: 80
                            radius: 10
                            color: "transparent"
                            border.color: view.sys.colLine
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: (view.sys && view.sys.isPt) ? "Cancelar" : "Cancel"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.showAddModal = false
                            }
                        }

                        Rectangle {
                            Layout.preferredHeight: 28
                            Layout.preferredWidth: 80
                            radius: 10
                            color: view.sys.colOn

                            Text {
                                anchors.centerIn: parent
                                text: (view.sys && view.sys.isPt) ? "Salvar" : "Save"
                                color: "#111111"
                                font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (fTitle.text.trim().length > 0) {
                                        view.addEvent(fTitle.text.trim(), fDate.text.trim(), fTime.text.trim(), fDesc.text.trim(), false);
                                        fTitle.text = "";
                                        fDesc.text = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Lista de Eventos do Dia
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: view.eventsForSelectedDate

                    Rectangle {
                        id: evCard
                        required property var modelData
                        Layout.fillWidth: true
                        radius: 12
                        color: Qt.rgba(1, 1, 1, 0.05)
                        border.color: view.sys.colLine
                        border.width: 1
                        implicitHeight: evCol.implicitHeight + 16

                        ColumnLayout {
                            id: evCol
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                // Pílula de Horário
                                Rectangle {
                                    Layout.preferredHeight: 20
                                    Layout.preferredWidth: timeTxt.implicitWidth + 12
                                    radius: 10
                                    color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.18)

                                    Text {
                                        id: timeTxt
                                        anchors.centerIn: parent
                                        text: evCard.modelData.allDay
                                              ? ((view.sys && view.sys.isPt) ? "Dia todo" : "All day")
                                              : (evCard.modelData.time + (evCard.modelData.endTime ? " - " + evCard.modelData.endTime : ""))
                                        color: view.sys.colOn
                                        font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                                    }
                                }

                                // Origem (Google / Local)
                                Rectangle {
                                    Layout.preferredHeight: 18
                                    Layout.preferredWidth: srcTxt.implicitWidth + 10
                                    radius: 9
                                    color: Qt.rgba(1, 1, 1, 0.08)

                                    Text {
                                        id: srcTxt
                                        anchors.centerIn: parent
                                        text: evCard.modelData.source === "google" ? "Google" : "Local"
                                        color: Qt.rgba(1, 1, 1, 0.6)
                                        font { family: view.sys.fontFam; pixelSize: 9 }
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                // Botão Excluir
                                Rectangle {
                                    Layout.preferredWidth: 22
                                    Layout.preferredHeight: 22
                                    radius: 11
                                    color: delMa.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.25) : "transparent"

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✕"
                                        color: delMa.containsMouse ? "#ff6666" : view.sys.colMuted
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: delMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: view.deleteEvent(evCard.modelData.id)
                                    }
                                }
                            }

                            // Título do Evento
                            Text {
                                Layout.fillWidth: true
                                text: evCard.modelData.title || ""
                                color: view.sys.colFg
                                font { family: view.sys.fontFam; pixelSize: 13; bold: true }
                                wrapMode: Text.WordWrap
                            }

                            // Descrição do Evento
                            Text {
                                Layout.fillWidth: true
                                visible: (evCard.modelData.desc || "").trim().length > 0
                                text: (evCard.modelData.desc || "").trim()
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 11 }
                                elide: Text.ElideRight
                                maximumLineCount: 3
                                wrapMode: Text.WordWrap
                            }
                        }
                    }
                }

                // Placeholder se nenhum evento
                Text {
                    Layout.fillWidth: true
                    visible: view.eventsForSelectedDate.length === 0 && !view.showAddModal
                    text: (view.sys && view.sys.isPt)
                          ? "Nenhum evento para este dia. Clique em '+ Adicionar' acima para agendar."
                          : view.sys.tr("Нет событий на этот день.")
                    color: view.sys.colMuted
                    horizontalAlignment: Text.AlignHCenter
                    font { family: view.sys.fontFam; pixelSize: 11; italic: true }
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
                }
            }
        }
    }
}
