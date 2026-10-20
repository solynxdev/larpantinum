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
    // the analog's indicatorColor: tertiary with a secondary fallback, so the
    // accents land on the same periwinkle the clock's indicator uses
    readonly property color tertiaryColor: resolveColor("tertiary", resolveColor("secondary", ThemeBackend.peach))

    // ---- distro identity (logo + brand colour, fastfetch-style) ----
    property string osId: ""

    function distroId() {
        return root.osId.toLowerCase();
    }

    function brandColor() {
        switch (root.distroId()) {
            case "arch": return "#1793d1";
            case "fedora": return "#51a2da";
            case "ubuntu": return "#e95420";
            case "debian": return "#d70a53";
            case "nixos": return "#7ebae4";
            case "linuxmint": return "#86be43";
            case "manjaro": return "#35bf5c";
            case "opensuse*": case "opensuse-tumbleweed": case "opensuse-leap": return "#73ba25";
            default: return root.primaryColor;
        }
    }

    // fastfetch-style small logo art, drawn in the distro's brand colour.
    // Backslashes are doubled so the source stays valid QML and ASCII-clean.
    // fastfetch-style small logo art, drawn in the distro's brand colour.
    // Backslashes are doubled so the source stays valid QML and ASCII-clean.
    // fastfetch-style small logo art, drawn in the distro's brand colour.
    // One array element per line; backslashes doubled so the source stays
    // valid QML and free of non-ASCII bytes.
    function logoLines() {
        switch (root.distroId()) {
            case "arch":
                return ["        /\\       ",
                        "       /  \\      ",
                        "      /    \\     ",
                        "     /      \\    ",
                        "    /   ,,   \\   ",
                        "   /   |  |   \\  ",
                        "  /_-''    ''-\\_ "];
            case "fedora":
                return ["      _____       ",
                        "     /   __)\\     ",
                        "     |  /  \\ \\    ",
                        "  ___|  |__/ /    ",
                        " / (_    _)_/     ",
                        "/ /  |  |         ",
                        "\\ \\__/  |         ",
                        " \\(___/"];
            case "ubuntu":
                return ["         _         ",
                        "     ---(_)        ",
                        " _/  ---  \\       ",
                        "(_) |   |          ",
                        "  \\  --- _/        ",
                        "     ---(_)        "];
            case "debian":
                return ["      _____       ",
                        "     /  __ \\      ",
                        "     | /  \\/      ",
                        "     | /\\__/\\      ",
                        "     |\\___/\\      ",
                        "    |/     \\     ",
                        "     \\_____  \\    ",
                        "           \\(__) "];
            case "nixos":
                return ["        /\\  \\     ",
                        "       /  \\  \\    ",
                        "      / /\\ \\  \\   ",
                        "     / /  \\ \\  \\  ",
                        "    / /____\\ \\  \\ ",
                        "   /__________\\  \\ ",
                        "   \\__________/   "];
            default: return [];
        }
    }

    function hasLogo() {
        return root.logoLines().length > 0;
    }

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
        osReleaseFile.reload();
        infoProc.running = false;
        infoProc.running = true;
        root.rebuildRows();
        rowRefreshTimer.restart();
    }

    function rebuildRows() {
        let unk = typeof I18n !== "undefined" ? I18n.t("widgets.fetch.unknown", "Unknown") : "Unknown";
        let os = (typeof SystemInfo !== "undefined" && SystemInfo.osName !== "" ? SystemInfo.osName : unk);
        root.systemRows = [
            mkRow("os", "widgets.fetch.os", os + " " + root.arch),
            mkRow("host", "widgets.fetch.host", root.hostLabel()),
            mkRow("kernel", "widgets.fetch.kernel", typeof SystemInfo !== "undefined" && SystemInfo.kernelVersion !== "" ? SystemInfo.kernelVersion : unk),
            mkRow("uptime", "widgets.fetch.uptime", typeof SystemInfo !== "undefined" && SystemInfo.uptime !== "" ? SystemInfo.uptime : unk),
            mkRow("pkg", "widgets.fetch.packages", root.pkgCount + (root.pkgManager !== "" ? " (" + root.pkgManager + ")" : "")),
            mkRow("shell", "widgets.fetch.shell", root.shellName()),
            mkRow("de", "widgets.fetch.de", typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv !== "" ? SystemInfo.desktopEnv : unk),
            mkRow("wm", "widgets.fetch.wm", root.wmLabel())
        ];
        root.hwRows = [
            mkRow("cpu", "widgets.fetch.cpu", root.cpuLabel()),
            mkRow("gpu", "widgets.fetch.gpu", root.gpuValue()),
            mkRow("mem", "widgets.fetch.memory", root.memoryLabel()),
            mkRow("disk", "widgets.fetch.disk", root.diskLabel()),
            mkRow("res", "widgets.fetch.resolution", root.resolutionLabel()),
            mkRow("theme", "widgets.fetch.theme", root.themeLabel())
        ];
    }

    function mkRow(icon, key, value) {
        return {
            icon: icon,
            label: typeof I18n !== "undefined" ? I18n.t(key) : key,
            value: value
        };
    }

    function hostLabel() {
        let u = typeof SystemInfo !== "undefined" && SystemInfo.username !== "" ? SystemInfo.username : "user";
        let h = typeof SystemInfo !== "undefined" && SystemInfo.hostname !== "" ? SystemInfo.hostname : "host";
        return u + "@" + h;
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

    // copy a row value to the clipboard, then flash the row's icon to a tick
    function copyValue(value) {
        copyProc.command = ["wl-copy", "--", value];
        copyProc.running = false;
        copyProc.running = true;
    }

    // nerd-font glyph per row key (Font Awesome range, same icon language
    // the shell's menus already use)
    // nerd-font glyph per row key (Font Awesome range, same icon language
    // the shell's menus already use). Escaped so the source stays ASCII.
    function glyphFor(key) {
        switch (key) {
            case "os": return "\uf17c";
            case "host": return "\uf233";
            case "kernel": return "\uf109";
            case "uptime": return "\uf017";
            case "pkg": return "\uf1b3";
            case "shell": return "\uf120";
            case "de": return "\uf108";
            case "wm": return "\uf009";
            case "cpu": return "\uf2db";
            case "gpu": return "\uf2dc";
            case "mem": return "\uf538";
            case "disk": return "\uf0a0";
            case "res": return "\uf5fd";
            case "theme": return "\uf53f";
            default:         return "\uf128";
        }
    }

    function tickGlyph() {
        return "\uf00c";
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

    // /etc/os-release -> ID (drives which logo + brand colour we draw)
    FileView {
        id: osReleaseFile
        path: "/etc/os-release"
        onLoaded: {
            let txt = text();
            if (!txt) return;
            let lines = txt.split("\n");
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].startsWith("ID=")) {
                    root.osId = lines[i].split("=")[1].replace(/"/g, "").trim();
                    break;
                }
            }
            root.rebuildRows();
        }
    }

    Process {
        id: copyProc
        running: false
        command: ["wl-copy"]
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

    // ---- card: rounded rectangle with a gently undulating outline ----
    // (the redactor-selection silhouette, not a blob)
    Canvas {
        id: cardCanvas
        anchors.fill: parent
        antialiasing: true

        property real corner: Math.min(ThemeBackend.borderRadius * 1.6, Math.min(width, height) * 0.20)
        property real amp: Math.min(width, height) * 0.020
        property int lobes: 14
        property color fillColor: root.cardColor
        property color edgeColor: Qt.alpha(root.primaryColor, 0.26)

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onFillColorChanged: requestPaint()
        onEdgeColorChanged: requestPaint()

        // point + outward normal on a rounded rect, by arc-length fraction s
        function edgePoint(s, pad, w, h, r, Lx, Ly, La, P) {
            let d = s * P;
            if (d < Lx) return [pad + r + d, pad, 0, -1];
            d -= Lx;
            if (d < La) { let a = -Math.PI / 2 + d / r; return [pad + w - r + r * Math.cos(a), pad + r + r * Math.sin(a), Math.cos(a), Math.sin(a)]; }
            d -= La;
            if (d < Ly) return [pad + w, pad + r + d, 1, 0];
            d -= Ly;
            if (d < La) { let a = d / r; return [pad + w - r + r * Math.cos(a), pad + h - r + r * Math.sin(a), Math.cos(a), Math.sin(a)]; }
            d -= La;
            if (d < Lx) return [pad + w - r - d, pad + h, 0, 1];
            d -= Lx;
            if (d < La) { let a = Math.PI / 2 + d / r; return [pad + r + r * Math.cos(a), pad + h - r + r * Math.sin(a), Math.cos(a), Math.sin(a)]; }
            d -= La;
            if (d < Ly) return [pad, pad + h - r - d, -1, 0];
            d -= Ly;
            let a = Math.PI + d / r;
            return [pad + r + r * Math.cos(a), pad + r + r * Math.sin(a), Math.cos(a), Math.sin(a)];
        }

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const pad = cardCanvas.amp + 1;
            const w = width - 2 * pad, h = height - 2 * pad;
            if (w <= 4 || h <= 4) return;
            const r = Math.min(cardCanvas.corner, Math.min(w, h) / 2);
            const Lx = w - 2 * r, Ly = h - 2 * r, La = Math.PI * r / 2;
            const P = 2 * Lx + 2 * Ly + 4 * La;
            const lobes = cardCanvas.lobes, amp = cardCanvas.amp;
            const steps = 480;
            ctx.beginPath();
            for (let i = 0; i <= steps; i++) {
                const sv = i / steps;
                const p = cardCanvas.edgePoint(sv, pad, w, h, r, Lx, Ly, La, P);
                const off = amp * Math.cos(lobes * 2 * Math.PI * sv);
                const x = p[0] + p[2] * off, y = p[1] + p[3] * off;
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.closePath();
            ctx.fillStyle = cardCanvas.fillColor;
            ctx.fill();
            ctx.lineWidth = 1;
            ctx.strokeStyle = cardCanvas.edgeColor;
            ctx.stroke();
        }
    }

    // ---- content ----
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.width * 0.055
        anchors.rightMargin: root.width * 0.055
        anchors.topMargin: root.height * 0.07
        anchors.bottomMargin: root.height * 0.07
        spacing: root.width * 0.045

        // ---- OS logo (fastfetch small-logo art, in the distro's brand colour) ----
        Item {
            visible: root.hasLogo()
            Layout.preferredWidth: logoCol.implicitWidth
            Layout.preferredHeight: logoCol.implicitHeight
            Layout.alignment: Qt.AlignVCenter

            Column {
                id: logoCol
                spacing: 0
                Repeater {
                    model: root.logoLines()
                    delegate: Text {
                        required property var modelData
                        text: modelData
                        font.family: "Iosevka Nerd Font"
                        font.pixelSize: Math.max(root.s(9), Math.min(root.width, root.height) * 0.055)
                        color: root.brandColor()
                        lineHeight: 1.0
                        renderType: Text.NativeRender
                    }
                }
            }
        }

        // ---- info column ----
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(8)

                Text {
                    text: root.hostLabel()
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Black
                    font.pixelSize: root.s(15)
                    color: root.primaryColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Text {
                    text: typeof SystemInfo !== "undefined" && SystemInfo.osName !== "" ? SystemInfo.osName : ""
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(11)
                    color: ThemeBackend.subtext0
                    elide: Text.ElideRight
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: root.s(7)
                Layout.bottomMargin: root.s(6)
                height: 1
                color: Qt.alpha(root.primaryColor, 0.28)
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Repeater {
                    model: root.systemRows
                    delegate: InfoRow {}
                }
                Repeater {
                    model: root.hwRows
                    delegate: InfoRow {}
                }
            }
        }
    }

    component InfoRow: Item {
        id: rowRoot

        required property var modelData
        required property int index

        Layout.fillWidth: true
        Layout.preferredHeight: s(24)

        function s(v) { return root.s(v); }

        property bool copied: false

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: -root.s(6)
            anchors.rightMargin: -root.s(6)
            radius: ThemeBackend.borderRadius
            color: rowMouse.containsMouse ? Qt.alpha(root.secondaryColor, 0.16) : "transparent"
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.s(8)

            Text {
                text: rowRoot.copied ? root.tickGlyph() : root.glyphFor(rowRoot.modelData.icon)
                font.family: "Iosevka Nerd Font"
                font.pixelSize: root.s(13)
                color: rowRoot.copied ? root.primaryColor : Qt.alpha(root.brandColor(), 0.95)
                Layout.preferredWidth: root.s(16)
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: rowRoot.modelData.label
                font.family: ThemeBackend.fontFamily
                font.weight: Font.DemiBold
                font.pixelSize: root.s(12)
                color: ThemeBackend.subtext0
                Layout.preferredWidth: root.s(74)
                elide: Text.ElideRight
            }

            Text {
                text: rowRoot.modelData.value
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(12)
                color: ThemeBackend.text
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.copyValue(rowRoot.modelData.value);
                rowRoot.copied = true;
                copyFlash.restart();
            }
        }

        Timer {
            id: copyFlash
            interval: 1200
            onTriggered: rowRoot.copied = false
        }
    }
}
