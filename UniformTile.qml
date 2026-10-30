import QtQuick

ShaderEffect {
    id: tile

    property real phase: 0

    fragmentShader: "qrc:/shaders/tile.frag.qsb"

    UniformAnimator {
        target: tile
        uniform: "phase"
        from: 0
        to: 1
        duration: 1000
        loops: Animation.Infinite
        running: true
    }
}
