import QtQuick

// Repeatedly removes running tiles from the window. Nothing else is needed:
// the GUI thread only toggles a Loader while the render thread animates.
Window {
    id: root

    required property string mode

    width: 1200
    height: 800
    visible: true
    title: "uniformanimator_race: " + mode

    Component { id: uniformTile; UniformTile {} }
    Component { id: numberTile; NumberTile {} }
    Component { id: xTile; XTile {} }

    Loader {
        id: page
        anchors.fill: parent
        sourceComponent: Grid {
            columns: 6
            spacing: 6
            Repeater {
                model: 120
                delegate: Loader {
                    width: 190
                    height: 56
                    sourceComponent: root.mode === "number" ? numberTile
                                   : root.mode === "xanimator" ? xTile
                                   : uniformTile
                }
            }
        }
    }

    Timer {
        interval: 150
        running: true
        repeat: true
        onTriggered: page.active = !page.active
    }
}
