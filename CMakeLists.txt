cmake_minimum_required(VERSION 3.21)
project(uniformanimator_race LANGUAGES CXX)

find_package(Qt6 6.5 REQUIRED COMPONENTS Gui Qml Quick ShaderTools)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(uniformanimator_race main.cpp)

qt_add_qml_module(uniformanimator_race
    URI rig
    VERSION 1.0
    QML_FILES Main.qml UniformTile.qml NumberTile.qml XTile.qml
)

qt_add_shaders(uniformanimator_race "shaders"
    PREFIX "/shaders"
    FILES tile.frag
)

target_link_libraries(uniformanimator_race PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick)
