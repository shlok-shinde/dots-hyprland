#version 440
// Liquid glass for surfaces the compositor's glass plugin can't reach (the
// lock screen). The same optics as hyprglass, in the shell: the glass takes
// its shape from `mask` (any item's alpha), reads its height from `field`
// (that shape blurred by about the bezel width), and refracts `behind`.
//
// Compile: qsb --glsl "100 es,120,150" -o liquidglass.frag.qsb liquidglass.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;     // px of the padded box all three textures cover
    float bezel;       // px of curved rim
    float refraction;  // px the rim shifts what is behind it
    float bodyLens;    // magnification across the whole pane (0.03 = 3%)
    float frost;       // px of blur in what shows through
    float rim;         // brightness of the one-pixel edge
    float brightness;
    float adaptiveDim; // how hard bright backdrops are pulled down (readability)
    vec4 tint;         // rgb, a = amount
    float dispersion;  // chromatic split at the rim
    float shadow;      // soft drop shadow under the glass
};
layout(binding = 1) uniform sampler2D mask;
layout(binding = 2) uniform sampler2D field;
layout(binding = 3) uniform sampler2D behind;

const float CEILING = 0.30;

float luma(vec3 c) {
    return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 backdrop(vec2 uv, vec2 px) {
    if (frost < 0.01)
        return texture(behind, uv).rgb;
    vec2 d = frost * px;
    return (texture(behind, uv).rgb * 2.0
          + texture(behind, uv + vec2(d.x, d.y)).rgb + texture(behind, uv + vec2(-d.x, d.y)).rgb
          + texture(behind, uv + vec2(d.x, -d.y)).rgb + texture(behind, uv + vec2(-d.x, -d.y)).rgb) / 6.0;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = 1.0 / itemSize;

    float coverage = texture(mask, uv).a;

    // Outside the shape: only a soft shadow, which keeps the glass apart from what is behind
    if (coverage < 0.002) {
        float s = texture(field, uv - vec2(0.0, 3.0) * px).a;
        fragColor = vec4(0.0, 0.0, 0.0, shadow * pow(clamp(s * 2.0, 0.0, 1.0), 1.6)) * qt_Opacity;
        return;
    }

    // The crisp rim: where coverage falls off within one pixel
    float n4 = min(min(texture(mask, uv + vec2(px.x, 0.0)).a, texture(mask, uv - vec2(px.x, 0.0)).a),
                   min(texture(mask, uv + vec2(0.0, px.y)).a, texture(mask, uv - vec2(0.0, px.y)).a));
    float line = clamp(coverage - n4, 0.0, 1.0);

    // The bezel: the blurred shape is the glass's height. Its gradient points
    // inward and is steepest at the edge, flat deep inside.
    vec2 g = vec2(texture(field, uv + vec2(px.x, 0.0)).a - texture(field, uv - vec2(px.x, 0.0)).a,
                  texture(field, uv + vec2(0.0, px.y)).a - texture(field, uv - vec2(0.0, px.y)).a) * 0.5;
    float slope = clamp(length(g) * bezel * 2.5, 0.0, 1.0);
    vec2 inward = length(g) > 1e-6 ? normalize(g) : vec2(0.0);

    // Refraction: the rim shows what lies just outside it, squeezed in; the
    // whole pane is a shallow magnifier
    vec2 offset = -inward * pow(slope, 1.5) * refraction * px - (uv - 0.5) * bodyLens;
    vec3 color = vec3(backdrop(uv + offset * (1.0 + dispersion), px).r,
                      backdrop(uv + offset, px).g,
                      backdrop(uv + offset * (1.0 - dispersion), px).b);

    // Tone: smoked, with bright backdrops pulled down so text on the glass stays readable
    float l = luma(color);
    float toned = l - max(l - CEILING, 0.0) * adaptiveDim;
    color *= brightness * (l > 1e-4 ? toned / l : 1.0);
    color = mix(color, tint.rgb, tint.a);

    // Light: no key light. The edge brightens where it reflects something
    // bright just outside it, and a little is caught inside the curve
    float env = smoothstep(0.30, 0.95, luma(texture(behind, uv - inward * 5.0 * px).rgb));
    color += vec3(slope * slope * 0.06 * (0.3 + 0.7 * env));
    color = mix(color, vec3(1.0), clamp(line * rim * (0.42 + 0.58 * env), 0.0, 1.0));

    fragColor = vec4(color * coverage, coverage) * qt_Opacity;
}
