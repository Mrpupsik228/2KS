// main post-processing layer
#version 120

#include "/lib/properties.glsl"
#include "/lib/noise.glsl"

const bool colortex1MipmapEnabled = true;
/*
const int colortex2Format = R32F;
*/

uniform sampler2D texture, colortex1, colortex2;
uniform float frameTimeCounter;
uniform float viewWidth, viewHeight, aspectRatio;
uniform vec3 sunPosition;
uniform mat4 gbufferProjection;

varying vec2 coord0;

#ifdef BLOOM_ENABLED
    vec3 bloomKernel(in vec2 texcoord, in float scale, in float lod) {
        vec2 pixelSize = vec2(scale / viewWidth, scale / viewHeight);
        vec3 color = textureLod(colortex1, texcoord, lod).rgb * 0.5;

        color += textureLod(colortex1, texcoord + vec2( 1.0,  0.0) * pixelSize, lod).rgb * 0.25;
        color += textureLod(colortex1, texcoord + vec2(-1.0,  0.0) * pixelSize, lod).rgb * 0.25;
        color += textureLod(colortex1, texcoord + vec2( 0.0,  1.0) * pixelSize, lod).rgb * 0.25;
        color += textureLod(colortex1, texcoord + vec2( 0.0, -1.0) * pixelSize, lod).rgb * 0.25;

        color += textureLod(colortex1, texcoord + vec2( 2.0,  0.0) * pixelSize, lod).rgb * 0.125;
        color += textureLod(colortex1, texcoord + vec2(-2.0,  0.0) * pixelSize, lod).rgb * 0.125;
        color += textureLod(colortex1, texcoord + vec2( 0.0,  2.0) * pixelSize, lod).rgb * 0.125;
        color += textureLod(colortex1, texcoord + vec2( 0.0, -2.0) * pixelSize, lod).rgb * 0.125;

        return color;
    }
#endif

#ifdef LENS_FLARE_ENABLED
    vec3 flare(in vec3 color, in float dist, in float radius, in float softness, in vec2 invSunPos, in vec2 flareDir) {
        float radiusDist = radius * dist;
        return color * smoothstep(0.0, softness * radiusDist, radiusDist - distance(invSunPos, flareDir / dist));
    }
#endif

void main() {
    #ifdef NO_POSTPROCESSING
        gl_FragData[0] = texture2D(texture, coord0);
        return;
    #endif

    #ifdef BLOOM_ENABLED
        vec3 bloom = bloomKernel(coord0, 128.0, 7.0);
        bloom += bloomKernel(coord0, 64.0, 6.0);
        bloom *= 0.3 * BLOOM_STRENGTH;

        #ifdef BROKEN_BLOOM_ENABLED
            vec3 theseBrokenLines = vec3(0.0);
            for(int i = 0; i < 8; i++) {
                theseBrokenLines += max(dot(textureLod(colortex1, vec2(coord0.s, (float(i) + random(coord0 + sin(frameTimeCounter))) * (1.0 / 8.0)), 3.0).rgb - 0.3, vec3(0.333)), 0.0);
            }
            bloom += vec3(0.4, 0.1, 0.9) * min(theseBrokenLines, 0.2) * BROKEN_BLOOM_STRENGTH;
        #endif
    #endif
    
    #ifdef CHROMATIC_ABBERATION_ENABLED
        float chromaticAberrationAmount = CHROMATIC_ABBERATION_STRENGTH / viewWidth * float(DOWNSAMPLING);
        float red = texture2D(texture, vec2(coord0.s + chromaticAberrationAmount, coord0.t)).r;
        float green = texture2D(texture, coord0).g;
        float blue = texture2D(texture, vec2(coord0.s - chromaticAberrationAmount, coord0.t)).b;

        gl_FragData[0] = vec4(red, green, blue, 1.0);
    #else
        gl_FragData[0] = texture2D(texture, coord0);
    #endif
    #ifdef BLOOM_ENABLED
        gl_FragData[0].rgb += bloom;
    #endif
    #ifdef FILM_GRAIN_ENABLED
        gl_FragData[0].rgb *= mix(random((vec2(fract(coord0 * vec2(viewWidth, viewHeight) / max(float(DOWNSAMPLING), 1.0) / 75.0) * 75.0)) + sin(frameTimeCounter) * 10.0) * 0.5 + 0.5, 1.0, 1.0 - FILM_GRAIN_STRENGTH);
    #endif

    #ifdef LENS_FLARE_ENABLED
        vec4 sunPositionOnScreen = gbufferProjection * vec4(sunPosition * 0.01, 1.0);
        sunPositionOnScreen /= sunPositionOnScreen.w;

        vec2 viewRes = vec2(viewWidth, viewHeight);
        float lensAvailability = 0.0;
        for (int i = 0; i < 8; i++) {
            float angle = float(i) * 0.785398163;
            float spiral = sin(angle * 2.38123) * 0.5 + 0.5;
            lensAvailability += step(0.9996, texture2D(colortex2, sunPositionOnScreen.st * 0.5 + 0.5 + vec2(cos(angle), sin(angle)) * spiral * 64.0 / viewRes).r);
        }
        lensAvailability *= 0.125;

        vec2 texcoord = coord0 * 2.0 - 1.0;
        texcoord.x *= aspectRatio;
        texcoord = texcoord * 0.5 + 0.5;
        texcoord += snoise(vec3(texcoord * 4.0, 0.0)) * 0.006;
        vec2 localSunPositionOnScreen = sunPositionOnScreen.st;
        localSunPositionOnScreen.x *= aspectRatio;

        vec2 invSunPos = -localSunPositionOnScreen;
        vec2 flareDir = (texcoord - localSunPositionOnScreen) * 2.0 - 1.0;

        vec3 lensFlare = vec3(0.0);
        lensFlare += flare(vec3(0.3, 1.0, 0.4) * 0.6, 3.9, 0.001, 2.0, invSunPos, flareDir);
        lensFlare += flare(vec3(0.3, 1.0, 0.4) * 0.2, 3.8, 0.005, 0.2, invSunPos, flareDir);
        lensFlare += flare(vec3(0.8, 0.6, 0.3) * 0.3, 3.5, 0.01, 0.2, invSunPos, flareDir);
        lensFlare += flare(vec3(1.0, 0.0, 0.0) * 0.5, 3.0, 0.003, 1.0, invSunPos, flareDir);
        lensFlare += flare(vec3(0.0, 1.0, 0.0) * 0.5, 2.95, 0.003, 1.0, invSunPos, flareDir);
        lensFlare += flare(vec3(0.0, 0.0, 1.0) * 0.5, 2.9, 0.003, 1.0, invSunPos, flareDir);
        lensFlare += flare(vec3(1.0, 0.6, 0.3) * 0.3, 2.8, 0.013, 0.3, invSunPos, flareDir);
        lensFlare += flare(vec3(0.9, 0.8, 0.3) * 0.3, 1.5, 0.06, 0.3, invSunPos, flareDir);
        lensFlare = floor(lensFlare * 16.0 + random(texcoord + sin(frameTimeCounter) * 13.23842)) / 16.0;
        lensFlare *= 0.5 * LENS_FLARE_STRENGTH;

        lensFlare = mix(vec3(0.0), lensFlare, lensAvailability);
        gl_FragData[0].rgb += lensFlare * max(1.0 - distance(sunPositionOnScreen.xy, vec2(0.0)), 0.0) * max(dot(sunPosition * 0.01, vec3(0.0, 0.0, -1.0)), 0.0);
    #endif
}
