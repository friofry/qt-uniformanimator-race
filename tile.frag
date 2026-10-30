#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float phase;
};

void main()
{
    float band = 1.0 - clamp(abs(qt_TexCoord0.x - phase) * 4.0, 0.0, 1.0);
    fragColor = vec4(vec3(0.2 + 0.6 * band), 1.0) * qt_Opacity;
}
