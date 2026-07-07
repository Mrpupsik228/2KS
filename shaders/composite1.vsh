#version 120

#include "/lib/properties.glsl"

uniform float frameTimeCounter;
uniform vec3 cameraPosition, previousCameraPosition;

varying vec4 color;
varying vec2 coord0;
varying vec2 shakeOffset;
varying float tiltValue;

void main() {
    gl_Position = ftransform();
    color = gl_Color;
    coord0 = (gl_MultiTexCoord0).xy;

    float power = (1.0 - 1.0 / exp(distance(cameraPosition, previousCameraPosition) * 2.3)) * 0.5;
    vec2 offset = vec2(0.0);

    offset.x += sin(frameTimeCounter * 0.3 * SHAKE_FLOW_SPEED) * 0.04 * SHAKE_FLOW_STRENGTH;
    float microA = sin(frameTimeCounter * 23.0 * SHAKE_MICRO_SPEED) * sin(frameTimeCounter * 9.0 * SHAKE_MICRO_SPEED);
    float microB = max(sin(frameTimeCounter * 0.21 * SHAKE_MICRO_SPEED) * sin(frameTimeCounter * 12.0 * SHAKE_MICRO_SPEED) * sin(frameTimeCounter * 0.1 * SHAKE_MICRO_SPEED) * 20.0, 0.0);
    offset.x += clamp(microA * microB * 1.3 - 0.3, -1.0, 1.0) * 0.001 * SHAKE_MICRO_STRENGTH;
    float rareX = sin(frameTimeCounter * 7.0 * SHAKE_MICRO_SPEED) * cos(frameTimeCounter * 2.0 * SHAKE_MICRO_SPEED) * sin(frameTimeCounter * 0.9 * SHAKE_MICRO_SPEED + 0.32);
    offset.x += (rareX * rareX) * 0.005 * (1.0 + power * 2.0) * SHAKE_MICRO_STRENGTH;
    offset.x += clamp(sin(frameTimeCounter * 5.21 + 58.93) * cos(frameTimeCounter * 7.6843 - 12.6344) + cos(frameTimeCounter * 0.312 * SHAKE_DROP_FREQUENCY + 0.324) * 4.0, -1.0, 1.0) * 0.01 * (1.0 + power * 3.5) * SHAKE_DROP_STRENGTH;

    offset.y += sin(frameTimeCounter * 0.32 * SHAKE_FLOW_SPEED + 12.291) * 0.04 * (1.0 + power) * SHAKE_FLOW_STRENGTH;
    float microC = sin(frameTimeCounter * 21.3 * SHAKE_MICRO_SPEED - 0.324) * sin(frameTimeCounter * 7.6 * SHAKE_MICRO_SPEED - 2.242);
    float microD = max(sin(frameTimeCounter * 0.2834 * SHAKE_MICRO_SPEED + 0.23) * sin(frameTimeCounter * 11.23 * SHAKE_MICRO_SPEED + 3.42) * sin(frameTimeCounter * 0.132 * SHAKE_MICRO_SPEED - 0.324) * 20.0, 0.0);
    offset.y += clamp(microC * microD * 1.3 - 0.3, -1.0, 1.0) * 0.001 * SHAKE_MICRO_STRENGTH;
    float rareY = sin(frameTimeCounter * 4.3 + 32.24) * cos(frameTimeCounter * 8.392 - 0.324) + cos(frameTimeCounter * 2.392 - 31.324);
    offset.y += clamp(rareY * rareY * rareY, -1.0, 1.0) * 0.01 * (1.0 + power * 3.5) * SHAKE_DROP_STRENGTH;

    vec2 miniShake = vec2(sin(frameTimeCounter * 78.0 * (1.1 - power)), cos(frameTimeCounter * 86.0 * (1.1 - power))) * 0.01 * (power * power);
    offset += miniShake;
    offset *= GLOBAL_SHAKE_STRENGTH;
    shakeOffset = offset;

    float tiltAngle = 0.0;
    tiltAngle += floor(sin(frameTimeCounter * 0.5 * TILT_FLOW_SPEED) * 10.0) / 10.0 * 0.2 * GLOBAL_SHAKE_STRENGTH * TILT_STRENGTH * TILT_FLOW_STRENGTH + power;
    tiltAngle += sin(frameTimeCounter * 0.32 * TILT_FLOW_SPEED + 3.14) * 0.2 * GLOBAL_SHAKE_STRENGTH * TILT_FLOW_STRENGTH * TILT_STRENGTH;
    tiltValue = tiltAngle * 0.1;
}
