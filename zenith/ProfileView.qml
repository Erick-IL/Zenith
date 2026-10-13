import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// ProfileView: Desktop UI dashboard widget for GitHub profile & developer stats
FocusScope {
    id: view
    property var sys

    width: parent ? parent.width : ((view.sys && view.sys.panelW) ? view.sys.panelW - 30 : 440)
    implicitHeight: col.implicitHeight

    // Purple palette
    readonly property color colPurple: "#a855f7"
    readonly property color colPurpleLight: "#c084fc"
    readonly property color colPurpleDark: "#7e22ce"
    readonly property color colPurpleDeep: "#3b1d60"
    readonly property color colGridEmpty: "#181524"

    property var profileData: null
    property string hoverDayText: ""
    property bool loadingProfile: false
    property bool editingLogin: false

    Component.onCompleted: {
        pLoadCache.running = true;
        pFetchProfile.running = true;
    }

    function doSaveUser(uname) {
        if (!uname || !uname.trim().length) return;
        view.loadingProfile = true;
        pSaveUser.command = ["python3", Quickshell.env("HOME") + "/.config/zenith/scripts/github_profile.py", "--save", uname.trim()];
        pSaveUser.running = false;
        pSaveUser.running = true;
    }

    function refreshProfile() {
        view.loadingProfile = true;
        pFetchProfile.running = false;
        pFetchProfile.running = true;
    }

    // Process: Leitura imediata do cache local
    Process {
        id: pLoadCache
        command: ["cat", Quickshell.env("HOME") + "/.config/zenith/github_data.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed && (parsed.login || parsed.repos !== undefined)) {
                        view.profileData = parsed;
                    }
                } catch (e) {}
            }
        }
    }

    // Process: Live search on GitHub

    Process {
        id: pFetchProfile
        command: ["python3", Quickshell.env("HOME") + "/.config/zenith/scripts/github_profile.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed) {
                        view.profileData = parsed;
                        profImg.source = "";
                        profImg.source = Quickshell.env("HOME") + "/.config/zenith/assets/github_avatar.png";
                    }
                } catch (e) {}
                view.loadingProfile = false;
            }
        }
        onExited: view.loadingProfile = false
    }

    // Process: Change user with --save


    Process {
        id: pSaveUser
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(text);
                    if (parsed) {
                        view.profileData = parsed;
                        profImg.source = "";
                        profImg.source = Quickshell.env("HOME") + "/.config/zenith/assets/github_avatar.png";
                    }
                } catch (e) {}
                view.loadingProfile = false;
                view.editingLogin = false;
            }
        }
        onExited: {
            view.loadingProfile = false;
            view.editingLogin = false;
        }
    }

    Process {
        id: pOpenUrl
        property string targetUrl: ""
        command: ["xdg-open", targetUrl]
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 12

        // ========================================================
        // TOP SECTION: Profile Header & Stats
        // ========================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: topCol.implicitHeight + 24
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.035)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            ColumnLayout {
                id: topCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    // Avatar picture
                    Rectangle {
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                        radius: 24
                        color: Qt.rgba(0.66, 0.33, 0.97, 0.20)
                        border.color: view.colPurple
                        border.width: 2
                        clip: true

                        Image {
                            id: profImg
                            anchors.fill: parent
                            source: Quickshell.env("HOME") + "/.config/zenith/assets/github_avatar.png"
                            fillMode: Image.PreserveAspectCrop
                            visible: status === Image.Ready && view.profileData && view.profileData.login
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: profImg.status !== Image.Ready || !view.profileData || !view.profileData.login
                            text: "󰊤" // GitHub Nerd Font icon
                            color: view.colPurpleLight
                            font { family: view.sys.fontFam; pixelSize: 24 }
                        }
                    }

                    // User Info
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            spacing: 6
                            Text {
                                text: (view.profileData && view.profileData.name && view.profileData.name.length > 0)
                                      ? view.profileData.name
                                      : ((view.profileData && view.profileData.login && view.profileData.login.length > 0)
                                         ? view.profileData.login
                                         : (view.sys && view.sys.isPt ? "Perfil GitHub" : "GitHub Profile"))
                                color: "#ffffff"
                                font { family: view.sys.fontDisplay; pixelSize: 15; bold: true }
                                elide: Text.ElideRight
                                Layout.maximumWidth: 170
                            }
                            Text {
                                text: (view.profileData && view.profileData.login && view.profileData.login.length > 0)
                                      ? ("@" + view.profileData.login)
                                      : ""
                                visible: text.length > 0
                                color: view.colPurpleLight
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }
                        }

                        Text {
                            text: (view.profileData && view.profileData.bio && view.profileData.bio.length > 0)
                                  ? ("\"" + view.profileData.bio + "\"")
                                  : ((view.profileData && view.profileData.login && view.profileData.login.length > 0)
                                     ? ""
                                     : (view.sys && view.sys.isPt ? "Conecte seu usuário do GitHub no botão ao lado" : "Connect your GitHub user via the user button"))
                            visible: text.length > 0
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font { family: view.sys.fontBody; pixelSize: 11; italic: true }
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    // Switch User/Login button


                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: view.editingLogin ? Qt.rgba(0.66, 0.33, 0.97, 0.35)
                             : (loginBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05))
                        border.color: view.editingLogin ? view.colPurple : "transparent"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "󰍂" // login / switch user icon
                            color: view.editingLogin ? view.colPurpleLight : "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 12 }
                        }
                        MouseArea {
                            id: loginBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                view.editingLogin = !view.editingLogin;
                                if (view.editingLogin) userInput.forceActiveFocus();
                            }
                        }
                    }

                    // Reload/Sync Button


                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: syncMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        Text {
                            id: syncIcon
                            anchors.centerIn: parent
                            text: "󰑐"
                            color: view.loadingProfile ? view.colPurpleLight : "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 12 }
                            RotationAnimator {
                                target: syncIcon
                                running: view.loadingProfile
                                from: 0; to: 360
                                duration: 1000
                                loops: Animation.Infinite
                            }
                        }
                        MouseArea {
                            id: syncMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.refreshProfile()
                        }
                    }

                    // Close button


                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        color: closeMa.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(1, 1, 1, 0.05)
                        Text {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                        MouseArea {
                            id: closeMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: view.sys.collapse()
                        }
                    }
                }

                // ========================================================
                // INLINE LOGIN / SWITCH USER BAR
                // ========================================================
                Rectangle {
                    visible: view.editingLogin
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    radius: 10
                    color: Qt.rgba(0, 0, 0, 0.40)
                    border.color: view.colPurple
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: "󰊤"
                            color: view.colPurpleLight
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }

                        TextInput {
                            id: userInput
                            Layout.fillWidth: true
                            color: "#ffffff"
                            font { family: view.sys.fontFam; pixelSize: 12 }
                            text: view.profileData ? (view.profileData.login || "") : ""
                            selectByMouse: true
                            clip: true

                            Text {
                                anchors.fill: parent
                                text: view.sys && view.sys.isPt ? "Usuário GitHub (ex: octocat)..." : "GitHub username (e.g. octocat)..."
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font: parent.font
                                visible: !parent.text && !parent.activeFocus
                            }

                            onAccepted: view.doSaveUser(userInput.text)
                        }

                        Rectangle {
                            Layout.preferredWidth: 64
                            Layout.preferredHeight: 24
                            radius: 6
                            color: saveMa.pressed ? view.colPurpleDark : view.colPurple
                            scale: saveMa.pressed ? 0.95 : (saveMa.containsMouse ? 1.05 : 1.0)
                            Behavior on scale { NumberAnimation { duration: 80 } }

                            Text {
                                anchors.centerIn: parent
                                text: view.loadingProfile ? "..." : (view.sys && view.sys.isPt ? "Salvar" : "Save")
                                color: "#ffffff"
                                font { family: view.sys.fontFam; pixelSize: 10; bold: true }
                            }

                            MouseArea {
                                id: saveMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.doSaveUser(userInput.text)
                            }
                        }
                    }
                }

                // Vertical List of Stats
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5

                    Repeater {
                        model: [
                            { label: "Total Stars: " + (view.profileData && view.profileData.stars !== undefined ? view.profileData.stars : 0), icon: "󰓎" },
                            { label: "Repositories: " + (view.profileData && view.profileData.repos !== undefined ? view.profileData.repos : 0), icon: "󰳔" },
                            { label: "Total Forks: " + (view.profileData && view.profileData.forks !== undefined ? view.profileData.forks : 0),  icon: "󰘬" }
                        ]

                        Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            radius: 6
                            color: Qt.rgba(1, 1, 1, 0.025)

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8

                                Text {
                                    text: modelData.icon
                                    color: view.colPurple
                                    font { family: view.sys.fontFam; pixelSize: 11 }
                                }
                                Text {
                                    text: modelData.label
                                    color: Qt.rgba(1, 1, 1, 0.85)
                                    font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ========================================================
        // MIDDLE SECTION: Contributions Heatmap Grid
        // ========================================================
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: midCol.implicitHeight + 20
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.035)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            ColumnLayout {
                id: midCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Contributions" + (view.profileData && view.profileData.totalContributions !== undefined ? (" (" + view.profileData.totalContributions + " no ano)") : "")
                        color: "#ffffff"
                        font { family: view.sys.fontDisplay; pixelSize: 12; bold: true }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: view.hoverDayText.length > 0 ? view.hoverDayText : "24 semanas de visão geral"
                        color: view.hoverDayText.length > 0 ? view.colPurpleLight : Qt.rgba(1, 1, 1, 0.40)
                        font { family: view.sys.fontFam; pixelSize: 10 }
                    }
                }

                // Heatmap Grid: 7 rows x 24 columns
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 7 * 11 + 6 * 3

                    Grid {
                        id: heatGrid
                        anchors.centerIn: parent
                        rows: 7
                        columns: 24
                        rowSpacing: 3
                        columnSpacing: 3
                        flow: Grid.TopToBottom

                        Repeater {
                            model: (view.profileData && view.profileData.contributions && view.profileData.contributions.length === 168)
                                   ? view.profileData.contributions
                                   : 168

                            Rectangle {
                                required property var modelData
                                required property int index
                                width: 10
                                height: 10
                                radius: 2.5

                                readonly property var itemObj: (typeof modelData === "object" && modelData !== null) ? modelData : null
                                readonly property int cellCount: itemObj ? (itemObj.count || 0) : 0
                                readonly property int cellLevel: itemObj ? (itemObj.level !== undefined ? itemObj.level : (cellCount > 0 ? 1 : 0)) : 0
                                readonly property string cellDate: itemObj ? (itemObj.date || "") : ""

                                color: cellLevel === 4 ? view.colPurpleLight
                                     : cellLevel === 3 ? view.colPurple
                                     : cellLevel === 2 ? view.colPurpleDark
                                     : cellLevel === 1 ? view.colPurpleDeep
                                     : view.colGridEmpty

                                border.width: cellMa.containsMouse ? 1 : 0
                                border.color: "#ffffff"
                                scale: cellMa.containsMouse ? 1.25 : 1.0
                                Behavior on scale { NumberAnimation { duration: 80 } }

                                MouseArea {
                                    id: cellMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        if (parent.cellDate && parent.cellDate.length > 0) {
                                            view.hoverDayText = parent.cellCount + (parent.cellCount === 1 ? " contribuição em " : " contribuições em ") + parent.cellDate;
                                        } else {
                                            view.hoverDayText = parent.cellCount + (parent.cellCount === 1 ? " contribuição" : " contribuições");
                                        }
                                    }
                                    onExited: view.hoverDayText = ""
                                }
                            }
                        }
                    }
                }
            }
        }

        // ========================================================
        // BOTTOM SECTION: Quick GitHub Links & Actions
        // ========================================================
        Rectangle {
            visible: view.profileData && view.profileData.login && view.profileData.login.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: btmCol.implicitHeight + 20
            radius: 14
            color: Qt.rgba(1, 1, 1, 0.035)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            ColumnLayout {
                id: btmCol
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    Text {
                        Layout.fillWidth: true
                        text: "github.com/" + (view.profileData ? view.profileData.login : "")
                        color: Qt.rgba(1, 1, 1, 0.70)
                        font { family: view.sys.fontFam; pixelSize: 11 }
                        elide: Text.ElideRight
                    }

                    // Open in Browser button


                    Rectangle {
                        Layout.preferredWidth: openBtnTxt.implicitWidth + 24
                        Layout.preferredHeight: 30
                        radius: 15
                        color: openBtnMa.pressed ? view.colPurpleDark
                             : (openBtnMa.containsMouse ? view.colPurpleLight : view.colPurple)
                        scale: openBtnMa.pressed ? 0.95 : (openBtnMa.containsMouse ? 1.04 : 1.0)
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "󰌹"
                                color: "#ffffff"
                                font { family: view.sys.fontFam; pixelSize: 11 }
                            }

                            Text {
                                id: openBtnTxt
                                text: view.sys && view.sys.isPt ? "Abrir Perfil" : "Open Profile"
                                color: "#ffffff"
                                font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                            }
                        }

                        MouseArea {
                            id: openBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (view.profileData && view.profileData.login) {
                                    pOpenUrl.targetUrl = "https://github.com/" + view.profileData.login;
                                    pOpenUrl.running = false;
                                    pOpenUrl.running = true;
                                }
                            }
                        }
                    }
                }
            }
        }

        // ========================================================
        // FOOTER: Quotes
        // ========================================================
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: footerCol.implicitHeight + 6

            ColumnLayout {
                id: footerCol
                anchors.centerIn: parent
                spacing: 2

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "\"Simplicity is the soul of efficiency.\""
                    color: Qt.rgba(1, 1, 1, 0.40)
                    font { family: view.sys.fontBody; pixelSize: 11; italic: true }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "— Austin Freeman"
                    color: Qt.rgba(1, 1, 1, 0.28)
                    font { family: view.sys.fontBody; pixelSize: 10 }
                }
            }
        }
    }
}
