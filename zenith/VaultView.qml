import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Password manager with 2FA / TOTP support.
FocusScope {
    id: view
    property var sys

    implicitHeight: col.implicitHeight

    Component.onCompleted: {
        view.forceActiveFocus();
        if (view.sys.vaultUnlocked) view.refreshTotp();
    }
    FocusGrabber { target: view.sys.vaultUnlocked ? search : pw }

    // any action extends the life of the open storage
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        onPositionChanged: view.sys.touchVault()
        z: -1
    }

    function goBack() { view.sys.page = "main"; return true; }
    Keys.onEscapePressed: view.goBack()

    property string editId: ""       // id of record in edit mode
    property string query: ""
    property string currentTab: "all" // "all", "passwords", "2fa"
    property var totpCodes: ({})

    Process {
        id: pTotpBatch
        stdout: SplitParser {
            onRead: data => {
                try {
                    var parsed = JSON.parse(data.trim());
                    if (parsed && typeof parsed === "object") {
                        view.totpCodes = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    function refreshTotp() {
        if (!view.sys.vaultUnlocked || !view.sys.vaultEntries) return;
        var list = [];
        for (var i = 0; i < view.sys.vaultEntries.length; i++) {
            var e = view.sys.vaultEntries[i];
            if (e && e.totp && String(e.totp).trim().length > 0) {
                list.push({ id: String(e.id), totp: String(e.totp).trim() });
            }
        }
        if (list.length === 0) {
            view.totpCodes = ({});
            return;
        }
        pTotpBatch.command = ["python3", Quickshell.env("HOME") + "/.config/panacea/scripts/vault_totp.py", "batch", JSON.stringify(list)];
        pTotpBatch.running = true;
    }

    Timer {
        id: totpTimer
        interval: 1000
        repeat: true
        running: view.sys.vaultUnlocked
        onTriggered: view.refreshTotp()
    }

    Connections {
        target: view.sys
        function onVaultEntriesChanged() { view.refreshTotp(); }
        function onVaultUnlockedChanged() {
            if (view.sys.vaultUnlocked) view.refreshTotp();
        }
    }

    readonly property var shown: {
        var q = view.query.trim().toLowerCase();
        var list = view.sys.vaultEntries || [];
        if (view.currentTab === "2fa") {
            list = list.filter(function (e) {
                return e.totp && String(e.totp).trim().length > 0;
            });
        } else if (view.currentTab === "passwords") {
            list = list.filter(function (e) {
                return !e.totp || String(e.totp).trim().length === 0;
            });
        }
        if (q.length === 0) return list;
        return list.filter(function (e) {
            return String(e.label).toLowerCase().indexOf(q) >= 0
                || String(e.login).toLowerCase().indexOf(q) >= 0;
        });
    }

    readonly property real estimatedListHeight: {
        var h = 0;
        var listData = view.shown || [];
        for (var i = 0; i < listData.length; i++) {
            var it = listData[i];
            if (view.editId === it.id) h += 142;
            else if (it.totp && String(it.totp).trim().length > 0) h += 102;
            else h += 62;
        }
        return h;
    }

    // edit field: the same for name, login and password
    component Field: Rectangle {
        id: fld
        property alias text: fin.text
        property string hint: ""
        property bool secret: false
        Layout.fillWidth: true
        Layout.preferredHeight: 32
        radius: 10
        color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
        border.color: fin.activeFocus ? view.sys.colOn : view.sys.colLine
        TextInput {
            id: fin
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            verticalAlignment: TextInput.AlignVCenter
            color: view.sys.colFg
            selectByMouse: true
            echoMode: fld.secret && !fin.activeFocus ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
            onTextEdited: view.sys.touchVault()
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: fin.text.length === 0
                text: fld.hint
                color: Qt.rgba(1, 1, 1, 0.26)
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
            }
        }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 14

        // ------------------------------------------------------------ hat
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 40
                Layout.preferredHeight: 40
                radius: 12
                color: view.sys.vaultUnlocked ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.16)
                                              : Qt.rgba(1, 1, 1, 0.08)
                Glyph {
                    anchors.fill: parent
                    glyph: String.fromCodePoint(view.sys.vaultUnlocked ? 0xF0FC6 : 0xF033E)
                    color: view.sys.vaultUnlocked ? view.sys.colOk : view.sys.colMuted
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize + 2
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                    text: view.sys.tr("Пароли")
                    color: view.sys.colFg
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize; bold: true }
                }
                Text {
                    Layout.fillWidth: true
                    text: view.sys.vaultUnlocked
                          ? view.sys.vaultEntries.length + " " + view.sys.tr("записей")
                          : view.sys.tr("Введите пароль пользователя")
                    color: view.sys.colMuted
                    elide: Text.ElideRight
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                }
            }

            // close the vault manually
            Rectangle {
                visible: view.sys.vaultUnlocked
                Layout.preferredWidth: 34
                Layout.preferredHeight: 34
                radius: 11
                color: lockMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                Glyph {
                    anchors.fill: parent
                    glyph: String.fromCodePoint(0xF033E)
                    color: view.sys.colFg
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize - 2
                }
                MouseArea {
                    id: lockMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    // closed the storage - keep a blank request page
                    // there is no need for a password, let's go to the tiles
                    onClicked: { view.sys.lockVault(); view.sys.page = "main"; }
                }
            }
        }

        // ------------------------------------------------------- entering password
        Rectangle {
            visible: !view.sys.vaultUnlocked
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            radius: 12
            color: Qt.rgba(1, 1, 1, 0.06)
            border.width: 1
            border.color: pw.activeFocus ? view.sys.colOn : view.sys.colLine
            Behavior on border.color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 10
                spacing: 8

                TextInput {
                    id: pw
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: view.sys.colFg
                    selectByMouse: true
                    enabled: !view.sys.vaultBusy
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize }
                    onAccepted: { view.sys.unlockVault(text); text = ""; }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pw.text.length === 0
                        text: view.sys.tr("Пароль")
                        color: Qt.rgba(1, 1, 1, 0.28)
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize }
                    }
                }

                Text {
                    visible: view.sys.vaultBusy
                    text: view.sys.tr("Проверка…")
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                }
            }
        }

        Text {
            visible: !view.sys.vaultUnlocked && view.sys.vaultError.length > 0
            Layout.fillWidth: true
            text: view.sys.vaultError
            color: view.sys.colCrit
            wrapMode: Text.WordWrap
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
        }

        Text {
            visible: !view.sys.vaultUnlocked
            Layout.fillWidth: true
            text: view.sys.tr("Хранилище шифруется этим же паролем и закрывается само через 15 минут простоя.")
            color: Qt.rgba(1, 1, 1, 0.30)
            wrapMode: Text.WordWrap
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
        }

        // ---------------------------------------------------------- tabs (All, Passwords, 2FA)
        RowLayout {
            visible: view.sys.vaultUnlocked
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: [
                    { id: "all", label: (view.sys && view.sys.isPt) ? "Todos" : "Все", icon: "󰌋" },
                    { id: "passwords", label: (view.sys && view.sys.isPt) ? "Senhas" : "Пароли", icon: "󰢬" },
                    { id: "2fa", label: "2FA (TOTP)", icon: "󰒃" }
                ]

                Rectangle {
                    required property var modelData
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: tabTxt.implicitWidth + 24
                    radius: 14
                    readonly property bool active: view.currentTab === modelData.id
                    color: active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                  : (tabMa.containsMouse ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.05))
                    border.color: active ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1

                    RowLayout {
                        id: tabTxt
                        anchors.centerIn: parent
                        spacing: 6
                        Text {
                            text: modelData.icon
                            color: active ? view.sys.colOn : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                        Text {
                            text: modelData.label
                            color: active ? view.sys.colFg : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 11; bold: active }
                        }
                    }

                    MouseArea {
                        id: tabMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.currentTab = modelData.id
                    }
                }
            }
            Item { Layout.fillWidth: true }
        }

        // ---------------------------------------------------------- search/+
        RowLayout {
            visible: view.sys.vaultUnlocked
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 11
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: search.activeFocus ? view.sys.colOn : view.sys.colLine

                TextInput {
                    id: search
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    color: view.sys.colFg
                    selectByMouse: true
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    onTextChanged: { view.query = text; view.sys.touchVault(); }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: search.text.length === 0
                        text: view.sys.tr("Поиск")
                        color: Qt.rgba(1, 1, 1, 0.28)
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                    }
                }
            }

            // look for passwords in browsers
            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 11
                color: scanMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                opacity: view.sys.browserScanning ? 0.6 : 1

                Glyph {
                    id: scanGlyph
                    anchors.fill: parent
                    // during search - “clock”, otherwise browser icon
                    glyph: String.fromCodePoint(view.sys.browserScanning ? 0xF051B : 0xF059F)
                    color: view.sys.colFg
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize - 2

                    RotationAnimation on rotation {
                        running: view.sys.browserScanning
                        loops: Animation.Infinite
                        from: 0; to: 360; duration: 1400
                        onRunningChanged: if (!running) scanGlyph.rotation = 0
                    }
                }
                MouseArea {
                    id: scanMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: view.sys.browserScan()
                }
                ToolTip.visible: scanMa.containsMouse
                ToolTip.text: view.sys.tr("Из браузеров")
            }

            Rectangle {
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 11
                color: addMa.containsMouse ? Qt.rgba(1, 1, 1, 0.13) : Qt.rgba(1, 1, 1, 0.06)
                Glyph {
                    anchors.fill: parent
                    glyph: String.fromCodePoint(0xF0415)      // plus
                    color: view.sys.colFg
                    fontFam: view.sys.fontFam
                    size: view.sys.iconSize - 2
                }
                MouseArea {
                    id: addMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        view.sys.vaultAdd((view.sys && view.sys.isPt) ? "Nova Senha" : view.sys.tr("Новая запись"), "", "", "");
                        view.editId = view.sys.vaultEntries.length
                                      ? view.sys.vaultEntries[0].id : "";
                    }
                }
            }
        }

        // ------------------------------------------- found in browsers
        // Appears only after searching: nothing is transferred by itself,
        // A person adds each entry himself - or all at once.
        ColumnLayout {
            visible: view.sys.vaultUnlocked
                     && (view.sys.browserScanning || view.sys.browserScanned)
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    Layout.fillWidth: true
                    text: view.sys.browserScanning
                          ? view.sys.tr("Ищем в браузерах…")
                          : (view.sys.browserError.length
                             ? view.sys.browserError
                             : (view.sys.browserFound.length
                                ? view.sys.tr("Найдено в браузерах") + " · "
                                  + view.sys.browserFound.length
                                : view.sys.tr("В браузерах ничего нового")))
                    color: view.sys.browserError.length ? view.sys.colCrit : view.sys.colMuted
                    elide: Text.ElideRight
                    font {
                        family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4
                        bold: true; capitalization: Font.AllUppercase; letterSpacing: 1
                    }
                }

                // add everything at once
                Rectangle {
                    visible: view.sys.browserFound.length > 1
                    Layout.preferredWidth: allTxt.implicitWidth + 20
                    Layout.preferredHeight: 26
                    radius: 9
                    color: allMa.containsMouse ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.28)
                                               : Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.16)
                    Text {
                        id: allTxt
                        anchors.centerIn: parent
                        text: view.sys.tr("Добавить все")
                        color: view.sys.colOk
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                    }
                    MouseArea {
                        id: allMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.sys.browserImportAll()
                    }
                }
            }

            ListView {
                visible: view.sys.browserFound.length > 0
                Layout.fillWidth: true
                Layout.preferredHeight:
                    Math.min(200, Math.max(0, view.sys.browserFound.length * 50))
                clip: true
                spacing: 6
                model: view.sys.browserFound
                boundsBehavior: Flickable.StopAtBounds

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
                }

                delegate: Rectangle {
                    id: found
                    required property var modelData
                    width: ListView.view.width
                    height: 44
                    radius: 11
                    color: Qt.rgba(1, 1, 1, 0.05)
                    border.width: 1
                    border.color: view.sys.colLine

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 10

                        Glyph {
                            Layout.preferredWidth: 22
                            Layout.preferredHeight: 22
                            glyph: String.fromCodePoint(0xF059F)
                            color: view.sys.colMuted
                            fontFam: view.sys.fontFam
                            size: view.sys.iconSize - 5
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            Text {
                                Layout.fillWidth: true
                                text: String(found.modelData.url || "")
                                color: view.sys.colFg
                                elide: Text.ElideRight
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize - 3
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: String(found.modelData.login || "") + "   "
                                      + String(found.modelData.browser || "")
                                color: view.sys.colMuted
                                elide: Text.ElideRight
                                font {
                                    family: view.sys.fontFam
                                    pixelSize: view.sys.fontSize - 5
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 10
                            color: impMa.containsMouse ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.28)
                                                       : Qt.rgba(1, 1, 1, 0.07)
                            Glyph {
                                anchors.fill: parent
                                glyph: String.fromCodePoint(0xF0415)   // plus
                                color: impMa.containsMouse ? view.sys.colOk : view.sys.colFg
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize - 4
                            }
                            MouseArea {
                                id: impMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.sys.browserImport(found.modelData)
                            }
                        }
                    }
                }
            }
        }

        // ------------------------------------------------------------ list
        ListView {
            id: list
            visible: view.sys.vaultUnlocked
            Layout.fillWidth: true
            Layout.preferredHeight: view.shown.length > 0
                ? Math.min(Math.max(540, (view.sys && view.sys.height ? view.sys.height - 240 : 680)), Math.max(160, view.estimatedListHeight))
                : 0
            clip: true
            spacing: 6
            model: view.shown
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                contentItem: Rectangle { radius: 2; color: Qt.rgba(1, 1, 1, 0.22) }
            }

            delegate: Rectangle {
                id: row
                required property var modelData
                readonly property bool editing: view.editId === row.modelData.id
                readonly property bool hasTotp: row.modelData.totp && String(row.modelData.totp).trim().length > 0
                readonly property var totpInfo: (view.totpCodes && view.totpCodes[String(row.modelData.id)]) ? view.totpCodes[String(row.modelData.id)] : null

                width: list.width
                height: row.editing ? 136 : (row.hasTotp ? 96 : 56)
                radius: 12
                color: rowMa.containsMouse ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: view.sys.colLine
                Behavior on height { NumberAnimation { duration: view.sys.animQuick } }
                Behavior on color { ColorAnimation { duration: 140 } }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onContainsMouseChanged: if (containsMouse) view.sys.touchVault()
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 9
                            color: row.hasTotp ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                            Glyph {
                                anchors.fill: parent
                                glyph: String.fromCodePoint(row.hasTotp ? 0xF0FC6 : 0xF0306)
                                color: row.hasTotp ? view.sys.colOn : view.sys.colMuted
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize - 4
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            RowLayout {
                                spacing: 6
                                Text {
                                    text: String(row.modelData.label)
                                    color: view.sys.colFg
                                    elide: Text.ElideRight
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2; bold: true }
                                }
                                Rectangle {
                                    visible: row.hasTotp
                                    Layout.preferredHeight: 14
                                    Layout.preferredWidth: 28
                                    radius: 7
                                    color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "2FA"
                                        color: view.sys.colOn
                                        font { family: view.sys.fontFam; pixelSize: 8; bold: true }
                                    }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: String(row.modelData.login).length
                                      ? String(row.modelData.login) + "   " + String(row.modelData.at)
                                      : String(row.modelData.at)
                                color: view.sys.colMuted
                                elide: Text.ElideRight
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 5 }
                            }
                        }

                        // copy password
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 10
                            color: copyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                            Glyph {
                                anchors.fill: parent
                                glyph: String.fromCodePoint(copyMa.done ? 0xF012C : 0xF018F)
                                color: copyMa.done ? view.sys.colOk : view.sys.colFg
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize - 4
                            }
                            MouseArea {
                                id: copyMa
                                property bool done: false
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    view.sys.vaultCopy(String(row.modelData.pw));
                                    done = true; doneTimer.restart();
                                }
                                Timer { id: doneTimer; interval: 1200; onTriggered: copyMa.done = false }
                            }
                            ToolTip.visible: copyMa.containsMouse
                            ToolTip.text: (view.sys && view.sys.isPt) ? "Copiar Senha" : "Copy Password"
                        }

                        // editing
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 10
                            color: editMa.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07)
                            Glyph {
                                anchors.fill: parent
                                glyph: String.fromCodePoint(0xF03EB)     // pencil
                                color: view.sys.colFg
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize - 4
                            }
                            MouseArea {
                                id: editMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.editId = row.editing ? "" : String(row.modelData.id)
                            }
                        }

                        // delete
                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            radius: 10
                            color: delMa.containsMouse ? Qt.rgba(1, 0.27, 0.27, 0.18) : Qt.rgba(1, 1, 1, 0.07)
                            Glyph {
                                anchors.fill: parent
                                glyph: String.fromCodePoint(0xF01B4)     // basket
                                color: delMa.containsMouse ? view.sys.colCrit : view.sys.colFg
                                fontFam: view.sys.fontFam
                                size: view.sys.iconSize - 4
                            }
                            MouseArea {
                                id: delMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.sys.vaultRemove(String(row.modelData.id))
                            }
                        }
                    }

                    // Barra de 2FA (TOTP) quando não está editando
                    Rectangle {
                        visible: row.hasTotp && !row.editing
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 8
                        color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.12)
                        border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.30)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 8

                            Text {
                                text: "󰒃"
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 13 }
                            }

                            Text {
                                text: "2FA"
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: (row.totpInfo && row.totpInfo.formatted) ? row.totpInfo.formatted : ((row.totpInfo && row.totpInfo.code) ? row.totpInfo.code : "------")
                                color: view.sys.colFg
                                font { family: "monospace"; pixelSize: 15; bold: true; letterSpacing: 2 }
                            }

                            // Contador de segundos restantes (ex: 24s)
                            Rectangle {
                                Layout.preferredHeight: 20
                                Layout.preferredWidth: 32
                                radius: 10
                                color: (row.totpInfo && row.totpInfo.remaining <= 5) ? Qt.rgba(1, 0.27, 0.27, 0.25) : Qt.rgba(1, 1, 1, 0.08)
                                border.color: (row.totpInfo && row.totpInfo.remaining <= 5) ? view.sys.colCrit : "transparent"
                                border.width: 1

                                Text {
                                    anchors.centerIn: parent
                                    text: (row.totpInfo && row.totpInfo.remaining !== undefined) ? (row.totpInfo.remaining + "s") : "30s"
                                    color: (row.totpInfo && row.totpInfo.remaining <= 5) ? view.sys.colCrit : view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                                }
                            }

                            // Botão de Copiar Código 2FA
                            Rectangle {
                                Layout.preferredWidth: 26
                                Layout.preferredHeight: 26
                                radius: 8
                                color: copyTotpMa.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)

                                Text {
                                    anchors.centerIn: parent
                                    text: copyTotpMa.done ? "󰄬" : "󰆏"
                                    color: copyTotpMa.done ? view.sys.colOk : view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: 12 }
                                }

                                MouseArea {
                                    id: copyTotpMa
                                    property bool done: false
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var c = (row.totpInfo && row.totpInfo.code) ? row.totpInfo.code : "";
                                        if (c) {
                                            view.sys.vaultCopy(c);
                                            done = true;
                                            totpDoneTimer.restart();
                                        }
                                    }
                                    Timer { id: totpDoneTimer; interval: 1200; onTriggered: copyTotpMa.done = false }
                                }
                                ToolTip.visible: copyTotpMa.containsMouse
                                ToolTip.text: (view.sys && view.sys.isPt) ? "Copiar Código 2FA" : "Copy 2FA Code"
                            }
                        }
                    }

                    // edit block: 2 linhas de campos
                    ColumnLayout {
                        visible: row.editing
                        Layout.fillWidth: true
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Field { id: fLabel; text: String(row.modelData.label); hint: (view.sys && view.sys.isPt) ? "Nome do Serviço" : view.sys.tr("Название") }
                            Field { id: fLogin; text: String(row.modelData.login); hint: (view.sys && view.sys.isPt) ? "Usuário / E-mail" : view.sys.tr("Логин") }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6
                            Field { id: fPw; text: String(row.modelData.pw); hint: (view.sys && view.sys.isPt) ? "Senha" : view.sys.tr("Пароль"); secret: true }
                            Field { id: fTotp; text: String(row.modelData.totp || ""); hint: (view.sys && view.sys.isPt) ? "Chave 2FA / TOTP (opcional)" : "2FA Secret (TOTP)"; secret: true }

                            Rectangle {
                                Layout.preferredWidth: 54
                                Layout.preferredHeight: 32
                                radius: 10
                                color: okMa.containsMouse ? Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.28)
                                                          : Qt.rgba(view.sys.colOk.r, view.sys.colOk.g, view.sys.colOk.b, 0.16)
                                Text {
                                    anchors.centerIn: parent
                                    text: "OK"
                                    color: view.sys.colOk
                                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
                                }
                                MouseArea {
                                    id: okMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        view.sys.vaultUpdate(String(row.modelData.id),
                                                             fLabel.text, fLogin.text, fPw.text, fTotp.text);
                                        view.editId = "";
                                        view.refreshTotp();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Text {
            visible: view.sys.vaultUnlocked && view.shown.length === 0
            Layout.fillWidth: true
            text: view.query.length ? view.sys.tr("Ничего не найдено")
                                    : view.sys.tr("Пока ни одного пароля")
            color: view.sys.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
        }
    }
}
