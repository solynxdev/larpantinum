import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

Item {
    id: root
    visible: false
    focus: true
    enabled: visible

    function s(val) {
        return Scaler.s(val);
    }

    property real targetMasterWidth: root.s(760)
    property real targetMasterHeight: root.s(500)
    implicitWidth: targetMasterWidth
    implicitHeight: targetMasterHeight
    width: targetMasterWidth
    height: targetMasterHeight

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

    // ---- intro / exit ----
    property real openProgress: 0.0
    property var exitCallback: null

    Behavior on openProgress {
        enabled: root.visible
        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
    }

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
        let unk = I18n.t("widgets.fetch.unknown", "Unknown");
        root.systemRows = [
            mkRow("widgets.fetch.os", (SystemInfo.osName !== "" ? SystemInfo.osName : unk) + " " + root.arch),
            mkRow("widgets.fetch.kernel", SystemInfo.kernelVersion !== "" ? SystemInfo.kernelVersion : unk),
            mkRow("widgets.fetch.uptime", SystemInfo.uptime !== "" ? SystemInfo.uptime : unk),
            mkRow("widgets.fetch.packages", root.pkgCount + (root.pkgManager !== "" ? " (" + root.pkgManager + ")" : "")),
            mkRow("widgets.fetch.shell", root.shellName()),
            mkRow("widgets.fetch.de", SystemInfo.desktopEnv !== "" ? SystemInfo.desktopEnv : unk),
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
        return { label: I18n.t(key), value: value };
    }

    function shellName() {
        let sh = SystemInfo.shell || "";
        let idx = sh.lastIndexOf("/");
        return idx >= 0 ? sh.substring(idx + 1) : sh;
    }

    function wmLabel() {
        if (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")) return "Hyprland (Wayland)";
        if (Quickshell.env("WAYLAND_DISPLAY")) return "Wayland";
        return SystemInfo.desktopEnv !== "" ? SystemInfo.desktopEnv : "—";
    }

    function cpuLabel() {
        let m = SystemInfo.cpuModel || "";
        if (m === "") return I18n.t("widgets.fetch.unknown");
        return SystemInfo.cpuCores > 0 ? (m + " (" + SystemInfo.cpuCores + ")") : m;
    }

    function gpuValue() {
        if (root.gpuModel !== "") return root.gpuModel;
        if (SystemInfo.gpuModel !== "") return SystemInfo.gpuModel;
        return I18n.t("widgets.fetch.unknown");
    }

    function memoryLabel() {
        if (root.memTotalGb <= 0) return I18n.t("widgets.fetch.unknown");
        let res = root.memUsedGb + " / " + root.memTotalGb + " GB";
        if (root.memPercent > 0) res += " (" + root.memPercent + "%)";
        return res;
    }

    function diskLabel() {
        if (SystemInfo.diskTotalGb <= 0) return I18n.t("widgets.fetch.unknown");
        let res = SystemInfo.diskUsedGb + " / " + SystemInfo.diskTotalGb + " GB";
        if (SystemInfo.diskPercent > 0) res += " (" + SystemInfo.diskPercent + "%)";
        return res;
    }

    function resolutionLabel() {
        let screens = Quickshell.screens || [];
        let len = screens.length !== undefined ? screens.length : (screens.count !== undefined ? screens.count : 0);
        if (len === 0) return I18n.t("widgets.fetch.unknown");
        let s0 = screens[0] !== undefined ? screens[0] : screens.get(0);
        if (!s0) return I18n.t("widgets.fetch.unknown");
        let w = s0.physicalWidth || s0.width || 0;
        let h = s0.physicalHeight || s0.height || 0;
        if (w >= 320 && h >= 240) return w + "x" + h;
        return I18n.t("widgets.fetch.unknown");
    }

    function themeLabel() {
        try {
            let t = Config.getSetting("theme", {});
            if (typeof t === "object" && t !== null) {
                if (t.matugen) return t.activePreset || "Matugen";
                if (t.name) return t.name;
                if (t.activePreset) return t.activePreset;
                if (t.currentTheme) return t.currentTheme;
            }
        } catch (e) {}
        return "Matugen";
    }

    function startExit(onFinished) {
        root.exitCallback = onFinished;
        exitAnim.restart();
    }

    onVisibleChanged: {
        if (visible) {
            Qt.callLater(forceActiveFocus);
            root.refresh();
            root.openProgress = 0;
            introTimer.restart();
        }
    }

    Timer {
        id: introTimer
        interval: 16
        repeat: false
        onTriggered: root.openProgress = 1
    }

    Timer {
        id: rowRefreshTimer
        interval: 250
        repeat: false
        onTriggered: root.rebuildRows()
    }

    SequentialAnimation {
        id: exitAnim
        NumberAnimation {
            target: root
            property: "openProgress"
            to: 0
            duration: 170
            easing.type: Easing.OutCubic
        }
        ScriptAction {
            script: {
                let cb = root.exitCallback;
                root.exitCallback = null;
                if (cb) cb();
            }
        }
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

    // ---- panel ----
    Rectangle {
        id: panel
        anchors.fill: parent
        color: Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.95)
        radius: Math.min(ThemeBackend.borderRadius, root.s(28))
        border.width: 0
        clip: true
        opacity: root.openProgress
        transform: Translate { y: root.s(10) * (1.0 - root.openProgress) }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.s(22)
            spacing: 0

            // ---- brand header (lock-like) ----
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: root.s(6)

                ImageBox {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: root.s(56)
                    Layout.preferredHeight: root.s(56)
                    size: root.s(56)
                    cornerRadius: root.s(16)
                    imageRadius: root.s(16)
                    source: SystemInfo.avatarPath !== "" ? ("file://" + SystemInfo.avatarPath) : ""
                    backgroundColor: SystemInfo.avatarPath === "" ? ThemeBackend.surface1 : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: root.s(26)
                        color: ThemeBackend.text
                        visible: SystemInfo.avatarPath === ""
                    }
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "larpantinum"
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Black
                    font.pixelSize: root.s(24)
                    color: ThemeBackend.text
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: (SystemInfo.username !== "" ? SystemInfo.username : "user")
                        + "@" + (SystemInfo.hostname !== "" ? SystemInfo.hostname : "host")
                        + "   ·   " + (SystemInfo.osName !== "" ? SystemInfo.osName : I18n.t("widgets.fetch.unknown"))
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(12)
                    color: ThemeBackend.subtext0
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: root.s(20)
                Layout.bottomMargin: root.s(16)
                height: 1
                color: Qt.alpha(ThemeBackend.surface0, 0.55)
            }

            // ---- info rows (fastfetch-style) ----
            RowLayout {
                Layout.fillWidth: true
                spacing: root.s(36)

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: root.systemRows

                        Item {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: Math.max(fetchLabel.implicitHeight, fetchValue.implicitHeight) + root.s(9)

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.s(12)

                                Text {
                                    id: fetchLabel
                                    text: modelData.label.toUpperCase() + ":"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(12)
                                    color: ThemeBackend.subtext0
                                    Layout.preferredWidth: root.s(92)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: fetchValue
                                    text: modelData.value
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(12)
                                    color: ThemeBackend.text
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Qt.alpha(ThemeBackend.surface0, 0.55)
                                visible: index < root.systemRows.length - 1
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Repeater {
                        model: root.hwRows

                        Item {
                            required property var modelData
                            required property int index
                            Layout.fillWidth: true
                            implicitHeight: Math.max(hwLabel.implicitHeight, hwValue.implicitHeight) + root.s(9)

                            RowLayout {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: root.s(12)

                                Text {
                                    id: hwLabel
                                    text: modelData.label.toUpperCase() + ":"
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(12)
                                    color: ThemeBackend.subtext0
                                    Layout.preferredWidth: root.s(92)
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: hwValue
                                    text: modelData.value
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: root.s(12)
                                    color: ThemeBackend.text
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 1
                                color: Qt.alpha(ThemeBackend.surface0, 0.55)
                                visible: index < root.hwRows.length - 1
                            }
                        }
                    }
                }
            }
        }
    }
}