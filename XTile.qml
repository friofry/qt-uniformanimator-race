import QtQuick

// Control: a render thread animator that does not go through ShaderEffect.
ShaderEffect {
    id: tile

    property real phase: 0.5

    fragmentShader: "qrc:/shaders/tile.frag.qsb"

    XAnimator {
        target: tile
        from: 0
        to: 2
        duration: 1000
        loops: Animation.Infinite
        running: true
    }
}
