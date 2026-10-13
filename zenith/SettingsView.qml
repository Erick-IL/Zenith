import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell

// Settings window: search and list of sections on the left, section itself on the right.
//
// Each section lives in a separate Set*.qml file and receives only `sys`.
// The header with the icon and description is drawn by the frame, so the pages consist of
// the same cards and do not repeat the same markings one after another.
Item {
    id: view

    property var sys
    // section index in view.sections
    property int tab: 0

    implicitWidth: 980
    implicitHeight: 620

    // ------------------------------------------------------------- sections
    // keys - keywords for search: the section can be found using them, even if
    // the title does not contain the required word (“themes” → Appearance, “wifi” → Control
    // Center).
    readonly property var sections: [
        { id: "bar",     title: view.sys.tr("Панель и остров"),   g: 0xF12E1, page: "SetBarIsland.qml",
          sub: view.sys.tr("Как остров стоит на кромке и во что он разворачивается."),
          keys: "notch island pill bar height width cpu gpu load temperature остров вырез капсула нагрузка температура" },
        { id: "media",   title: view.sys.tr("Медиа"),          g: 0xF0387, page: "SetMedia.qml",
          sub: view.sys.tr("Плеер, обложки и то, что видно в свёрнутом острове."),
          keys: "player music cover звук плеер музыка обложка" },
        { id: "clock",   title: view.sys.tr("Часы и дата"),   g: 0xF0150, page: "SetClock.qml",
          sub: view.sys.tr("Формат времени, часовой пояс и подпись под ним."),
          keys: "clock time date timezone часы дата время пояс регион" },
        { id: "look",    title: view.sys.tr("Оформление"),     g: 0xF03D8, page: "SetAppearance.qml",
          sub: view.sys.tr("Виджеты, шрифты и оформление системы."),
          keys: "theme nothing font size sounds audio haptics виджеты звуки звук звуковые эффекты тема шрифт цвет" },
        { id: "weather", title: view.sys.tr("Погода"),        g: 0xF0590, page: "SetWeather.qml",
          sub: view.sys.tr("Ключ, город и шкала для виджета погоды."),
          keys: "weather temperature city openweather api key celsius fahrenheit "
                + "погода температура город ключ цельсий фаренгейт градусы" },
        { id: "motion",  title: view.sys.tr("Анимация"),         g: 0xF15B6, page: "SetMotion.qml",
          sub: view.sys.tr("Насколько быстро оболочка движется — и движется ли вообще."),
          keys: "animation speed bounce анимация скорость движение" },
        { id: "launch",  title: view.sys.tr("Лаунчер"),       g: 0xF0349, page: "SetLauncher.qml",
          sub: view.sys.tr("Поиск приложений и то, что он ищет кроме них."),
          keys: "launcher apps search запуск приложения поиск" },
        { id: "notif",   title: view.sys.tr("Уведомления"),  g: 0xF009A, page: "SetNotifications.qml",
          sub: view.sys.tr("Сколько карточек висит на экране и как долго."),
          keys: "notifications dnd toast уведомления не беспокоить" },
        { id: "cc",      title: view.sys.tr("Быстрые настройки"), g: 0xF062E, page: "SetControlCenter.qml",
          sub: view.sys.tr("Раскладка быстрых настроек — плитки переставляются мышью."),
          keys: "quick settings tiles layout wifi bluetooth плитки быстрые" },
        { id: "lock",    title: view.sys.tr("Экран блокировки"),    g: 0xF033E, page: "SetLock.qml",
          sub: view.sys.tr("Экран блокировки: что на нём видно и когда он появляется."),
          keys: "lock screen blur idle блокировка экран размытие" },
        { id: "display", title: view.sys.tr("Экран"),        g: 0xF0379, page: "SetDisplay.qml",
          sub: view.sys.tr("Разрешение, частота и масштаб подключённых экранов."),
          keys: "display monitor resolution refresh scale layout placement detect island "
                + "экран монитор разрешение герцовка раскладка расположение остров" },
        { id: "input",   title: view.sys.tr("Ввод"),           g: 0xF037D, page: "SetInput.qml",
          sub: view.sys.tr("Скорость указателя и разгон."),
          keys: "mouse keyboard layouts xkb pointer cursor sensitivity speed accel acceleration raw input flat "
                + "мышь клавиатура раскладки указатель курсор скорость сенса чувствительность разгон ввод" },
        { id: "system",  title: view.sys.tr("Система"),         g: 0xF0493, page: "SetSystem.qml",
          sub: view.sys.tr("Из чего собрана машина и чем она сейчас занята."),
          keys: "about system cpu ram temperature система озу температура процессы" }
    ]

    // Each navigation entry contains a few related pages. Page ids stay stable
    // so links from notifications and IPC still open the intended page.
    readonly property var groups: [
        { id: "island", title: view.sys.tr("Остров"), g: 0xF12E1, pages: ["bar", "media", "clock"] },
        { id: "appearance", title: view.sys.tr("Оформление"), g: 0xF03D8, pages: ["look", "weather", "motion"] },
        { id: "controls", title: view.sys.tr("Управление"), g: 0xF062E, pages: ["cc", "launch", "notif"] },
        { id: "devices", title: view.sys.tr("Устройства"), g: 0xF0379, pages: ["display", "input"] },
        { id: "security", title: view.sys.tr("Безопасность"), g: 0xF033E, pages: ["lock"] },
        { id: "system", title: view.sys.tr("Система"), g: 0xF0493, pages: ["system"] }
    ]

    function groupForPage(pageId) {
        for (var i = 0; i < groups.length; i++)
            if (groups[i].pages.indexOf(pageId) >= 0) return groups[i];
        return groups[0];
    }
    function pagesForGroup(group) {
        var result = [];
        for (var i = 0; i < group.pages.length; i++)
            for (var j = 0; j < sections.length; j++)
                if (sections[j].id === group.pages[i]) result.push({ index: j, title: sections[j].title });
        return result;
    }
    function groupMatches(group) {
        if (!view.query.length) return true;
        if (group.title.toLowerCase().indexOf(view.query.toLowerCase()) >= 0) return true;
        var pages = pagesForGroup(group);
        for (var i = 0; i < pages.length; i++)
            if (view.matches(sections[pages[i].index])) return true;
        return false;
    }
    function goGroup(group) {
        var pages = pagesForGroup(group);
        for (var i = 0; i < pages.length; i++)
            if (view.matches(sections[pages[i].index])) { view.go(pages[i].index); return; }
        if (pages.length) view.go(pages[0].index);
    }

    readonly property var section: sections[Math.max(0, Math.min(sections.length - 1, tab))]
    readonly property var activeGroup: groupForPage(section.id)
    readonly property var groupPages: pagesForGroup(activeGroup)

    // The section could be asked for by name - for example, update notification
    // leads directly to System. We look for the name here: the list of sections lives right there, and
    // no one outside needs to know what the partition number is.
    function goToSection(id) {
        if (!id) return;
        for (var i = 0; i < view.sections.length; i++) {
            if (view.sections[i].id === id) { view.go(i); break; }
        }
        // the request was fulfilled - otherwise re-opening the settings again
        // would lead to the same section
        view.sys.settingsSection = "";
    }
    Component.onCompleted: view.goToSection(view.sys.settingsSection)
    Connections {
        target: view.sys
        function onSettingsSectionChanged() { view.goToSection(view.sys.settingsSection); }
    }

    // ------------------------------------------------------------- history
    // The arrows above the section move through the already opened ones, like in a browser: a list
    // The sections are long, and going back to the previous one by hand is confusing.
    property var hist: [0]
    property int histAt: 0
    function go(i) {
        if (i === view.tab) return;
        var h = view.hist.slice(0, view.histAt + 1);
        h.push(i);
        view.hist = h;
        view.histAt = h.length - 1;
        view.tab = i;
    }
    function back()    { if (canBack)    { view.histAt--; view.tab = view.hist[view.histAt]; } }
    function forward() { if (canForward) { view.histAt++; view.tab = view.hist[view.histAt]; } }
    readonly property bool canBack:    histAt > 0
    readonly property bool canForward: histAt < hist.length - 1

    // ------------------------------------------------------------- search
    property string query: ""
    function matches(s) {
        if (view.query.length === 0) return true;
        var q = view.query.toLowerCase();
        return s.title.toLowerCase().indexOf(q) >= 0 || s.keys.toLowerCase().indexOf(q) >= 0;
    }

    // ========================================================== the window itself
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ----------------------------------------------------- sidebar
        ColumnLayout {
            // Width based on the longest signature, not “by eye”: list
            // sections is known in advance, and the excess air to the right of it
            // It just took up space from the settings themselves.
            readonly property real navW: {
                var m = 0;
                for (var i = 0; i < view.sections.length; i++)
                    m = Math.max(m, navMetric.advanceWidth(view.sections[i].title));
                // 7 indent + 28 icon + 10 space + text + 14 margin.
                // Font family metrics give a little less than they measure
                // Text itself (the style is selected later), so to the text
                // a tenth part was added: without it, long names were cut
                // with ellipses exactly where there was actually enough space.
                return Math.max(196, Math.min(300, Math.ceil(m * 1.25) + 64));
            }
            FontMetrics {
                id: navMetric
                font.family: view.sys.fontBody
                font.pixelSize: view.sys.fontSize - 1
            }

            // A layer nested in a RowLayout stretches itself by default -
            // without an explicit refusal, the width of the text did not solve anything, and the sidebar
            // took up all the free space.
            Layout.fillWidth: false
            Layout.preferredWidth: navW
            Layout.minimumWidth: navW
            Layout.maximumWidth: navW
            Layout.fillHeight: true
            spacing: 10

            // search by section
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                radius: 12
                color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b,
                               searchInput.activeFocus ? 0.12 : 0.07)
                Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                Text {
                    id: searchIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 11
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(0xF0349)
                    color: view.sys.colMuted
                    font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 2 }
                }

                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                    anchors.leftMargin: 8
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: view.sys.colFg
                    clip: true
                    selectByMouse: true
                    selectionColor: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.4)
                    font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 2 }
                    onTextChanged: view.query = text
                    // Enter opens the first matching partition
                    onAccepted: {
                        for (var i = 0; i < view.sections.length; i++)
                            if (view.matches(view.sections[i])) { view.go(i); break; }
                    }
                    Keys.onEscapePressed: { text = ""; focus = false; }

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: searchInput.text.length === 0
                        text: view.sys.tr("Поиск настроек")
                        color: view.sys.colMuted
                        font: searchInput.font
                    }
                }
            }

            // list of sections
            ListView {
                id: nav
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: view.groups
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: SetScroll { sys: view.sys }

                // same wheel as the page: the list of sections is longer
                // windows when the font is large
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        var max = Math.max(0, nav.contentHeight - nav.height);
                        nav.contentY = Math.max(0, Math.min(max, nav.contentY - d));
                    }
                }

                delegate: Rectangle {
                    id: navItem
                    required property int index
                    required property var modelData
                    readonly property bool active: view.activeGroup.id === navItem.modelData.id
                    readonly property bool shown: view.groupMatches(navItem.modelData)

                    width: nav.width
                    height: shown ? 42 : 0
                    visible: shown
                    radius: 13
                    color: navItem.active
                           ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.16)
                           : (navMa.containsMouse
                              ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.07)
                              : "transparent")
                    border.width: 1
                    border.color: navItem.active
                                  ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.35)
                                  : "transparent"
                    Behavior on color { ColorAnimation { duration: view.sys.animFade } }
                    Behavior on border.color { ColorAnimation { duration: view.sys.animFade } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 7
                        anchors.rightMargin: 10
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 9
                            color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.08)

                            Text {
                                anchors.centerIn: parent
                                text: String.fromCodePoint(navItem.modelData.g)
                                color: navItem.active ? view.sys.colOn : view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 1 }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: navItem.modelData.title
                            color: navItem.active ? view.sys.colFg : view.sys.colMuted
                            elide: Text.ElideRight
                            font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 1 }
                        }
                    }

                    MouseArea {
                        id: navMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.goGroup(navItem.modelData)
                    }
                }
            }
        }

        // ----------------------------------------------------- section
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 18
            spacing: 12

            // history arrows
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [{ g: 0xF004D, fwd: false }, { g: 0xF0054, fwd: true }]
                    Rectangle {
                        id: navArrow
                        required property var modelData
                        readonly property bool armed: navArrow.modelData.fwd ? view.canForward : view.canBack

                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 28
                        radius: 9
                        opacity: navArrow.armed ? 1 : 0.35
                        color: arrowMa.containsMouse && navArrow.armed
                               ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                               : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.06)
                        Behavior on color { ColorAnimation { duration: view.sys.animFade } }

                        Text {
                            anchors.centerIn: parent
                            text: String.fromCodePoint(navArrow.modelData.g)
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3 }
                        }

                        MouseArea {
                            id: arrowMa
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: navArrow.armed
                            cursorShape: Qt.PointingHandCursor
                            onClicked: navArrow.modelData.fwd ? view.forward() : view.back()
                        }
                    }
                }

                // Sub-abas do grupo ativo (quando há mais de uma página)
                RowLayout {
                    spacing: 6
                    visible: view.groupPages.length > 1

                    Repeater {
                        model: view.groupPages
                        Rectangle {
                            required property var modelData
                            readonly property bool active: view.tab === modelData.index
                            Layout.preferredHeight: 28
                            Layout.preferredWidth: tabTxt.implicitWidth + 20
                            radius: 9
                            color: active
                                   ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.22)
                                   : (tabMa.containsMouse ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.10) : "transparent")
                            border.width: 1
                            border.color: active ? view.sys.colOn : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12)
                            Behavior on color { ColorAnimation { duration: 140 } }

                            Text {
                                id: tabTxt
                                anchors.centerIn: parent
                                text: modelData.title
                                color: active ? view.sys.colFg : view.sys.colMuted
                                font { family: view.sys.fontBody; pixelSize: view.sys.fontSize - 3; bold: active }
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.go(modelData.index)
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }
            }

            // section header and cards in general scrolling
            Flickable {
                id: scroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: pageCol.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 3000
                ScrollBar.vertical: SetScroll { sys: view.sys }

                // We turn the wheel ourselves. Flickable's own processing depends
                // from the one who gets the event: the island catches the guidance
                // with his HoverHandler and in some positions he took the wheel
                // myself - scrolling worked only at the top edge.
                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        var d = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
                        var max = Math.max(0, scroll.contentHeight - scroll.height);
                        scroll.contentY = Math.max(0, Math.min(max, scroll.contentY - d));
                    }
                }

                ColumnLayout {
                    id: pageCol
                    width: scroll.width - 12   // space for scroll bar
                    spacing: 12

                    SetHeader {
                        sys: view.sys
                        glyph: String.fromCodePoint(view.section.g)
                        title: view.section.title
                        sub: view.section.sub
                    }

                    // We raise the page via setSource with ready `sys`:
                    // with a simple source, the page has time to build with
                    // an empty link, and all its bindings to the palette fail.
                    Loader {
                        id: pageLoader
                        Layout.fillWidth: true

                        function reload() { setSource(view.section.page, { sys: view.sys }); }
                        Component.onCompleted: reload()

                        Connections {
                            target: view
                            function onTabChanged() { pageLoader.reload(); }
                        }
                    }

                    Item { Layout.preferredHeight: 8 }
                }
            }
        }
    }

    // the section has changed - scrolling starts from the top, and not where it ended
    // previous
    onTabChanged: scroll.contentY = 0
}
