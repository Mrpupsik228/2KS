// Base post-processing layer
#version 120

#include "/lib/properties.glsl"
#include "/lib/noise.glsl"

const bool colortex0MipmapEnabled = true;
uniform sampler2D texture, depthtex0;
uniform float viewWidth, viewHeight;
uniform float frameTimeCounter, aspectRatio;
uniform vec3 previousCameraPosition, cameraPosition;
uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView, gbufferPreviousProjection;

varying vec4 color;
varying vec2 coord0;
varying vec2 shakeOffset;
varying float tiltValue;

#ifdef MOTION_BLUR_ENABLED
    vec3 MotionBlur(in vec3 color, in vec2 texcoord, in float z, in float dither) {
        const float DEPTH_THRESHOLD = 0.66;
        if (z <= DEPTH_THRESHOLD) return color;

        vec4 currentPosition = vec4(texcoord, z, 1.0) * 2.0 - 1.0;
        vec4 viewPos = gbufferProjectionInverse * currentPosition;
        viewPos = gbufferModelViewInverse * viewPos;
        viewPos /= viewPos.w;

        vec3 cameraOffset = cameraPosition - previousCameraPosition;
        vec4 previousPosition = gbufferPreviousProjection * gbufferPreviousModelView * (viewPos + vec4(cameraOffset, 0.0));
        previousPosition /= previousPosition.w;

        vec2 velocity = (currentPosition - previousPosition).xy;
        velocity = velocity / (1.0 + length(velocity)) * MOTION_BLUR_STRENGTH;

        if (dot(velocity, velocity) < 0.000001) return color;

        vec3 mblur = vec3(0.0);
        float totalWeight = 0.0;
        float invSamples = 1.0 / float(MOTION_BLUR_SAMPLES - 1);

        for (int i = 0; i < MOTION_BLUR_SAMPLES; i++) {
            float t = (float(i) + dither) * invSamples;
            vec2 offset = velocity * (t - 0.5);
            vec3 sampleColor = texture2D(texture, texcoord + offset).rgb;

            float noiseValue = fract(dither * 100.0 + float(i) * 0.6180339);
            float weight = mix(0.5, 1.0, noiseValue);

            mblur += sampleColor * weight;
            totalWeight += weight;
        }

        return mblur / totalWeight;
    }
#endif

mat2 rotate2D(float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return mat2(c, -s, s, c);
}

void main() {
    #ifdef NO_POSTPROCESSING
        gl_FragData[0] = texture2D(texture, coord0);
        return;
    #endif

    vec2 texcoord = (coord0 * 2.0 - 1.0) / 1.1;
    float centerDistance = length(texcoord);
    texcoord *= centerDistance * FISHEYE_STRENGTH + (1.0 - FISHEYE_STRENGTH);
    texcoord.x *= aspectRatio;
    #ifdef GLOBAL_SHAKE_ENABLED
        texcoord.xy += shakeOffset;
        #ifdef TILT_ENABLED
            texcoord.xy *= rotate2D(tiltValue);
        #endif
    #endif
    texcoord.x /= aspectRatio;
    texcoord = texcoord * 0.5 + 0.5;

    vec4 depth = texture2D(depthtex0, texcoord);
    vec3 color = texture2D(texture, texcoord).rgb;
    #ifdef MOTION_BLUR_ENABLED
        color = MotionBlur(color, texcoord, depth.r, random(texcoord * frameTimeCounter));
    #endif

    /* RENDERTARGETS: 0,1,2 */
    gl_FragData[0] = vec4(color, 1.0);
    #ifdef BLOOM_ENABLED
        gl_FragData[1] = vec4(color * smoothstep(0.3, 1.0, dot(color, vec3(0.333))), 1.0);
    #endif
    gl_FragData[2] = vec4(depth.rgb, 1.0);
}
