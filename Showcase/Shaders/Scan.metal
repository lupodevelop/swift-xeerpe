#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// A document scanner: the line sits at `line` (0 top, 1 bottom) of the
// view. What it has passed is turned into crisp black and white, and the
// line itself glows green. Alpha is kept.
[[ stitchable ]] half4 scan(float2 pos, half4 color, float4 bounds, float line) {
    if (color.a <= 0.0h) { return color; }
    float y = (pos.y - bounds.y) / bounds.w;
    float3 rgb = float3(color.rgb / color.a);
    if (y < line) {
        float g = dot(rgb, float3(0.299, 0.587, 0.114));
        rgb = float3(smoothstep(0.3, 0.6, g));
    }
    float glow = exp(-pow((y - line) * bounds.w / 6.0, 2.0));
    rgb = mix(rgb, float3(0.45, 1.0, 0.75), glow * 0.85);
    return half4(half3(clamp(rgb, 0.0, 1.0)) * color.a, color.a);
}
