import QtQuick

// Control: same shader, the phase is animated on the GUI thread.
ShaderEffect {
    id: tile

    property real phase: 0

    fragmentShader: "qrc:/shaders/tile.frag.qsb"

    NumberAnimation on phase {
        from: 0
        to: 1
        duration: 1000
        loops: Animation.Infinite
        running: true
    }
}
