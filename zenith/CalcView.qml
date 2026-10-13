import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io

// Complete calculator in Dynamic Island with full numpad support,

// Calculation history and Temperature, Metric and Currency converters.


FocusScope {
    id: view
    property var sys

    implicitHeight: mainCol.implicitHeight

    // Abas: "calc" | "temp" | "metric" | "currency"
    property string activeTab: "calc"

    // ------------------------------------------------------------- Estado da Calculadora
    property string expr: ""
    property string result: "0"
    property string history: ""
    property bool justEvaluated: false
    property string copyToast: ""

    function appendChar(ch) {
        if (view.justEvaluated) {
            // If you have just evaluated and pressed an operator (+, -, *, /, %), the calculation continues


            if (ch === "+" || ch === "−" || ch === "×" || ch === "÷" || ch === "%" || ch === "^") {
                view.expr = view.result;
            } else {
                view.expr = "";
            }
            view.justEvaluated = false;
        }

        // Basic validations of consecutive operators


        var ops = ["+", "−", "×", "÷", "%", "^"];
        var lastChar = view.expr.length > 0 ? view.expr.charAt(view.expr.length - 1) : "";

        if (ops.indexOf(ch) >= 0 && ops.indexOf(lastChar) >= 0) {
            // Substitui operador anterior
            view.expr = view.expr.substring(0, view.expr.length - 1) + ch;
            calculateLive();
            return;
        }

        if (ch === ".") {
            // Do not write two dots in the same number


            var parts = view.expr.split(/[\+\−\×\÷\%\^\(\)]/);
            var curNum = parts[parts.length - 1];
            if (curNum.indexOf(".") >= 0) return;
            if (curNum.length === 0) ch = "0.";
        }

        view.expr += ch;
        calculateLive();
    }

    function backspace() {
        if (view.justEvaluated) {
            view.justEvaluated = false;
            return;
        }
        if (view.expr.length > 0) {
            view.expr = view.expr.substring(0, view.expr.length - 1);
            calculateLive();
        }
    }

    function clearAll() {
        view.expr = "";
        view.result = "0";
        view.history = "";
        view.justEvaluated = false;
    }

    function toggleSign() {
        if (view.justEvaluated) {
            view.expr = view.result;
            view.justEvaluated = false;
        }
        if (view.expr.length === 0) return;
        // Try to reverse the last number


        var match = view.expr.match(/(.*?)([\+\−\×\÷\(])?(\d+\.?\d*)$/);
        if (match) {
            var prefix = match[1] || "";
            var op = match[2] || "";
            var num = match[3] || "";
            if (op === "−") {
                view.expr = prefix + (prefix.length > 0 ? "+" : "") + num;
            } else if (op === "+") {
                view.expr = prefix + "−" + num;
            } else {
                view.expr = prefix + (op ? op : "") + "(-" + num + ")";
            }
            calculateLive();
        }
    }

    function sanitizeForEval(s) {
        if (!s) return "0";
        var clean = s.replace(/×/g, "*")
                     .replace(/÷/g, "/")
                     .replace(/−/g, "-")
                     .replace(/\^/g, "**");
        // porcentagem: 50% -> (50/100)
        clean = clean.replace(/(\d+(\.\d+)?)%/g, "($1/100)");
        // remove caracteres invalidos

        clean = clean.replace(/[^0-9\.\+\-\*\/\(\)]/g, "");
        return clean;
    }

    function calculateLive() {
        if (view.expr.trim().length === 0) {
            view.result = "0";
            return;
        }
        try {
            var s = sanitizeForEval(view.expr);
            // Evita erro de sintaxe se terminar em operador
            s = s.replace(/[\+\-\*\/]+$/, "");
            if (s.length === 0) return;
            var val = Function('"use strict"; return (' + s + ')')();
            if (typeof val === "number" && !isNaN(val) && isFinite(val)) {
                // Formata numbero

                if (Math.abs(val) < 1e-10) val = 0;
                view.result = String(Math.round(val * 100000000) / 100000000);
            }
        } catch (e) {
            // Expression in progress, does not update the result


        }
    }

    function evaluate() {
        if (view.expr.trim().length === 0) return;
        try {
            var s = sanitizeForEval(view.expr);
            var val = Function('"use strict"; return (' + s + ')')();
            if (typeof val === "number" && !isNaN(val) && isFinite(val)) {
                if (Math.abs(val) < 1e-10) val = 0;
                var resStr = String(Math.round(val * 100000000) / 100000000);
                view.history = view.expr + " =";
                view.result = resStr;
                view.expr = resStr;
                view.justEvaluated = true;
            }
        } catch (e) {
            view.result = "Erro";
        }
    }

    function copyToClip(text) {
        if (!text || text.length === 0) return;
        pCopyText.command = ["sh", "-c", "printf '%s' \"$1\" | wl-copy", "_", text];
        pCopyText.running = true;
        view.copyToast = view.sys.isPt ? "Copiado!" : "Copied!";
        toastTimer.restart();
    }

    Process { id: pCopyText }
    Timer {
        id: toastTimer
        interval: 1800
        onTriggered: view.copyToast = ""
    }

    // ------------------------------------------------------------- Conversion State: Temperature


    property real tempInputVal: 25.0
    property string tempInputStr: "25"
    property string tempBaseUnit: "C" // "C" | "F" | "K"

    readonly property real tempC: {
        var v = parseFloat(view.tempInputStr) || 0;
        if (tempBaseUnit === "C") return v;
        if (tempBaseUnit === "F") return (v - 32) * (5 / 9);
        if (tempBaseUnit === "K") return v - 273.15;
        return v;
    }
    readonly property real tempF: (tempC * (9 / 5)) + 32
    readonly property real tempK: tempC + 273.15

    function formatNum(n, decimals) {
        if (isNaN(n)) return "0";
        var d = decimals !== undefined ? decimals : 4;
        var r = Math.round(n * Math.pow(10, d)) / Math.pow(10, d);
        return String(r);
    }

    // ------------------------------------------------------------- Conversion Status: Metric


    property string metricCategory: "length" // "length" | "weight" | "volume" | "area" | "speed" | "data"
    property string metricInputStr: "1"
    property string metricUnitFrom: "m"
    property string metricUnitTo: "km"

    // Factors relating to the base unit of each category:


    // length -> base: metros
    readonly property var metricUnits: ({
        length: [
            { id: "mm", name: "Milímetro (mm)", factor: 0.001 },
            { id: "cm", name: "Centímetro (cm)", factor: 0.01 },
            { id: "m",  name: "Metro (m)", factor: 1.0 },
            { id: "km", name: "Quilômetro (km)", factor: 1000.0 },
            { id: "in", name: "Polegada (in)", factor: 0.0254 },
            { id: "ft", name: "Pé (ft)", factor: 0.3048 },
            { id: "yd", name: "Jarda (yd)", factor: 0.9144 },
            { id: "mi", name: "Milha (mi)", factor: 1609.344 }
        ],
        weight: [
            { id: "mg", name: "Miligrama (mg)", factor: 0.000001 },
            { id: "g",  name: "Grama (g)", factor: 0.001 },
            { id: "kg", name: "Quilograma (kg)", factor: 1.0 },
            { id: "t",  name: "Tonelada (t)", factor: 1000.0 },
            { id: "oz", name: "Onça (oz)", factor: 0.0283495 },
            { id: "lb", name: "Libra (lb)", factor: 0.453592 }
        ],
        volume: [
            { id: "ml",  name: "Mililitro (mL)", factor: 0.001 },
            { id: "l",   name: "Litro (L)", factor: 1.0 },
            { id: "m3",  name: "Metro cúbico (m³)", factor: 1000.0 },
            { id: "gal", name: "Galão US (gal)", factor: 3.78541 },
            { id: "floz",name: "Onça fluida (fl oz)", factor: 0.0295735 },
            { id: "cup", name: "Xícara (cup)", factor: 0.24 }
        ],
        area: [
            { id: "cm2", name: "Centímetro² (cm²)", factor: 0.0001 },
            { id: "m2",  name: "Metro² (m²)", factor: 1.0 },
            { id: "ha",  name: "Hectare (ha)", factor: 10000.0 },
            { id: "km2", name: "Quilômetro² (km²)", factor: 1000000.0 },
            { id: "sqft",name: "Pé² (ft²)", factor: 0.092903 },
            { id: "ac",  name: "Acre (ac)", factor: 4046.86 }
        ],
        speed: [
            { id: "ms",   name: "Metros por seg (m/s)", factor: 1.0 },
            { id: "kmh",  name: "Quilômetros por hora (km/h)", factor: 0.277778 },
            { id: "mph",  name: "Milhas por hora (mph)", factor: 0.44704 },
            { id: "knot", name: "Nó (knot)", factor: 0.514444 }
        ],
        data: [
            { id: "b",  name: "Byte (B)", factor: 1.0 },
            { id: "kb", name: "Kilobyte (KB)", factor: 1024.0 },
            { id: "mb", name: "Megabyte (MB)", factor: 1048576.0 },
            { id: "gb", name: "Gigabyte (GB)", factor: 1073741824.0 },
            { id: "tb", name: "Terabyte (TB)", factor: 1099511627776.0 }
        ]
    })

    function getMetricFactor(cat, unitId) {
        var list = view.metricUnits[cat] || [];
        for (var i = 0; i < list.length; i++) {
            if (list[i].id === unitId) return list[i].factor;
        }
        return 1.0;
    }

    readonly property real metricCalculatedResult: {
        var v = parseFloat(view.metricInputStr) || 0;
        var fFrom = view.getMetricFactor(view.metricCategory, view.metricUnitFrom);
        var fTo = view.getMetricFactor(view.metricCategory, view.metricUnitTo);
        if (fTo <= 0) return 0;
        var baseVal = v * fFrom;
        return baseVal / fTo;
    }

    function setMetricCategory(cat) {
        view.metricCategory = cat;
        var list = view.metricUnits[cat] || [];
        if (list.length >= 2) {
            view.metricUnitFrom = list[2] ? list[2].id : list[0].id;
            view.metricUnitTo = list[3] ? list[3].id : list[1].id;
        }
    }

    // ------------------------------------------------------------- Conversion State: Currency


    property string currInputStr: "100"
    property string currFrom: "USD"
    property string currTo: "BRL"
    property var currencyRates: ({
        USD: 1.0, BRL: 5.146, EUR: 0.865, GBP: 0.741, JPY: 154.38,
        CAD: 1.39, AUD: 1.40, CHF: 0.817, CNY: 6.725, ARS: 1510.3, BTC: 0.000016
    })
    property string currLastUpdated: ""
    property bool currLoading: false

    readonly property var currencyList: [
        { id: "BRL", sym: "R$", name: "Real Brasileiro" },
        { id: "USD", sym: "$",  name: "Dólar Americano" },
        { id: "EUR", sym: "€",  name: "Euro" },
        { id: "GBP", sym: "£",  name: "Libra Esterlina" },
        { id: "JPY", sym: "¥",  name: "Iene Japonês" },
        { id: "CAD", sym: "C$", name: "Dólar Canadense" },
        { id: "AUD", sym: "A$", name: "Dólar Australiano" },
        { id: "CHF", sym: "Fr", name: "Franco Suíço" },
        { id: "CNY", sym: "¥",  name: "Yuan Chinês" },
        { id: "ARS", sym: "$",  name: "Peso Argentino" },
        { id: "BTC", sym: "₿",  name: "Bitcoin" }
    ]

    function getRate(code) {
        return view.currencyRates[code] || 1.0;
    }

    readonly property real currCalculatedResult: {
        var v = parseFloat(view.currInputStr) || 0;
        var rFrom = view.getRate(view.currFrom);
        var rTo = view.getRate(view.currTo);
        if (rFrom <= 0) return 0;
        // Convert first to base USD, then to target currency

        var inUsd = v / rFrom;
        return inUsd * rTo;
    }

    Process {
        id: pCurr
        stdout: SplitParser {
            onRead: line => {
                try {
                    var data = JSON.parse(line.trim());
                    if (data && data.rates) {
                        view.currencyRates = data.rates;
                        if (data.updated) {
                            var d = new Date(data.updated * 1000);
                            view.currLastUpdated = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                        }
                    }
                } catch (e) {}
                view.currLoading = false;
            }
        }
    }

    function refreshCurrency(forceOnline) {
        view.currLoading = true;
        pCurr.command = ["python3", view.sys.scriptDir + "/currency.py", forceOnline ? "fetch" : "get"];
        pCurr.running = false;
        pCurr.running = true;
    }

    // ------------------------------------------------------------- Teclado & Numpad Handler
    focus: true
    Component.onCompleted: {
        forceActiveFocus();
        refreshCurrency(false);
    }

    // Dark and integrated Stylized ComboBox with Zenith theme

    component DarkComboBox: ComboBox {
        id: cb
        implicitHeight: 32

        displayText: {
            if (cb.currentIndex >= 0 && cb.model && cb.model.length > cb.currentIndex) {
                var item = cb.model[cb.currentIndex];
                if (item) {
                    if (cb.textRole && item[cb.textRole] !== undefined) return String(item[cb.textRole]);
                    return String(item);
                }
            }
            return cb.currentText;
        }

        background: Rectangle {
            implicitHeight: cb.height
            radius: 8
            color: cb.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.05)
            border.color: (cb.popup && cb.popup.visible)
                          ? view.sys.colOn
                          : (cb.hovered ? Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.25)
                                        : Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.12))
            border.width: 1
            Behavior on border.color { ColorAnimation { duration: 120 } }
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        contentItem: Text {
            leftPadding: 10
            rightPadding: 26
            text: cb.displayText
            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: true }
            color: view.sys.colFg
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }

        indicator: Text {
            x: cb.width - width - 10
            y: (cb.height - height) / 2
            text: String.fromCodePoint((cb.popup && cb.popup.visible) ? 0xF0143 : 0xF0140)
            font { family: view.sys.fontFam; pixelSize: 13 }
            color: (cb.popup && cb.popup.visible) ? view.sys.colOn : view.sys.colMuted
        }

        popup: Popup {
            y: cb.height + 4
            width: Math.max(cb.width, 180)
            implicitHeight: Math.min(contentItem.implicitHeight + 8, 220)
            padding: 4
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

            background: Rectangle {
                radius: 10
                color: Qt.rgba(view.sys.colBg.r, view.sys.colBg.g, view.sys.colBg.b, 0.98)
                border.color: Qt.rgba(view.sys.colFg.r, view.sys.colFg.g, view.sys.colFg.b, 0.20)
                border.width: 1
            }

            contentItem: ListView {
                clip: true
                implicitHeight: contentHeight
                model: cb.popup.visible ? cb.delegateModel : null
                currentIndex: cb.highlightedIndex
                ScrollIndicator.vertical: ScrollIndicator { }
            }
        }

        delegate: ItemDelegate {
            id: itemDel
            width: ListView.view ? ListView.view.width : cb.width
            height: 30
            highlighted: cb.highlightedIndex === index
            hoverEnabled: true

            background: Rectangle {
                radius: 6
                color: itemDel.highlighted
                       ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.28)
                       : (itemDel.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
            }

            contentItem: Text {
                leftPadding: 8
                rightPadding: 8
                text: {
                    var d = (typeof modelData !== "undefined" && modelData)
                            ? modelData
                            : ((typeof model !== "undefined" && model) ? model : null);
                    if (d && d.id && d.name && cb.textRole === "id") {
                        return d.id + "  " + d.name;
                    }
                    if (cb.textRole && d && d[cb.textRole] !== undefined) {
                        return String(d[cb.textRole]);
                    }
                    if (d !== null && d !== undefined) return String(d);
                    return "";
                }
                color: itemDel.highlighted ? view.sys.colOn : view.sys.colFg
                font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 3; bold: itemDel.highlighted }
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
    }

    Keys.onPressed: event => {
        // Numpad and common number keys


        var t = event.text;

        // If in the converter tabs, the numeric keypad edits the active converter input field


        if (view.activeTab === "temp") {
            if (event.key === Qt.Key_Backspace) {
                view.tempInputStr = view.tempInputStr.length > 1 ? view.tempInputStr.substring(0, view.tempInputStr.length - 1) : "0";
                event.accepted = true; return;
            }
            if (event.key === Qt.Key_Escape) { view.tempInputStr = "0"; event.accepted = true; return; }
            if (t && /^[0-9\.\-]$/.test(t)) {
                if (view.tempInputStr === "0" && t !== ".") view.tempInputStr = t;
                else if (t === "." && view.tempInputStr.indexOf(".") >= 0) {}
                else view.tempInputStr += t;
                event.accepted = true; return;
            }
            return;
        }

        if (view.activeTab === "metric") {
            if (event.key === Qt.Key_Backspace) {
                view.metricInputStr = view.metricInputStr.length > 1 ? view.metricInputStr.substring(0, view.metricInputStr.length - 1) : "0";
                event.accepted = true; return;
            }
            if (event.key === Qt.Key_Escape) { view.metricInputStr = "0"; event.accepted = true; return; }
            if (t && /^[0-9\.]$/.test(t)) {
                if (view.metricInputStr === "0" && t !== ".") view.metricInputStr = t;
                else if (t === "." && view.metricInputStr.indexOf(".") >= 0) {}
                else view.metricInputStr += t;
                event.accepted = true; return;
            }
            return;
        }

        if (view.activeTab === "currency") {
            if (event.key === Qt.Key_Backspace) {
                view.currInputStr = view.currInputStr.length > 1 ? view.currInputStr.substring(0, view.currInputStr.length - 1) : "0";
                event.accepted = true; return;
            }
            if (event.key === Qt.Key_Escape) { view.currInputStr = "0"; event.accepted = true; return; }
            if (t && /^[0-9\.]$/.test(t)) {
                if (view.currInputStr === "0" && t !== ".") view.currInputStr = t;
                else if (t === "." && view.currInputStr.indexOf(".") >= 0) {}
                else view.currInputStr += t;
                event.accepted = true; return;
            }
            return;
        }

        // --- Standard Calculator Mode ---


        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Equal) {
            view.evaluate();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Backspace) {
            view.backspace();
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Escape || event.key === Qt.Key_Delete) {
            if (view.expr.length > 0) {
                view.clearAll();
                event.accepted = true;
                return;
            }
            // If it was already clean, let the exhaust close the pill


            return;
        }

        // Mapeamento direto de caracteres de texto do teclado/numpad
        if (t.length === 1) {
            if (t >= "0" && t <= "9") { view.appendChar(t); event.accepted = true; return; }
            if (t === "." || t === ",") { view.appendChar("."); event.accepted = true; return; }
            if (t === "+") { view.appendChar("+"); event.accepted = true; return; }
            if (t === "-") { view.appendChar("−"); event.accepted = true; return; }
            if (t === "*") { view.appendChar("×"); event.accepted = true; return; }
            if (t === "/") { view.appendChar("÷"); event.accepted = true; return; }
            if (t === "%") { view.appendChar("%"); event.accepted = true; return; }
            if (t === "^") { view.appendChar("^"); event.accepted = true; return; }
            if (t === "(") { view.appendChar("("); event.accepted = true; return; }
            if (t === ")") { view.appendChar(")"); event.accepted = true; return; }
            if (t.toLowerCase() === "c") { view.clearAll(); event.accepted = true; return; }
        }
    }

    // ------------------------------------------------------------- Layout Visual
    ColumnLayout {
        id: mainCol
        width: parent.width
        spacing: 8

        // Header with Selection Tabs


        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            // Application icon


            Rectangle {
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 8
                color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.20)
                border.color: Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.40)
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "󰪚"
                    color: view.sys.colOn
                    font { family: view.sys.fontFam; pixelSize: 15; bold: true }
                }
            }

            // Tab bar

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                component TabBtn: Rectangle {
                    id: tbtn
                    property string tabId: ""
                    property string label: ""
                    property string icon: ""
                    readonly property bool active: view.activeTab === tbtn.tabId

                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    radius: 8
                    color: active ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25)
                                  : (tma.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
                    border.color: active ? view.sys.colOn : "transparent"
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 5
                        Text {
                            text: tbtn.icon
                            color: tbtn.active ? view.sys.colOn : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }
                        Text {
                            text: tbtn.label
                            color: tbtn.active ? view.sys.colFg : view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: tbtn.active }
                        }
                    }

                    MouseArea {
                        id: tma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            view.activeTab = tbtn.tabId;
                            view.forceActiveFocus();
                        }
                    }
                }

                TabBtn {
                    tabId: "calc"
                    icon: "󰪚"
                    label: view.sys.isPt ? "Calculadora" : "Calculator"
                }
                TabBtn {
                    tabId: "temp"
                    icon: "󰔄"
                    label: view.sys.isPt ? "Temperatura" : "Temperature"
                }
                TabBtn {
                    tabId: "metric"
                    icon: "󰑭"
                    label: view.sys.isPt ? "Métrica" : "Metric"
                }
                TabBtn {
                    tabId: "currency"
                    icon: "󱌠"
                    label: view.sys.isPt ? "Moeda" : "Currency"
                }
            }
        }

        // ========================================================= ABA 1: CALCULADORA
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: view.activeTab === "calc"

            // Result and Expression Display


            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    anchors.topMargin: 8
                    anchors.bottomMargin: 8
                    spacing: 2

                    // Expression Line/History


                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: view.history.length > 0 ? view.history : " "
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                            elide: Text.ElideLeft
                        }
                        Item { Layout.fillWidth: true }
                        // Toast de copiado
                        Text {
                            visible: view.copyToast.length > 0
                            text: view.copyToast
                            color: view.sys.colOk || "#10b981"
                            font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: true }
                        }
                    }

                    // Main Input/Result Line

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            Layout.fillWidth: true
                            text: view.expr.length > 0 ? view.expr : view.result
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 24; bold: true }
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideLeft
                        }

                        // Copy Result Button


                        Rectangle {
                            Layout.preferredWidth: 28
                            Layout.preferredHeight: 28
                            radius: 7
                            color: copyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                            border.color: Qt.rgba(1, 1, 1, 0.10)
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: "󰆏"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 13 }
                            }

                            MouseArea {
                                id: copyMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.copyToClip(view.result)
                            }
                        }
                    }
                }
            }

            // Grade do Teclado da Calculadora (5 colunas)
            GridLayout {
                Layout.fillWidth: true
                columns: 5
                rowSpacing: 6
                columnSpacing: 6

                component CalcBtn: Rectangle {
                    id: cbtn
                    property string sym: ""
                    property string op: ""
                    property bool isAccent: false
                    property bool isOp: false
                    property bool isDanger: false
                    signal triggered()

                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    radius: 9
                    color: isAccent ? (bma.pressed ? Qt.darker(view.sys.colOn, 1.2) : (bma.containsMouse ? Qt.lighter(view.sys.colOn, 1.1) : view.sys.colOn))
                         : isDanger ? (bma.containsMouse ? Qt.rgba(1, 0.27, 0.27, 0.25) : Qt.rgba(1, 0.27, 0.27, 0.12))
                         : isOp     ? (bma.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25) : Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.12))
                         : (bma.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                    border.color: isAccent ? view.sys.colOn
                                : isOp     ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.3)
                                : Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 100 } }

                    Text {
                        anchors.centerIn: parent
                        text: cbtn.sym
                        color: cbtn.isAccent ? view.sys.fgOn(view.sys.colOn)
                             : cbtn.isDanger ? "#f87171"
                             : cbtn.isOp     ? view.sys.colOn
                             : view.sys.colFg
                        font { family: view.sys.fontFam; pixelSize: 15; bold: cbtn.isAccent || cbtn.isOp }
                    }

                    MouseArea {
                        id: bma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            cbtn.triggered();
                            view.forceActiveFocus();
                        }
                    }
                }

                // Line 1

                CalcBtn { sym: "C";  isDanger: true; onTriggered: () => view.clearAll() }
                CalcBtn { sym: "(";  isOp: true; onTriggered: () => view.appendChar("(") }
                CalcBtn { sym: ")";  isOp: true; onTriggered: () => view.appendChar(")") }
                CalcBtn { sym: "%";  isOp: true; onTriggered: () => view.appendChar("%") }
                CalcBtn { sym: "÷";  isOp: true; onTriggered: () => view.appendChar("÷") }

                // Line 2

                CalcBtn { sym: "7";  onTriggered: () => view.appendChar("7") }
                CalcBtn { sym: "8";  onTriggered: () => view.appendChar("8") }
                CalcBtn { sym: "9";  onTriggered: () => view.appendChar("9") }
                CalcBtn { sym: "±";  isOp: true; onTriggered: () => view.toggleSign() }
                CalcBtn { sym: "×";  isOp: true; onTriggered: () => view.appendChar("×") }

                // Line 3

                CalcBtn { sym: "4";  onTriggered: () => view.appendChar("4") }
                CalcBtn { sym: "5";  onTriggered: () => view.appendChar("5") }
                CalcBtn { sym: "6";  onTriggered: () => view.appendChar("6") }
                CalcBtn { sym: "^";  isOp: true; onTriggered: () => view.appendChar("^") }
                CalcBtn { sym: "−";  isOp: true; onTriggered: () => view.appendChar("−") }

                // Line 4

                CalcBtn { sym: "1";  onTriggered: () => view.appendChar("1") }
                CalcBtn { sym: "2";  onTriggered: () => view.appendChar("2") }
                CalcBtn { sym: "3";  onTriggered: () => view.appendChar("3") }
                CalcBtn { sym: "⌫"; isOp: true; onTriggered: () => view.backspace() }
                CalcBtn { sym: "+";  isOp: true; onTriggered: () => view.appendChar("+") }

                // Line 5

                CalcBtn { Layout.columnSpan: 2; sym: "0"; onTriggered: () => view.appendChar("0") }
                CalcBtn { sym: "."; onTriggered: () => view.appendChar(".") }
                CalcBtn { Layout.columnSpan: 2; sym: "="; isAccent: true; onTriggered: () => view.evaluate() }
            }
        }

        // ========================================================= ABA 2: TEMPERATURA
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: view.activeTab === "temp"

            // Card de Entrada
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                radius: 10
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 10

                    Text {
                        text: view.sys.isPt ? "Valor de Entrada:" : "Input Value:"
                        color: view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4 }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 34
                        radius: 7
                        color: Qt.rgba(0, 0, 0, 0.3)
                        border.color: tinput.activeFocus ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.1)
                        clip: true

                        TextInput {
                            id: tinput
                            anchors.fill: parent
                            anchors.margins: 6
                            text: view.tempInputStr
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 15; bold: true }
                            verticalAlignment: Text.AlignVCenter
                            selectByMouse: true
                            onTextChanged: view.tempInputStr = text
                        }
                    }

                    // Seletor da unidade base
                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: ["C", "F", "K"]
                            Rectangle {
                                required property var modelData
                                width: 34
                                height: 32
                                radius: 6
                                color: view.tempBaseUnit === modelData ? view.sys.colOn : Qt.rgba(1, 1, 1, 0.08)
                                Text {
                                    anchors.centerIn: parent
                                    text: "°" + modelData
                                    color: view.tempBaseUnit === modelData ? view.sys.fgOn(view.sys.colOn) : view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        view.tempBaseUnit = modelData;
                                        view.forceActiveFocus();
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Resultados em 3 Cartoes Grandes

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                component TempCard: Rectangle {
                    id: tc
                    property string title: ""
                    property string valStr: ""
                    property string unit: ""
                    property string formula: ""
                    property color accentCol: view.sys.colOn

                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    radius: 10
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: tc.title
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 11; bold: true }
                            }
                            Item { Layout.fillWidth: true }
                            // Copy Button


                            Rectangle {
                                width: 22; height: 22; radius: 5
                                color: tcCopyMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"
                                Text {
                                    anchors.centerIn: parent
                                    text: "󰆏"
                                    color: view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: 11 }
                                }
                                MouseArea {
                                    id: tcCopyMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: view.copyToClip(tc.valStr + " " + tc.unit)
                                }
                            }
                        }

                        Text {
                            text: tc.valStr + " " + tc.unit
                            color: tc.accentCol
                            font { family: view.sys.fontFam; pixelSize: 18; bold: true }
                            elide: Text.ElideRight
                        }

                        Text {
                            text: tc.formula
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 9 }
                            elide: Text.ElideRight
                        }
                    }
                }

                TempCard {
                    title: "Celsius"
                    valStr: view.formatNum(view.tempC, 2)
                    unit: "°C"
                    formula: view.tempBaseUnit === "F" ? "(°F − 32) × 5/9" : (view.tempBaseUnit === "K" ? "K − 273.15" : "Unidade base")
                    accentCol: "#0ea5e9"
                }
                TempCard {
                    title: "Fahrenheit"
                    valStr: view.formatNum(view.tempF, 2)
                    unit: "°F"
                    formula: view.tempBaseUnit === "C" ? "(°C × 9/5) + 32" : (view.tempBaseUnit === "K" ? "(K − 273.15) × 9/5 + 32" : "Unidade base")
                    accentCol: "#f59e0b"
                }
                TempCard {
                    title: "Kelvin"
                    valStr: view.formatNum(view.tempK, 2)
                    unit: "K"
                    formula: view.tempBaseUnit === "C" ? "°C + 273.15" : (view.tempBaseUnit === "F" ? "(°F − 32) × 5/9 + 273.15" : "Unidade base")
                    accentCol: "#10b981"
                }
            }

            // Quick reference guide


            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 8
                color: Qt.rgba(1, 1, 1, 0.03)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 20

                    RowLayout {
                        spacing: 6
                        Text {
                            text: String.fromCodePoint(0xF0510)
                            color: "#38bdf8"
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }
                        Text {
                            text: "0 °C = 32 °F"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    RowLayout {
                        spacing: 6
                        Text {
                            text: String.fromCodePoint(0xF050F)
                            color: "#10b981"
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }
                        Text {
                            text: "20 °C = 68 °F"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }

                    RowLayout {
                        spacing: 6
                        Text {
                            text: String.fromCodePoint(0xF0511)
                            color: "#ef4444"
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }
                        Text {
                            text: "100 °C = 212 °F"
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 11 }
                        }
                    }
                }
            }
        }

        // ========================================================= ABA 3: METRIC

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: view.activeTab === "metric"

            // Seletor de Categorias
            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                component CatChip: Rectangle {
                    id: chip
                    property string catId: ""
                    property string label: ""
                    readonly property bool sel: view.metricCategory === chip.catId

                    Layout.fillWidth: true
                    Layout.preferredHeight: 28
                    radius: 7
                    color: sel ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.25) : Qt.rgba(1, 1, 1, 0.05)
                    border.color: sel ? view.sys.colOn : "transparent"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: chip.label
                        color: chip.sel ? view.sys.colFg : view.sys.colMuted
                        font { family: view.sys.fontFam; pixelSize: view.sys.fontSize - 4; bold: chip.sel }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: view.setMetricCategory(chip.catId)
                    }
                }

                CatChip { catId: "length"; label: view.sys.isPt ? "Comprimento" : "Length" }
                CatChip { catId: "weight"; label: view.sys.isPt ? "Massa" : "Weight" }
                CatChip { catId: "volume"; label: "Volume" }
                CatChip { catId: "area";   label: view.sys.isPt ? "Área" : "Area" }
                CatChip { catId: "speed";  label: view.sys.isPt ? "Velocidade" : "Speed" }
                CatChip { catId: "data";   label: view.sys.isPt ? "Dados" : "Data" }
            }

            // From -> To Conversion Panel


            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 110
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Line with From, Swap and To Button


                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Bloco "DE"
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: view.sys.isPt ? "De:" : "From:"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 10 }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    radius: 7
                                    color: Qt.rgba(0, 0, 0, 0.3)
                                    border.color: Qt.rgba(1, 1, 1, 0.1)

                                    TextInput {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        text: view.metricInputStr
                                        color: view.sys.colFg
                                        font { family: view.sys.fontFam; pixelSize: 14; bold: true }
                                        verticalAlignment: Text.AlignVCenter
                                        selectByMouse: true
                                        onTextChanged: view.metricInputStr = text
                                    }
                                }

                                // Seletor Unidade De
                                DarkComboBox {
                                    id: cbFrom
                                    Layout.preferredWidth: 125
                                    Layout.preferredHeight: 32
                                    model: view.metricUnits[view.metricCategory] || []
                                    textRole: "name"
                                    valueRole: "id"
                                    currentIndex: {
                                        var m = view.metricUnits[view.metricCategory] || [];
                                        for (var i = 0; i < m.length; i++) if (m[i].id === view.metricUnitFrom) return i;
                                        return 0;
                                    }
                                    onActivated: index => {
                                        var m = view.metricUnits[view.metricCategory] || [];
                                        if (m[index] && m[index].id) view.metricUnitFrom = m[index].id;
                                        else if (currentValue !== undefined) view.metricUnitFrom = currentValue;
                                    }
                                }
                            }
                        }

                        // Swap Button


                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 32
                            Layout.alignment: Qt.AlignBottom
                            radius: 8
                            color: swapMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: view.sys.colOn
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: String.fromCodePoint(0xF04E2)
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 15; bold: true }
                            }

                            MouseArea {
                                id: swapMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var tmp = view.metricUnitFrom;
                                    view.metricUnitFrom = view.metricUnitTo;
                                    view.metricUnitTo = tmp;
                                }
                            }
                        }

                        // "TO" block

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Text {
                                text: view.sys.isPt ? "Para:" : "To:"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 10 }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                // Unit To Selector

                                DarkComboBox {
                                    id: cbTo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 32
                                    model: view.metricUnits[view.metricCategory] || []
                                    textRole: "name"
                                    valueRole: "id"
                                    currentIndex: {
                                        var m = view.metricUnits[view.metricCategory] || [];
                                        for (var i = 0; i < m.length; i++) if (m[i].id === view.metricUnitTo) return i;
                                        return 0;
                                    }
                                    onActivated: index => {
                                        var m = view.metricUnits[view.metricCategory] || [];
                                        if (m[index] && m[index].id) view.metricUnitTo = m[index].id;
                                        else if (currentValue !== undefined) view.metricUnitTo = currentValue;
                                    }
                                }
                            }
                        }
                    }

                    // Calculated Result Line

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: view.metricInputStr + " " + view.metricUnitFrom + " = "
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: view.formatNum(view.metricCalculatedResult, 6) + " " + view.metricUnitTo
                            color: view.sys.colOn
                            font { family: view.sys.fontFam; pixelSize: 16; bold: true }
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 6
                            color: copyMetricMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)

                            Text {
                                anchors.centerIn: parent
                                text: "󰆏"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            MouseArea {
                                id: copyMetricMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.copyToClip(view.formatNum(view.metricCalculatedResult, 6) + " " + view.metricUnitTo)
                            }
                        }
                    }
                }
            }
        }

        // ========================================================= ABA 4: MOEDA (CURRENCY)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            visible: view.activeTab === "currency"

            // Currency Conversion Main Card


            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 116
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.05)
                border.color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // Valor a converter
                        ColumnLayout {
                            Layout.preferredWidth: 130
                            spacing: 2
                            Text {
                                text: view.sys.isPt ? "Quantia:" : "Amount:"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 10 }
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                radius: 7
                                color: Qt.rgba(0, 0, 0, 0.3)
                                border.color: Qt.rgba(1, 1, 1, 0.1)

                                TextInput {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    text: view.currInputStr
                                    color: view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: 15; bold: true }
                                    verticalAlignment: Text.AlignVCenter
                                    selectByMouse: true
                                    onTextChanged: view.currInputStr = text
                                }
                            }
                        }

                        // De Moeda
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: view.sys.isPt ? "De:" : "From:"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 10 }
                            }
                            DarkComboBox {
                                id: cbCurrFrom
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                model: view.currencyList
                                textRole: "id"
                                valueRole: "id"
                                currentIndex: {
                                    for (var i = 0; i < view.currencyList.length; i++) if (view.currencyList[i].id === view.currFrom) return i;
                                    return 0;
                                }
                                onActivated: index => {
                                    if (view.currencyList[index] && view.currencyList[index].id) {
                                        view.currFrom = view.currencyList[index].id;
                                    } else if (currentValue !== undefined) {
                                        view.currFrom = currentValue;
                                    }
                                }
                            }
                        }

                        // Swap Button


                        Rectangle {
                            Layout.preferredWidth: 32
                            Layout.preferredHeight: 34
                            Layout.alignment: Qt.AlignBottom
                            radius: 8
                            color: currSwapMa.containsMouse ? Qt.rgba(view.sys.colOn.r, view.sys.colOn.g, view.sys.colOn.b, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                            border.color: view.sys.colOn
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: String.fromCodePoint(0xF04E2)
                                color: view.sys.colOn
                                font { family: view.sys.fontFam; pixelSize: 15; bold: true }
                            }

                            MouseArea {
                                id: currSwapMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    var tmp = view.currFrom;
                                    view.currFrom = view.currTo;
                                    view.currTo = tmp;
                                }
                            }
                        }

                        // For Currency

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: view.sys.isPt ? "Para:" : "To:"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 10 }
                            }
                            DarkComboBox {
                                id: cbCurrTo
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                model: view.currencyList
                                textRole: "id"
                                valueRole: "id"
                                currentIndex: {
                                    for (var i = 0; i < view.currencyList.length; i++) if (view.currencyList[i].id === view.currTo) return i;
                                    return 1;
                                }
                                onActivated: index => {
                                    if (view.currencyList[index] && view.currencyList[index].id) {
                                        view.currTo = view.currencyList[index].id;
                                    } else if (currentValue !== undefined) {
                                        view.currTo = currentValue;
                                    }
                                }
                            }
                        }
                    }

                    // Conversion Result and Rate


                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: view.currInputStr + " " + view.currFrom + " = "
                            color: view.sys.colMuted
                            font { family: view.sys.fontFam; pixelSize: 13 }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: view.formatNum(view.currCalculatedResult, 2) + " " + view.currTo
                            color: "#10b981"
                            font { family: view.sys.fontFam; pixelSize: 17; bold: true }
                            elide: Text.ElideRight
                        }

                        // Copy Currency Button


                        Rectangle {
                            Layout.preferredWidth: 26
                            Layout.preferredHeight: 26
                            radius: 6
                            color: copyCurrMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)

                            Text {
                                anchors.centerIn: parent
                                text: "󰆏"
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 12 }
                            }

                            MouseArea {
                                id: copyCurrMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.copyToClip(view.formatNum(view.currCalculatedResult, 2) + " " + view.currTo)
                            }
                        }

                        // Update Online Quotes Button


                        Rectangle {
                            Layout.preferredHeight: 26
                            Layout.preferredWidth: refreshRow.implicitWidth + 14
                            radius: 6
                            color: refMa.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                            border.color: Qt.rgba(1, 1, 1, 0.1)
                            border.width: 1

                            RowLayout {
                                id: refreshRow
                                anchors.centerIn: parent
                                spacing: 5
                                Text {
                                    text: "󰑐"
                                    color: view.currLoading ? view.sys.colOn : view.sys.colMuted
                                    font { family: view.sys.fontFam; pixelSize: 12 }
                                }
                                Text {
                                    text: view.currLoading ? "..." : (view.sys.isPt ? "Atualizar" : "Refresh")
                                    color: view.sys.colFg
                                    font { family: view.sys.fontFam; pixelSize: 10 }
                                }
                            }

                            MouseArea {
                                id: refMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: view.refreshCurrency(true)
                            }
                        }
                    }
                }
            }

            // Simultaneous Comparison (Amount in main currencies)


            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                component CurrMiniCard: Rectangle {
                    id: cmc
                    property string targetCode: ""
                    property string targetSym: ""
                    readonly property real convertedVal: {
                        var v = parseFloat(view.currInputStr) || 0;
                        var rFrom = view.getRate(view.currFrom);
                        var rTarget = view.getRate(cmc.targetCode);
                        if (rFrom <= 0) return 0;
                        return (v / rFrom) * rTarget;
                    }

                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 8
                    color: Qt.rgba(1, 1, 1, 0.04)
                    border.color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 6
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: cmc.targetCode
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 9; bold: true }
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: cmc.targetSym
                                color: view.sys.colMuted
                                font { family: view.sys.fontFam; pixelSize: 9 }
                            }
                        }

                        Text {
                            text: view.formatNum(cmc.convertedVal, 2)
                            color: view.sys.colFg
                            font { family: view.sys.fontFam; pixelSize: 12; bold: true }
                            elide: Text.ElideRight
                        }
                    }
                }

                CurrMiniCard { targetCode: "BRL"; targetSym: "R$" }
                CurrMiniCard { targetCode: "USD"; targetSym: "$" }
                CurrMiniCard { targetCode: "EUR"; targetSym: "€" }
                CurrMiniCard { targetCode: "GBP"; targetSym: "£" }
                CurrMiniCard { targetCode: "JPY"; targetSym: "¥" }
            }
        }
    }
}
