import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../../"
import "../../../reusables"

Item {
    id: root
    anchors.fill: parent
    clip: true

    // --- redactor resize constraints ---
    property real minWidth: s(420)
    property real minHeight: s(300)
    property real maxWidth: s(1800)
    property real maxHeight: s(1200)

    function s(val) {
        return Scaler.s(val);
    }

    // ---- material tonal colors (same resolution as the analog clock) ----
    function resolveColor(token, fallback) {
        if (ThemeBackend.matugenColors) {
            var val = ThemeBackend.matugenColors[token];
            if (val) {
                if (typeof val === "string") return Qt.color(val);
                if (typeof val === "object") {
                    if (val.hex) return Qt.color(val.hex);
                    if (val.color) return Qt.color(val.color);
                    if (val.default && val.default.hex) return Qt.color(val.default.hex);
                }
            }
        }
        return fallback;
    }

    readonly property color cardColor: resolveColor("primary_container", ThemeBackend.surface0)
    readonly property color primaryColor: resolveColor("primary", ThemeBackend.mauve)
    readonly property color secondaryColor: resolveColor("secondary", ThemeBackend.peach)
    readonly property color tertiaryColor: resolveColor("tertiary", ThemeBackend.teal)

    // ---- snapshot data -------------------------------------------------
    property var systemRows: []
    property var hwRows: []

    property string arch: ""
    property string gpuModel: ""
    property string pkgCount: "0"
    property string pkgManager: ""
    property real memUsedGb: 0.0
    property real memTotalGb: 0.0
    property int memPercent: 0

    function refresh() {
        if (typeof SystemInfo !== "undefined") {
            SystemInfo.fetch();
        }
        infoProc.running = false;
        infoProc.running = true;
        root.rebuildRows();
        rowRefreshTimer.restart();
    }

    function rebuildRows() {
        let unk = typeof I18n !== "undefined" ? I18n.t("widgets.fetch.unknown", "Unknown") : "Unknown";
        root.systemRows = [
            mkRow("widgets.fetch.os", (typeof SystemInfo !== "undefined" && SystemInfo.osName !== "" ? SystemInfo.osName : unk) + " " + root.arch),
            mkRow("widgets.fetch.kernel", typeof SystemInfo !== "undefined" && SystemInfo.kernelVersion !== "" ? SystemInfo.kernelVersion : unk),
            mkRow("widgets.fetch.uptime", typeof SystemInfo !== "undefined" && SystemInfo.uptime !== "" ? SystemInfo.uptime : unk),
            mkRow("widgets.fetch.packages", root.pkgCount + (root.pkgManager !== "" ? " (" + root.pkgManager + ")" : "")),
            mkRow("widgets.fetch.shell", root.shellName()),
            mkRow("widgets.fetch.de", typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv !== "" ? SystemInfo.desktopEnv : unk),
            mkRow("widgets.fetch.wm", root.wmLabel())
        ];
        root.hwRows = [
            mkRow("widgets.fetch.cpu", root.cpuLabel()),
            mkRow("widgets.fetch.gpu", root.gpuValue()),
            mkRow("widgets.fetch.memory", root.memoryLabel()),
            mkRow("widgets.fetch.disk", root.diskLabel()),
            mkRow("widgets.fetch.resolution", root.resolutionLabel()),
            mkRow("widgets.fetch.theme", root.themeLabel())
        ];
    }

    function mkRow(key, value) {
        return { label: typeof I18n !== "undefined" ? I18n.t(key) : key, value: value };
    }

    function shellName() {
        let sh = typeof SystemInfo !== "undefined" ? (SystemInfo.shell || "") : "";
        let idx = sh.lastIndexOf("/");
        return idx >= 0 ? sh.substring(idx + 1) : sh;
    }

    function wmLabel() {
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) return "Hyprland (Wayland)";
        if (Quickshell.env("WAYLAND_DISPLAY")) return "Wayland";
        return typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv !== "" ? SystemInfo.desktopEnv : "—";
    }

    function cpuLabel() {
        let m = typeof SystemInfo !== "undefined" ? (SystemInfo.cpuModel || "") : "";
        if (m === "") return typeof I18n !== "undefined" ? I18n.t("widgets.fetch.unknown") : "Unknown";
        return typeof SystemInfo !== "undefined" && SystemInfo.cpuCores > 0 ? (m + " (" + SystemInfo.cpuCores + ")") : m;
    }

    function gpuValue() {
        if (root.gpuModel !== "") return root.gpuModel;
        if (typeof SystemInfo !== "undefined" && SystemInfo.gpuModel !== "") return SystemInfo.gpuModel;
        return typeof I18n !== "undefined" ? I18n.t("widgets.fetch.unknown") : "Unknown";
    }

    function memoryLabel() {
        if (root.memTotalGb <= 0) return typeof I18n !== "undefined" ? I18n.t("widgets.fetch.unknown") : "Unknown";
        let res = root.memUsedGb + " / " + root.memTotalGb + " GB";
        if (root.memPercent > 0) res += " (" + root.memPercent + "%)";
        return res;
    }

    function diskLabel() {
        if (typeof SystemInfo === "undefined" || SystemInfo.diskTotalGb <= 0) {
            return typeof I18n !== "undefined" ? I18n.t("widgets.fetch.unknown") : "Unknown";
        }
        let res = SystemInfo.diskUsedGb + " / " + SystemInfo.diskTotalGb + " GB";
        if (SystemInfo.diskPercent > 0) res += " (" + SystemInfo.diskPercent + "%)";
        return res;
    }

    function resolutionLabel() {
        let screens = Quickshell.screens || [];
        let len = screens.length !== undefined ? screens.length : (screens.count !== undefined ? screens.count : 0);
        if (len === 0) return typeof I18n !== "undefined" ? I18n.t("widgets.fetch.unknown") : "Unknown";
        let s0 = screens[0] !== undefined ? screens[0] : screens.get(0);
        if (!s0) return typeof I18n !== "undefined" ? I18n.t("widgets.fetch.unknown") : "Unknown";
        let w = s0.physicalWidth || s0.width || 0;
        let h = s0.physicalHeight || s0.height || 0;
        if (w >= 320 && h >= 240) return w + "x" + h;
        return typeof I18n !== "undefined" ? I18n.t("widgets.fetch.unknown") : "Unknown";
    }

    function themeLabel() {
        try {
            let t = typeof Config !== "undefined" ? Config.getSetting("theme", {}) : {};
            if (typeof t === "object" && t !== null) {
                if (t.matugen) return t.activePreset || "Matugen";
                if (t.name) return t.name;
                if (t.activePreset) return t.activePreset;
                if (t.currentTheme) return t.currentTheme;
            }
        } catch (e) {}
        return "Matugen";
    }

    Component.onCompleted: {
        root.refresh();
        refreshTimer.start();
    }

    Timer {
        id: refreshTimer
        interval: 60000
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: rowRefreshTimer
        interval: 250
        repeat: false
        onTriggered: root.rebuildRows()
    }

    Process {
        id: infoProc
        running: false
        command: [
            "bash", "-c",
            "arch=$(uname -m); " +
            "pkg=0; man=\"\"; " +
            "if command -v pacman >/dev/null 2>&1; then pkg=$(pacman -Q 2>/dev/null | wc -l); man=\"pacman\"; " +
            "elif command -v dpkg >/dev/null 2>&1; then pkg=$(dpkg-query -f='.\\n' -W 2>/dev/null | wc -l); man=\"dpkg\"; " +
            "elif command -v rpm >/dev/null 2>&1; then pkg=$(rpm -qa --qf '.' 2>/dev/null | wc -c); man=\"rpm\"; fi; " +
            "gpu=\"\"; " +
            "if command -v nvidia-smi >/dev/null 2>&1; then gpu=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1); fi; " +
            "[ -z \"$gpu\" ] && gpu=$(lspci 2>/dev/null | grep -iE 'vga compatible|3d controller|display controller' | head -n1 | sed -e 's/^[^ ]* //' -e 's/^[^:]*: //' -e 's/ (rev .*)$//'); " +
            "mem=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{printf \"%d %d\", t-a, t}' /proc/meminfo); " +
            "echo \"$pkg|$man|$mem|$arch|$gpu\""
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let txt = this.text ? this.text.trim() : "";
                if (txt === "") return;
                let p = txt.split("|");
                if (p.length >= 5) {
                    root.pkgCount = p[0];
                    root.pkgManager = p[1];
                    let mm = (p[2] || "").trim().split(/\s+/);
                    if (mm.length >= 2) {
                        let usedKb = parseInt(mm[0]) || 0;
                        let totKb = parseInt(mm[1]) || 0;
                        root.memTotalGb = parseFloat((totKb / 1048576).toFixed(1));
                        root.memUsedGb = parseFloat((usedKb / 1048576).toFixed(1));
                        root.memPercent = totKb > 0 ? Math.round((usedKb / totKb) * 100) : 0;
                    }
                    root.arch = p[3];
                    root.gpuModel = (p[4] || "").trim();
                }
                root.rebuildRows();
            }
        }
    }

    // ---- organic material blob (analog-clock dial language) ----
    Canvas {
        id: blobCanvas
        anchors.fill: parent
        antialiasing: true
        visible: true

        property int lobes: 10
        property real exponent: 2.75
        property real ampRatio: 0.014
        property color fillColor: root.cardColor

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onFillColorChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const cx = w / 2, cy = h / 2;
            const rx = Math.max(1, w / 2 - 1);
            const ry = Math.max(1, h / 2 - 1);
            const amp = Math.min(w, h) * blobCanvas.ampRatio;
            const n = blobCanvas.exponent;
            const steps = 420;
            ctx.beginPath();
            for (let i = 0; i <= steps; i++) {
                const a = (i / steps) * Math.PI * 2;
                const ca = Math.cos(a), sa = Math.sin(a);
                const denom = Math.pow(Math.pow(Math.abs(sa) / rx, n) + Math.pow(Math.abs(ca) / ry, n), 1 / n);
                const R = 1 / Math.max(denom, 0.0001);
                const r = R + amp * Math.cos(lobes * a);
                const x = cx + r * sa;
                const y = cy - r * ca;
                if (i === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
            }
            ctx.closePath();
            ctx.fillStyle = fillColor;
            ctx.fill();
        }
    }

    // ---- content (safely inside the blob) ----
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: root.width * 0.10
        anchors.rightMargin: root.width * 0.10
        anchors.topMargin: root.height * 0.09
        anchors.bottomMargin: root.height * 0.11
        spacing: 0

        // ---- brand header (analog-material tones) ----
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: root.s(5)

            ImageBox {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: root.s(44)
                Layout.preferredHeight: root.s(44)
                size: root.s(44)
                cornerRadius: Math.min(ThemeBackend.borderRadius, root.s(12))
                imageRadius: Math.min(ThemeBackend.borderRadius, root.s(12))
                source: typeof SystemInfo !== "undefined" && SystemInfo.avatarPath !== "" ? ("file://" + SystemInfo.avatarPath) : ""
                backgroundColor: typeof SystemInfo === "undefined" || SystemInfo.avatarPath === ""
                    ? Qt.alpha(root.secondaryColor, 0.22) : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: root.s(20)
                    color: root.secondaryColor
                    visible: typeof SystemInfo === "undefined" || SystemInfo.avatarPath === ""
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "larpantinum"
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Black
                font.pixelSize: root.s(18)
                color: root.primaryColor
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: (typeof SystemInfo !== "undefined" && SystemInfo.username !== "" ? SystemInfo.username : "user")
                    + "@" + (typeof SystemInfo !== "undefined" && SystemInfo.hostname !== "" ? SystemInfo.hostname : "host")
                    + "   ·   " + (typeof SystemInfo !== "undefined" && SystemInfo.osName !== "" ? SystemInfo.osName : (typeof I18n !== "undefined" ? I18n.t("widgets.fetch.unknown") : "Unknown"))
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(11)
                color: ThemeBackend.subtext0
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: root.s(14)
            Layout.bottomMargin: root.s(12)
            height: 1
            color: Qt.alpha(root.primaryColor, 0.28)
        }

        // ---- info rows (fastfetch-style, two columns) ----
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.s(22)

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: root.systemRows
                    delegate: InfoRow {}
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Repeater {
                    model: root.hwRows
                    delegate: InfoRow {}
                }
            }
        }
    }

    component InfoRow: Item {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        implicitHeight: Math.max(infoLabel.implicitHeight, infoValue.implicitHeight) + root.s(7)

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.s(8)

            Rectangle {
                id: infoDot
                width: root.s(4)
                height: root.s(4)
                radius: width / 2
                color: Qt.alpha(root.tertiaryColor, 0.75)
            }

            Text {
                id: infoLabel
                text: modelData.label.toUpperCase() + ":"
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(12)
                color: ThemeBackend.subtext0
                Layout.preferredWidth: root.s(78)
                elide: Text.ElideRight
            }

            Text {
                id: infoValue
                text: modelData.value
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(12)
                color: ThemeBackend.text
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Qt.alpha(root.tertiaryColor, 0.20)
            visible: index > 0
        }
    }
}