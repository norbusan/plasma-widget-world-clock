/*
 * World Clock - a multi time-zone clock for KDE Plasma 6.
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami
import "timezones.js" as TZ

PlasmoidItem {
    id: root

    // Config-backed state ---------------------------------------------------
    readonly property var timeZones: plasmoid.configuration.timeZones
    readonly property bool use24Hour: plasmoid.configuration.use24HourClock
    readonly property bool showSeconds: plasmoid.configuration.showSeconds
    readonly property bool showDate: plasmoid.configuration.showDate
    readonly property bool showOffset: plasmoid.configuration.showOffset
    readonly property bool showWeekday: plasmoid.configuration.showWeekday

    readonly property string fontFamily: plasmoid.configuration.fontFamily || Kirigami.Theme.defaultFont.family
    readonly property bool fontBold: plasmoid.configuration.fontBold
    // 0 means "automatic": the text scales with the widget size.
    readonly property int fixedSize: plasmoid.configuration.fontSize

    // The configured zones, minus "Local" which is always shown as the header.
    readonly property var rowZones: timeZones.filter(function (z) { return z !== "Local"; })

    readonly property string timeFormat: {
        var f = use24Hour ? "HH:mm" : "h:mm";
        if (showSeconds)
            f += ":ss";
        if (!use24Hour)
            f += " AP";
        return f;
    }

    // Always show every time at once (also when placed in a panel).
    preferredRepresentation: fullRepresentation

    // Transparent by default; ConfigurableBackground lets the user turn a
    // background on again from Configure -> Appearance.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground

    // The Plasma "time" data engine delivers the wall-clock time for each
    // requested zone (or "Local") and keeps it ticking. "Local" is always
    // connected because it drives the header.
    P5Support.DataSource {
        id: timeSource
        engine: "time"
        connectedSources: {
            var s = root.timeZones.slice();
            if (s.indexOf("Local") === -1)
                s.push("Local");
            return s;
        }
        interval: root.showSeconds ? 1000 : 60000
        intervalAlignment: root.showSeconds ? P5Support.Types.NoAlignment
                                            : P5Support.Types.AlignToMinute
    }

    // Formatting helpers ----------------------------------------------------
    function zoneData(tz) {
        return timeSource.data[tz];
    }

    // Returns a JS Date whose *local* fields equal the wall-clock time of `tz`.
    //
    // The engine's per-zone DateTime arrives in QML as an absolute instant, so
    // formatting it would always render in the system zone. Instead we take the
    // single true instant (from the Local source) and shift it by the zone's
    // UTC offset, then rebuild a local-fielded Date so Qt.format*() is correct.
    function zoneDate(tz) {
        var base = zoneData("Local");
        var d = zoneData(tz);
        if (!base || !base["DateTime"] || !d || d["Offset"] === undefined)
            return null;
        var shifted = new Date(base["DateTime"].getTime() + d["Offset"] * 1000);
        return new Date(shifted.getUTCFullYear(), shifted.getUTCMonth(), shifted.getUTCDate(),
                        shifted.getUTCHours(), shifted.getUTCMinutes(), shifted.getUTCSeconds());
    }

    function timeText(tz) {
        var d = zoneDate(tz);
        return d ? Qt.formatTime(d, root.timeFormat) : "--:--";
    }

    function dateText(tz) {
        var d = zoneDate(tz);
        return d ? d.toLocaleDateString(Qt.locale(), Locale.LongFormat) : "";
    }

    function weekdayText(tz) {
        var d = zoneDate(tz);
        return d ? Qt.formatDate(d, "ddd") : "";
    }

    function offsetText(tz) {
        var d = zoneData(tz);
        if (!d || d["Offset"] === undefined)
            return "";
        var mins = Math.round(d["Offset"] / 60);
        var sign = mins < 0 ? "-" : "+";
        mins = Math.abs(mins);
        var h = Math.floor(mins / 60);
        var m = mins % 60;
        return "UTC" + sign + (h < 10 ? "0" + h : h) + ":" + (m < 10 ? "0" + m : m);
    }

    // Representations -------------------------------------------------------
    compactRepresentation: MouseArea {
        Layout.minimumWidth: compactRow.implicitWidth
        Layout.minimumHeight: compactRow.implicitHeight
        onClicked: root.expanded = !root.expanded

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: "clock"
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
            }
            PlasmaComponents3.Label {
                text: root.timeText("Local")
                font.family: root.fontFamily
                font.bold: root.fontBold
            }
        }
    }

    fullRepresentation: Item {
        id: fullRep

        Layout.minimumWidth: Kirigami.Units.gridUnit * 8
        Layout.minimumHeight: Kirigami.Units.gridUnit * 6
        Layout.preferredWidth: Kirigami.Units.gridUnit * 12
        Layout.preferredHeight: Kirigami.Units.gridUnit * 10

        // Automatic sizing: split the height into slots. The header is worth
        // ~2 rows; each zone row is worth 1. Scale text to those slots.
        readonly property int rowCount: root.rowZones.length
        readonly property real slot: height / ((rowCount + 2.4) * 1.35)

        function rowPx() {
            return root.fixedSize > 0 ? root.fixedSize : Math.max(9, Math.round(slot));
        }
        function headerPx() {
            return root.fixedSize > 0 ? Math.round(root.fixedSize * 1.7)
                                      : Math.max(14, Math.round(slot * 2.0));
        }
        function smallPx() {
            return Math.max(7, Math.round(rowPx() * 0.7));
        }
        // Middle info (offset/weekday) sizing: 2/3 of the row when only one
        // line is shown, a bit under 1/2 when both are stacked.
        function midOnePx() {
            return Math.max(7, Math.round(rowPx() * 0.66));
        }
        function midBothPx() {
            return Math.max(7, Math.round(rowPx() * 0.45));
        }

        // Width of the widest zone code, so every code column is the same
        // width and the middle info (offset/weekday) starts at the same x on
        // every row instead of wobbling with the code length.
        FontMetrics {
            id: codeFm
            font.family: root.fontFamily
            font.bold: true
            font.pixelSize: fullRep.rowPx()
        }
        readonly property real codeColWidth: {
            // Reference the font bits so the binding re-evaluates when they change.
            var f = codeFm.font.pixelSize + codeFm.font.family.length + (codeFm.font.bold ? 1 : 0);
            var w = 0;
            for (var i = 0; i < root.rowZones.length; i++)
                w = Math.max(w, codeFm.advanceWidth(TZ.code(root.rowZones[i])));
            return w;
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            // --- Header: local time, centered -----------------------------
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.timeText("Local")
                    font.family: root.fontFamily
                    font.bold: root.fontBold
                    font.pixelSize: fullRep.headerPx()
                }
                PlasmaComponents3.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: root.showDate ? dateText("Local") : i18nc("label for the local time zone", "Local time")
                    opacity: 0.7
                    font.family: root.fontFamily
                    font.pixelSize: fullRep.smallPx()
                    elide: Text.ElideRight
                }
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                visible: root.rowZones.length > 0
            }

            // --- One line per configured zone: code + time ----------------
            Repeater {
                model: root.rowZones

                delegate: RowLayout {
                    required property string modelData

                    // Both info lines requested -> stacked; exactly one -> a
                    // single line whose baseline aligns with the code/time.
                    readonly property bool bothInfo: root.showOffset && root.showWeekday
                    readonly property bool anyInfo: root.showOffset || root.showWeekday

                    Layout.fillWidth: true
                    spacing: Kirigami.Units.largeSpacing

                    PlasmaComponents3.Label {
                        text: TZ.code(modelData)
                        font.family: root.fontFamily
                        font.bold: true
                        font.pixelSize: fullRep.rowPx()
                        Layout.minimumWidth: fullRep.codeColWidth
                        Layout.preferredWidth: fullRep.codeColWidth
                        Layout.alignment: Qt.AlignBaseline
                    }

                    // Exactly one of weekday/offset: single line sharing the
                    // code's baseline instead of being centred in the row.
                    PlasmaComponents3.Label {
                        visible: anyInfo && !bothInfo
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignBaseline
                        text: root.showWeekday ? root.weekdayText(modelData)
                                               : root.offsetText(modelData)
                        opacity: 0.7
                        font.family: root.fontFamily
                        font.pixelSize: fullRep.midOnePx()
                        elide: Text.ElideRight
                    }

                    // Both weekday and offset: stacked, centred in the row.
                    ColumnLayout {
                        visible: bothInfo
                        Layout.fillWidth: true
                        spacing: 0

                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: root.weekdayText(modelData)
                            opacity: 0.7
                            font.family: root.fontFamily
                            font.pixelSize: fullRep.midBothPx()
                            elide: Text.ElideRight
                        }
                        PlasmaComponents3.Label {
                            Layout.fillWidth: true
                            text: root.offsetText(modelData)
                            opacity: 0.7
                            font.family: root.fontFamily
                            font.pixelSize: fullRep.midBothPx()
                            elide: Text.ElideRight
                        }
                    }

                    // Neither: filler so the time stays right-aligned.
                    Item {
                        visible: !anyInfo
                        Layout.fillWidth: true
                    }

                    PlasmaComponents3.Label {
                        text: root.timeText(modelData)
                        font.family: root.fontFamily
                        font.bold: root.fontBold
                        font.pixelSize: fullRep.rowPx()
                        Layout.alignment: Qt.AlignRight | Qt.AlignBaseline
                    }
                }
            }

            // Absorb spare vertical space so rows sit just under the header.
            Item { Layout.fillHeight: true }
        }
    }
}
