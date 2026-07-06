/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 */
import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    // Two-way bound to the KConfigXT keys of the same name.
    property alias cfg_use24HourClock: use24Hour.checked
    property alias cfg_showSeconds: showSeconds.checked
    property alias cfg_showDate: showDate.checked
    property alias cfg_showOffset: showOffset.checked
    property alias cfg_showWeekday: showWeekday.checked
    property alias cfg_fontBold: fontBold.checked
    property alias cfg_fontSize: fontSize.value
    // Not an alias: the combo maps "Default" <-> "".
    property string cfg_fontFamily: ""

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.CheckBox {
            id: use24Hour
            Kirigami.FormData.label: i18n("Clock:")
            text: i18n("Use 24-hour format")
        }

        QQC2.CheckBox {
            id: showSeconds
            text: i18n("Show seconds")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showDate
            Kirigami.FormData.label: i18n("Rows:")
            text: i18n("Show date")
        }

        QQC2.CheckBox {
            id: showOffset
            text: i18n("Show UTC offset")
        }

        QQC2.CheckBox {
            id: showWeekday
            text: i18n("Show weekday")
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.ComboBox {
            id: fontFamily
            Kirigami.FormData.label: i18n("Font:")
            // First entry is the theme default (stored as an empty string).
            model: [i18n("Default")].concat(Qt.fontFamilies())
            onActivated: page.cfg_fontFamily = (currentIndex === 0 ? "" : currentText)

            function syncFromConfig() {
                var idx = page.cfg_fontFamily === "" ? 0 : find(page.cfg_fontFamily);
                currentIndex = idx < 0 ? 0 : idx;
            }
            Component.onCompleted: syncFromConfig()
            Connections {
                target: page
                function onCfg_fontFamilyChanged() { fontFamily.syncFromConfig(); }
            }
        }

        QQC2.SpinBox {
            id: fontSize
            Kirigami.FormData.label: i18n("Font size:")
            from: 0
            to: 200
            // 0 renders as "Automatic": text scales with the widget size.
            textFromValue: function(value) {
                return value === 0 ? i18n("Automatic") : value + i18n(" px");
            }
            valueFromText: function(text) {
                return text === i18n("Automatic") ? 0 : parseInt(text) || 0;
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: i18n("“Automatic” scales the text to the widget size — resize the widget to change it.")
            opacity: 0.7
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
        }

        QQC2.CheckBox {
            id: fontBold
            text: i18n("Bold time")
        }
    }
}
