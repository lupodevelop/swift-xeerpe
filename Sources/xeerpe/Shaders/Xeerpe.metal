#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
#include <TargetConditionals.h>
using namespace metal;

static float xhash(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

static float xnoise(float2 p) {
    float2 i = floor(p), f = fract(p);
    float a = xhash(i), b = xhash(i + float2(1, 0)), c = xhash(i + float2(0, 1)), d = xhash(i + float2(1, 1));
    float2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Position 0...1 of unit-square point `u` along a sweep at `angle` radians,
// scaled so the sweep runs exactly from one corner to the opposite one.
static float xsweep(float2 u, float angle) {
    float2 dir = float2(cos(angle), sin(angle));
    return dot(u - 0.5, dir) / (abs(dir.x) + abs(dir.y)) + 0.5;
}

// Whether `p` lies inside the view's rect. Only geometry: the layer is
// never passed to a helper (see the blur macro below). Unused on watchOS,
// where the shaders that call it are compiled out.
__attribute__((unused)) static bool xinside(float2 p, float4 bounds) { return all(p >= bounds.xy) && all(p < bounds.xy + bounds.zw); }

static float xfbm(float2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * xnoise(p); p = p * 2.02 + float2(1.7, 9.2); a *= 0.5; }
    return v;
}

// Domain-warped noise mapped onto four colors. The pointer pulls the field
// toward itself. Fills the whole bounding rect; clip it from outside.
[[ stitchable ]] half4 xeerpeLiquid(float2 pos, half4 color, float4 bounds, float time, float speed, float warp,
                                    half4 c0, half4 c1, half4 c2, half4 c3, float2 pointer, float pointerOn) {
    float aspect = bounds.z / bounds.w;
    float2 p = (pos / bounds.zw - 0.5) * float2(aspect, 1.0) * 2.2;
    float t = time * speed * 0.15;
    float2 pu = (pointer / bounds.zw - 0.5) * float2(aspect, 1.0) * 2.2;
    float2 d = pu - p;
    p += pointerOn * d * exp(-dot(d, d) * 1.6) * 0.45;
    float2 q = float2(xfbm(p + t), xfbm(p + float2(5.2, 1.3) - t));
    float2 r = float2(xfbm(p + warp * q + float2(1.7, 9.2) + 0.7 * t), xfbm(p + warp * q + float2(8.3, 2.8) - 0.6 * t));
    float f = xfbm(p + warp * r);
    half3 col = mix(c0.rgb, c1.rgb, half(clamp(f * f * 2.0, 0.0, 1.0)));
    col = mix(col, c2.rgb, half(clamp(length(q), 0.0, 1.0)));
    col = mix(col, c3.rgb, half(clamp(r.x * r.x, 0.0, 1.0)));
    col *= half(0.55 + 0.9 * f);
    return half4(clamp(col, half3(0.0), half3(1.0)), 1.0);
}

#if !TARGET_OS_WATCH
// A glass lens around `center`: magnifies, splits color slightly at the
// edge, and adds a rim and a specular highlight. Highlights are premultiplied
// by the content's own alpha, so nothing is drawn over transparent areas, and
// every sample stays inside the layer.
[[ stitchable ]] half4 xeerpeLens(float2 pos, SwiftUI::Layer layer, float4 bounds, float2 center, float radius, float strength) {
    float2 lo = bounds.xy, hi = bounds.xy + bounds.zw - 1.0;
    float2 d = pos - center;
    float r = length(d);
    if (r >= radius) { return layer.sample(pos); }
    float k = r / radius;
    float2 src = clamp(center + d * (1.0 - strength * (1.0 - k * k)), lo, hi);
    float2 dir = r > 0.0 ? d / r : float2(0.0);
    float ca = 0.02 * radius * k;
    half4 base = layer.sample(src);
    half4 cr = layer.sample(clamp(src + dir * ca, lo, hi)), cb = layer.sample(clamp(src - dir * ca, lo, hi));
    half4 col = half4(cr.r, base.g, cb.b, base.a);
    float rim = smoothstep(0.84, 0.97, k) * (1.0 - smoothstep(0.97, 1.0, k));
    float spec = pow(max(0.0, 1.0 - length(d / radius - float2(-0.35, -0.4)) * 2.2), 3.0);
    float shine = rim * 0.4 + spec * 0.28 + 0.04;
    col.rgb += half3(1.0) * half(shine) * base.a;
    return col;
}
#endif

// Concentric wave expanding from `origin`, `time` seconds after the tap.
[[ stitchable ]] float2 xeerpeRipple(float2 pos, float2 origin, float time, float amplitude, float frequency, float speed, float decay) {
    float d = distance(pos, origin);
    float delay = d / speed;
    if (time < delay) { return pos; }
    float t = time - delay;
    float amp = amplitude * sin(t * frequency) * exp(-decay * t);
    float2 dir = d > 0.0 ? (pos - origin) / d : float2(0.0);
    return pos + dir * amp;
}

// Reveals the content along a distance field: `mode` 0 wipe (along `angle`),
// 1 iris and 2 fluid (both growing from `origin`, fluid with a noisy edge).
// `progress` 0 hides everything, 1 shows everything. A luminous band of
// `glow` rides the edge, but only on the content's own pixels.
[[ stitchable ]] half4 xeerpeReveal(float2 pos, half4 color, float4 bounds, float progress, float mode,
                                    float2 origin, float angle, float softness, float turbulence, half4 glow) {
    float2 size = bounds.zw;
    float2 u = pos / size;
    float aspect = size.x / size.y;
    float w = max(softness, 0.001);
    float s;
    float extra = 0.0;
    if (mode < 0.5 || mode > 2.5) {
        s = xsweep(u, angle);
        if (mode > 2.5) {
            // Dust: each 2.5 px grain crosses the edge at its own moment.
            s += (xhash(floor(pos / 2.5)) - 0.5) * turbulence;
            extra = turbulence * 0.5;
        }
    } else {
        float2 a = float2(aspect, 1.0);
        float2 o = origin * a, p = u * a;
        float far = max(max(distance(o, float2(0.0)), distance(o, float2(a.x, 0.0))),
                        max(distance(o, float2(0.0, a.y)), distance(o, a)));
        s = distance(p, o) / far;
        if (mode > 1.5) {
            s += (xfbm(p * 3.2) - 0.5) * turbulence;
            extra = turbulence * 0.5;
        }
    }
    float edgePos = mix(-w - extra, 1.0 + w + extra, progress);
    float a = 1.0 - smoothstep(edgePos - w, edgePos, s);
    float band = (s - (edgePos - w * 0.45)) / (w * 0.38);
    float edge = 0.85 * exp(-band * band) * smoothstep(0.0, 0.03, progress) * (1.0 - smoothstep(0.97, 1.0, progress));
    half alpha = max(color.a * half(a), color.a * half(edge) * glow.a);
    half3 rgb = color.rgb * half(a) + glow.rgb * half(edge) * color.a;
    return half4(min(rgb, half3(alpha)), alpha);
}

// Grain: a mono speckle mixed over the pixel at `opacity`. Alpha is kept.
[[ stitchable ]] half4 xeerpeGrain(float2 pos, half4 color, float opacity) {
    half n = half(xhash(floor(pos) + 0.5));
    half3 rgb = mix(color.rgb, half3(n) * color.a, half(opacity));
    return half4(rgb, color.a);
}

// Mottled noise, `scale` is its frequency in 1/20 px. Alpha is kept.
[[ stitchable ]] half4 xeerpeNoise(float2 pos, half4 color, float opacity, float scale) {
    half n = half(xfbm(pos * scale * 0.05));
    half3 rgb = mix(color.rgb, half3(n) * color.a, half(opacity));
    return half4(rgb, color.a);
}

#if !TARGET_OS_WATCH
// Gaussian-weighted Vogel spiral blur of RADIUS points around POS into OUT,
// rotated per pixel so the samples do not band. Samples stay inside BOUNDS,
// and OUT is scaled by the alpha of BASE, so the blur never spills past the
// content's edges or into its transparent corners. Two traps, both checked
// by tests: dividing by the blurred alpha, or sampling the layer from a
// helper function, makes every offset sample read back the pixel itself and
// the blur silently disappears. Hence a macro and a plain multiply.
#define XEERPE_SPIRAL_BLUR(LAYER, POS, BOUNDS, RADIUS, BASE, OUT) {                    \
    float2 lo_ = (BOUNDS).xy + 0.5, hi_ = (BOUNDS).xy + (BOUNDS).zw - 0.5;               \
    float rot_ = xhash(floor(POS)) * 6.2831853;                                          \
    half4 acc_ = half4(0.0);                                                             \
    float wsum_ = 0.0;                                                                   \
    for (int i_ = 0; i_ < 48; i_++) {                                                    \
        float r_ = sqrt((float(i_) + 0.5) / 48.0);                                       \
        float th_ = float(i_) * 2.3999632 + rot_;                                        \
        float w_ = exp(-2.0 * r_ * r_);                                                  \
        acc_ += LAYER.sample(clamp(POS + r_ * (RADIUS) * float2(cos(th_), sin(th_)), lo_, hi_)) * half(w_); \
        wsum_ += w_;                                                                     \
    }                                                                                    \
    OUT = (acc_ / half(wsum_)) * (BASE).a;                                               \
}

// Interactive reveal: a clear circle of `radius` around `center` (points);
// outside it the content is blurred up to `maxBlur` and darkened by
// `darken`, with an edge `softness` points wide. `turbulence` > 0 warps the
// edge with noise so it looks like ink or liquid.
[[ stitchable ]] half4 xeerpeFocus(float2 pos, SwiftUI::Layer layer, float4 bounds, float2 center, float radius,
                                   float softness, float maxBlur, float darken, float turbulence) {
    half4 base = layer.sample(pos);
    if (base.a <= 0.0) { return base; }
    float d = distance(pos, center);
    if (turbulence > 0.0) { d += (xfbm(pos * 0.025) - 0.5) * turbulence * max(radius, 40.0); }
    float hidden = 1.0;
    if (radius > 0.0) {
        float s = max(min(softness, radius), 0.0001);
        float t = clamp((d - (radius - s)) / (2.0 * s), 0.0, 1.0);
        hidden = t * t * (3.0 - 2.0 * t);
    }
    float r = maxBlur * hidden;
    half4 col = base;
    if (r >= 0.5) XEERPE_SPIRAL_BLUR(layer, pos, bounds, r, base, col)
    col.rgb *= half(1.0 - darken * hidden);
    return col;
}
#endif

#if !TARGET_OS_WATCH
// The fold effect of a folding phone screen: blur and darkness grow across
// the surface away from the hinge edge (`edgeMode` 0 leading, 1 trailing,
// 2 top, 3 bottom), scaled by `progress`. Blur radius follows pow(edge, 1.35)
// up to `maxBlur`; darkening starts at a fifth of the way and reaches black.
// The blur is a Gaussian-weighted Vogel spiral, rotated per pixel so the
// samples do not band. The result keeps the content's own alpha, so the
// blur stays inside its shape.
[[ stitchable ]] half4 xeerpeDuo(float2 pos, SwiftUI::Layer layer, float4 bounds, float progress, float edgeMode, float maxBlur) {
    float2 u = (pos - bounds.xy) / bounds.zw;
    float e = edgeMode < 0.5 ? u.x : (edgeMode < 1.5 ? 1.0 - u.x : (edgeMode < 2.5 ? u.y : 1.0 - u.y));
    float p = clamp(progress, 0.0, 1.0);
    float motion = p * p * (3.0 - 2.0 * p);
    float radius = maxBlur * motion * pow(clamp(e, 0.0, 1.0), 1.35);
    float darken = min(1.0, 2.0 * motion * pow(clamp((e - 0.2) / 0.8, 0.0, 1.0), 1.35));
    half4 base = layer.sample(pos);
    half4 col;
    if (radius < 0.5 || base.a <= 0.0) {
        col = base;
    } else {
        XEERPE_SPIRAL_BLUR(layer, pos, bounds, radius, base, col)
    }
    col.rgb *= half(1.0 - darken);
    return col;
}
#endif


#if !TARGET_OS_WATCH
// Spoiler: the content is replaced by a field of drifting, twinkling
// particles. A front grows from `origin` with radius `radius`; behind it the
// content shows, and the particles it passes fly outward and fade. Each
// pixel looks at the particles of its own 2.5 px cell and the 8 around it,
// so a particle can drift across a cell edge without being cut.
[[ stitchable ]] half4 xeerpeSpoiler(float2 pos, SwiftUI::Layer layer, float4 bounds, float time,
                                     float2 origin, float radius, float band, half4 tint) {
    const float cell = 2.5;
    half4 base = layer.sample(pos);
    float wobble = (xnoise(pos * 0.06 + time * 0.4) - 0.5) * band;
    float hidden = smoothstep(radius - band, radius + band, distance(pos, origin) + wobble);

    float glow = 0.0;
    float2 home = floor(pos / cell);
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 id = home + float2(x, y);
            float h = xhash(id);
            if (h > 0.62) continue;
            float h2 = xhash(id + 17.3), h3 = xhash(id + 41.7);
            float ang = time * (0.6 + h2 * 1.4) + h * 40.0;
            float2 p = (id + 0.5) * cell + float2(cos(ang), sin(ang * 1.3)) * cell * 0.8;
            float2 away = p - origin;
            float dist = length(away);
            float stay = smoothstep(radius - band, radius + band * 2.0, dist);
            p += (dist > 0.001 ? away / dist : float2(0)) * (1.0 - stay) * 22.0 * (0.5 + h3);
            float size = 0.45 + h3 * 0.55;
            float twinkle = 0.45 + 0.55 * sin(time * (2.0 + h2 * 4.0) + h3 * 30.0);
            glow += smoothstep(size + 0.6, size - 0.2, distance(pos, p)) * twinkle * stay;
        }
    }
    float a = clamp(glow, 0.0, 1.0) * float(tint.a);
    return base * half(1.0 - hidden) + half4(tint.rgb * half(a), half(a));
}
#endif

#if !TARGET_OS_WATCH
// Aura: five soft blobs of color orbiting the center at their own speeds and
// blended by distance, over a field warped by slow noise, so the colors flow
// into each other like liquid. Fills the bounding rect; clip it outside.
[[ stitchable ]] half4 xeerpeAura(float2 pos, half4 color, float4 bounds, float t,
                                  half4 c0, half4 c1, half4 c2, half4 c3, half4 c4) {
    float2 p = (pos - bounds.xy) / bounds.zw - 0.5;
    p += 0.12 * float2(xnoise(p * 2.2 + float2(t * 0.25, 0.0)) - 0.5, xnoise(p * 2.2 + float2(4.0, t * 0.22)) - 0.5);
    half4 cs[5] = { c0, c1, c2, c3, c4 };
    float3 acc = 0.0;
    float wsum = 0.0;
    for (int i = 0; i < 5; i++) {
        float fi = float(i);
        float sp = 0.45 + 0.17 * fi;
        float2 c = 0.32 * float2(sin(t * sp + fi * 1.9), cos(t * sp * 0.83 + fi * 2.7));
        float d = length(p - c);
        float w = exp(-d * d * 16.0);
        acc += float3(cs[i].rgb) * w;
        wsum += w;
    }
    float3 rgb = acc / max(wsum, 1e-4);
    return half4(half3(rgb), 1.0);
}
#endif

#if !TARGET_OS_WATCH
// Blur sweep: a front crosses the view along `angle` as `progress` goes 0 to
// 1. Behind it the content is blurred up to `maxBlur` and dimmed by
// `darken`; ahead of it the content is sharp. `band` is the width of the
// soft transition, as a fraction of the sweep.
[[ stitchable ]] half4 xeerpeBlurSweep(float2 pos, SwiftUI::Layer layer, float4 bounds, float progress, float angle,
                                       float maxBlur, float band, float darken) {
    float2 u = (pos - bounds.xy) / bounds.zw;
    float s = xsweep(u, angle);
    float b = max(band, 0.001);
    float front = mix(-b, 1.0 + b, clamp(progress, 0.0, 1.0));
    float k = 1.0 - smoothstep(front - b, front + b, s);
    float radius = maxBlur * k;
    half4 base = layer.sample(pos);
    half4 col = base;
    if (radius >= 0.5 && base.a > 0.0) {
        XEERPE_SPIRAL_BLUR(layer, pos, bounds, radius, base, col)
    }
    col.rgb *= half(1.0 - darken * k);
    return col;
}
#endif

#if !TARGET_OS_WATCH
// Blocks of `size` points, each the color at its center, on a grid anchored
// at the view's origin. Pixels in the sampling margin around the view stay
// clear, so edge blocks do not spill past its frame.
[[ stitchable ]] half4 xeerpePixelate(float2 pos, SwiftUI::Layer layer, float4 bounds, float size) {
    if (!xinside(pos, bounds)) { return half4(0.0); }
    float2 c = (floor((pos - bounds.xy) / size) + 0.5) * size + bounds.xy;
    return layer.sample(clamp(c, bounds.xy, bounds.xy + bounds.zw - 1.0));
}

// Glitch at `strength` 0...1: rows of a random height slide sideways by up
// to `shift` points, and red and blue split apart. `seed` picks the pattern.
// Samples stay inside the view, and its sampling margin stays clear.
[[ stitchable ]] half4 xeerpeGlitch(float2 pos, SwiftUI::Layer layer, float4 bounds, float strength, float seed, float shift) {
    if (!xinside(pos, bounds)) { return half4(0.0); }
    float2 lo = bounds.xy, hi = bounds.xy + bounds.zw - 1.0;
    float rowHeight = mix(3.0, 22.0, xhash(float2(seed, 7.1)));
    float row = floor((pos.y - bounds.y) / rowHeight);
    float moved = step(xhash(float2(row, seed)), 0.45 * strength);
    float2 p = pos + float2(moved * (xhash(float2(seed, row + 3.7)) - 0.5) * 2.0 * shift * strength, 0.0);
    float split = shift * 0.25 * strength;
    half4 base = layer.sample(clamp(p, lo, hi));
    half4 r = layer.sample(clamp(p + float2(split, 0.0), lo, hi));
    half4 b = layer.sample(clamp(p - float2(split, 0.0), lo, hi));
    return half4(r.r, base.g, b.b, max(base.a, max(r.a, b.a)));
}

// Digital rain: in each column of `cell`-point cells a drop falls at its own
// speed, `speed` cells a second on average, with a white head and a trail
// of `tint` that fades over 6 to 20 cells. Each cell holds a random 5x7
// bitmap glyph that changes a few times a second. `density` is the share
// of columns that rain. Fills the bounding rect; clip it outside.
[[ stitchable ]] half4 xeerpeMatrix(float2 pos, half4 color, float4 bounds, float time, float cell, float speed,
                                    float density, half4 tint, half4 back) {
    float2 p = pos - bounds.xy;
    float2 id = floor(p / cell);
    float hc = xhash(float2(id.x, 3.1));
    float trail = 6.0 + 14.0 * xhash(float2(id.x, 8.7));
    float period = bounds.w / cell + trail;
    float head = fmod(time * speed * (0.6 + hc) + hc * period * 7.0, period);
    float behind = head - id.y;
    float lit = (behind >= 0.0 && behind < trail) ? 1.0 - behind / trail : 0.0;
    lit *= step(xhash(float2(id.x, 1.3)), density);
    float2 f = fract(p / cell);
    float2 g = floor((f - 0.1) / 0.8 * float2(5.0, 7.0));
    float inside = step(0.1, f.x) * step(f.x, 0.9) * step(0.1, f.y) * step(f.y, 0.9);
    float change = floor(time * (1.0 + 3.0 * xhash(id + 0.5)));
    float bit = step(0.5, xhash(id * 1.37 + g * 0.173 + change * 0.71)) * inside;
    float headGlow = behind >= 0.0 && behind < 1.0 ? 1.0 : 0.0;
    half3 glyph = mix(tint.rgb, half3(1.0), half(headGlow * 0.8));
    half3 rgb = back.rgb + glyph * half(lit * bit);
    return half4(min(rgb, half3(1.0)), 1.0);
}
#endif

// Burn, bottom up: each pixel burns when the front passes its threshold,
// 70% height and 30% noise so the front is ragged. Ahead of the front the
// content chars over a band of 0.08; inside the band it glows from white-hot
// to `edge` and then ash, and its 1.5 pt grains fall away one by one.
[[ stitchable ]] half4 xeerpeBurn(float2 pos, half4 color, float4 bounds, float progress, half4 edge) {
    const float w = 0.08;
    float2 u = (pos - bounds.xy) / bounds.zw;
    float s = (1.0 - u.y) * 0.7 + xfbm(pos * 0.035) * 0.3;
    float d = s - mix(-w, 1.0 + w, progress);
    if (d < -w) { return half4(0.0); }
    if (d < 0.0) {
        float k = -d / w;
        if (xhash(floor(pos / 1.5)) < k) { return half4(0.0); }
        half3 hot = mix(half3(1.0, 0.95, 0.75), edge.rgb, half(min(k * 2.0, 1.0)));
        half3 rgb = mix(hot, half3(0.22, 0.2, 0.18), half(smoothstep(0.5, 1.0, k)));
        return half4(rgb * color.a, color.a);
    }
    if (d < w) { return half4(color.rgb * half(1.0 - 0.85 * (1.0 - d / w)), color.a); }
    return color;
}

#if !TARGET_OS_WATCH
// Embers: each 8 pt cell of the view may hold one emitter, at a random
// point that is solid with clear space 4 pt above or below it (outside the
// view counts as clear). Its spark climbs `height` points over its life,
// wobbling and flickering, white-hot at birth and `tint` as it fades. Each
// pixel checks the emitters in the cells beside it and below it within
// `height`. Drawn over the content, and in the margin above it.
[[ stitchable ]] half4 xeerpeEmbers(float2 pos, SwiftUI::Layer layer, float4 bounds, float time, float amount,
                                    float height, half4 tint) {
    const float cell = 8.0;
    float2 lo = bounds.xy, hi = bounds.xy + bounds.zw;
    half4 base = xinside(pos, bounds) ? layer.sample(pos) : half4(0.0);
    float glow = 0.0, heat = 0.0;
    float2 home = floor((pos - lo) / cell);
    int rows = int(ceil(height / cell)) + 1;
    for (int j = 0; j <= rows; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 id = home + float2(i, j);
            float h = xhash(id + 0.31);
            if (h > amount * 0.5) continue;
            float2 o = lo + (id + float2(xhash(id + 5.7), xhash(id + 9.1))) * cell;
            if (!xinside(o, bounds)) continue;
            float2 up = o - float2(0.0, 4.0), dn = o + float2(0.0, 4.0);
            half a0 = layer.sample(o).a;
            half au = up.y < lo.y ? 0.0h : layer.sample(up).a;
            half ad = dn.y >= hi.y ? 0.0h : layer.sample(dn).a;
            if (a0 < 0.5h || (au > 0.5h && ad > 0.5h)) continue;
            float life = fract(time * (0.35 + 0.4 * xhash(id + 2.3)) + h * 7.0);
            float2 e = o + float2(sin(time * 3.0 + h * 40.0) * 3.0 * life, -life * height);
            float r = 0.8 + xhash(id + 4.4);
            float flicker = 0.7 + 0.3 * sin(time * 9.0 + h * 50.0);
            glow += smoothstep(r + 1.0, r - 0.3, distance(pos, e)) * (1.0 - life) * flicker;
            heat = max(heat, 1.0 - life);
        }
    }
    float a = clamp(glow, 0.0, 1.0) * float(tint.a);
    half3 c = mix(tint.rgb, half3(1.0, 0.95, 0.8), half(heat * heat * 0.6));
    return half4(c * half(a) + base.rgb * half(1.0 - a), half(a) + base.a * half(1.0 - a));
}
#endif

// Scanlines: brightness follows a cosine with period `spacing`, dipping by
// `intensity` between lines. With `roll` > 0 a bar up to 8% brighter
// crosses the view top to bottom every 10 / `roll` seconds.
[[ stitchable ]] half4 xeerpeScanlines(float2 pos, half4 color, float4 bounds, float spacing, float intensity,
                                       float time, float roll) {
    float y = pos.y - bounds.y;
    float k = 1.0 - intensity * (0.5 - 0.5 * cos(y / spacing * 6.2831853));
    if (roll > 0.0) { k *= 1.0 + 0.08 * smoothstep(0.8, 1.0, fract(y / bounds.w - time * roll * 0.1)); }
    return half4(min(color.rgb * half(k), half3(color.a)), color.a);
}

// Phosphor stripes: columns `size` wide pass mostly red, green or blue in
// turn, brightened by half so white keeps its level, mixed in by `intensity`.
[[ stitchable ]] half4 xeerpePhosphor(float2 pos, half4 color, float size, float intensity) {
    float k = fmod(floor(pos.x / size), 3.0);
    half3 m = k < 0.5 ? half3(1.5, 0.4, 0.4) : (k < 1.5 ? half3(0.4, 1.5, 0.4) : half3(0.4, 0.4, 1.5));
    half3 rgb = color.rgb * mix(half3(1.0), m, half(intensity));
    return half4(min(rgb, half3(color.a)), color.a);
}

// Barrel: each point samples from farther out the farther it is from the
// center, by `amount` times its squared distance (1 at the edge midpoints),
// so the content bulges and the corners sample outside and turn clear.
[[ stitchable ]] float2 xeerpeBarrel(float2 pos, float4 bounds, float amount) {
    float2 half_ = bounds.zw * 0.5, c = bounds.xy + half_;
    float2 u = (pos - c) / half_;
    return c + u * (1.0 + amount * dot(u, u)) * half_;
}

// Vignette: dims by up to `amount` from 40% of the way to a corner onward.
[[ stitchable ]] half4 xeerpeVignette(float2 pos, half4 color, float4 bounds, float amount) {
    float d = length((pos - bounds.xy) / bounds.zw - 0.5) / 0.70710678;
    return half4(color.rgb * half(1.0 - amount * smoothstep(0.4, 1.0, d)), color.a);
}

// Ordered dither onto the first `tones` (2...4) colors: brightness picks two
// neighbouring colors and a 4x4 Bayer threshold, per cell of `pixel` points
// anchored at the view's origin, chooses between them.
[[ stitchable ]] half4 xeerpeDither(float2 pos, half4 color, float4 bounds, float pixel, float tones,
                                    half4 c0, half4 c1, half4 c2, half4 c3) {
    if (color.a <= 0.0h) { return color; }
    const float bayer[16] = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };
    float2 g = fmod(floor((pos - bounds.xy) / pixel), 4.0);
    float t = (bayer[int(g.y) * 4 + int(g.x)] + 0.5) / 16.0;
    float l = clamp(dot(float3(color.rgb / color.a), float3(0.299, 0.587, 0.114)), 0.0, 1.0) * (tones - 1.0);
    float i = min(floor(l) + step(t, fract(l)), tones - 1.0);
    half4 c = i < 0.5 ? c0 : (i < 1.5 ? c1 : (i < 2.5 ? c2 : c3));
    return half4(c.rgb * color.a, color.a);
}

#if !TARGET_OS_WATCH
// Brightness of LAYER at P (clamped into LO...HI) into OUT, premultiplied
// (the same as straight for the opaque samples it keeps); FALLBACK where the
// sample is mostly transparent.
#define XEERPE_LUM(LAYER, P, LO, HI, FALLBACK, OUT) {                                     \
    half4 s_ = LAYER.sample(clamp(P, LO, (HI) - 1.0));                                    \
    OUT = s_.a > 0.5h ? dot(float3(s_.rgb), float3(0.299, 0.587, 0.114)) : FALLBACK;      \
}

// Toon: colors pushed by `vivid` (saturation 1 + vivid), brightness snapped
// up to one of `levels` bands, 1/levels to 1, keeping the hue, so shadows
// stay colored instead of going black; ink in `outline` where a Sobel filter
// over brightness, 8 neighbours at 1.5 pt or 0.35 `width`, finds a jump
// above `ink`; and an outline `width` thick outside the content's shape,
// found from the alpha of 16 directions at half and full width. Samples
// outside the view count as clear, so the outline never grows past
// `width`, and the rest of the sampling margin stays clear.
[[ stitchable ]] half4 xeerpeToon(float2 pos, SwiftUI::Layer layer, float4 bounds, float levels, half4 outline,
                                  float width, float ink, float vivid) {
    float2 lo = bounds.xy, hi = bounds.xy + bounds.zw;
    half4 base = xinside(pos, bounds) ? layer.sample(pos) : half4(0.0);
    half4 col = base;
    const float3 lw = float3(0.299, 0.587, 0.114);
    if (base.a > 0.0h) {
        float3 rgb = float3(base.rgb / base.a);
        float l = dot(rgb, lw);
        rgb = clamp(mix(float3(l), rgb, 1.0 + vivid), 0.0, 1.0);
        float lv = dot(rgb, lw);
        if (levels >= 2.0 && lv > 0.001) {
            float q = min(floor(lv * levels) + 1.0, levels) / levels;
            rgb = min(rgb * (q / lv), float3(1.0));
        }
        col = half4(half3(rgb) * base.a, base.a);
        if (ink > 0.0 && base.a > 0.5h) {
            float d = max(1.5, width * 0.35);
            float n0, n1, n2, n3, n5, n6, n7, n8;
            XEERPE_LUM(layer, pos + float2(-d, -d), lo, hi, l, n0)
            XEERPE_LUM(layer, pos + float2(0, -d), lo, hi, l, n1)
            XEERPE_LUM(layer, pos + float2(d, -d), lo, hi, l, n2)
            XEERPE_LUM(layer, pos + float2(-d, 0), lo, hi, l, n3)
            XEERPE_LUM(layer, pos + float2(d, 0), lo, hi, l, n5)
            XEERPE_LUM(layer, pos + float2(-d, d), lo, hi, l, n6)
            XEERPE_LUM(layer, pos + float2(0, d), lo, hi, l, n7)
            XEERPE_LUM(layer, pos + float2(d, d), lo, hi, l, n8)
            float gx = (n2 + 2.0 * n5 + n8) - (n0 + 2.0 * n3 + n6);
            float gy = (n6 + 2.0 * n7 + n8) - (n0 + 2.0 * n1 + n2);
            float e = length(float2(gx, gy)) * 0.25;
            float k = smoothstep(ink, ink * 1.4, e);
            col = half4(mix(col.rgb, outline.rgb * base.a, half(k)), base.a);
        }
    }
    if (width > 0.0 && base.a < 0.99h) {
        float cover = 0.0;
        for (int i = 0; i < 16; i++) {
            float th = float(i) * 0.39269908;
            float2 dir = float2(cos(th), sin(th));
            for (int k = 1; k <= 2; k++) {
                float2 q = pos + dir * width * 0.5 * float(k);
                if (xinside(q, bounds)) { cover = max(cover, float(layer.sample(q).a)); }
            }
        }
        float oa = smoothstep(0.3, 0.6, cover) * float(outline.a);
        col += half4(outline.rgb * half(oa), half(oa)) * (1.0h - col.a);
    }
    return col;
}
#endif

// How much of the point is covered by a halftone dot for coverage `v`, on a
// grid of `size` turned by `angle`. Radius grows with sqrt(v) up to 0.75
// `size`, past the cell's corners, so v = 1 covers everything; the edge is
// antialiased over 1.5 pt and nothing is drawn at v = 0.
static float xdot(float2 pos, float size, float angle, float v) {
    float c = cos(angle), s = sin(angle);
    float2 q = float2(c * pos.x + s * pos.y, c * pos.y - s * pos.x) / size;
    float d = length(fract(q) - 0.5) * size;
    float r = size * 0.75 * sqrt(clamp(v, 0.0, 1.0));
    return smoothstep(r + 0.75, r - 0.75, d) * clamp(r / 0.75, 0.0, 1.0);
}

// Halftone. Mono: `ink` dots on `paper` by darkness. Colored: cyan,
// magenta, yellow and black dots on grids at 15, 75, 0 and 45 degrees from
// `angle`, black taking the gray part of each color, each ink capped at 60%
// coverage so the paper shows between the dots.
[[ stitchable ]] half4 xeerpeHalftone(float2 pos, half4 color, float size, float angle, half4 ink, half4 paper, float colored) {
    if (color.a <= 0.0h) { return color; }
    float3 rgb = float3(color.rgb / color.a);
    float3 out;
    if (colored < 0.5) {
        float v = 1.0 - dot(rgb, float3(0.299, 0.587, 0.114));
        out = mix(float3(paper.rgb), float3(ink.rgb), xdot(pos, size, angle, v));
    } else {
        float3 cmy = 1.0 - rgb;
        float k = min(cmy.x, min(cmy.y, cmy.z));
        cmy = (cmy - k) * 0.6;
        const float d = 0.01745329;
        out = float3(paper.rgb);
        out.r *= 1.0 - xdot(pos, size, angle - 30.0 * d, cmy.x);
        out.g *= 1.0 - xdot(pos, size, angle + 30.0 * d, cmy.y);
        out.b *= 1.0 - xdot(pos, size, angle - 45.0 * d, cmy.z);
        out *= 1.0 - xdot(pos, size, angle, k * 0.85);
    }
    return half4(half3(out) * color.a, color.a);
}

#if !TARGET_OS_WATCH
// Gooey: alpha blurred with Gaussian weights over 4 rings of 12 samples
// reaching twice `radius` (sigma about `radius`), each ring turned half a
// step from the one inside it so the edge stays smooth, then cut at 0.35:
// shapes closer than about `radius` melt into one blob and lone edges stay
// close to where they were. The color is the most opaque sample near the
// point, scaled by the new alpha; samples outside the view count as clear.
[[ stitchable ]] half4 xeerpeGooey(float2 pos, SwiftUI::Layer layer, float4 bounds, float radius) {
    half4 best = layer.sample(pos);
    float acc = float(best.a), wsum = 1.0;
    for (int k = 0; k < 4; k++) {
        float r = (float(k) + 1.0) / 4.0;
        float w = exp(-2.0 * r * r);
        for (int i = 0; i < 12; i++) {
            float th = (float(i) + 0.5 * float(k)) * 0.52359878;
            float2 q = pos + r * radius * 2.0 * float2(cos(th), sin(th));
            half4 s = xinside(q, bounds) ? layer.sample(q) : half4(0.0);
            acc += float(s.a) * w;
            wsum += w;
            best = s.a > best.a ? s : best;
        }
    }
    float a = smoothstep(0.28, 0.42, acc / wsum);
    return best * half(a);
}

// Smoke: from 6 pt inside the content's top edge up to `height` above it.
// Two noise fields drift up at different speeds; the second warps the
// first more the higher the smoke is, so it billows and drifts sideways.
// Its source is how much content sits on the top row under the smoke,
// averaged with tent weights over a span that widens with height and
// wavers with the noise, so plumes fan out and fade softly at the sides.
// A slow noise along x splits it into separate plumes. Density thins in
// over the first 10% and out toward the top, is capped at 0.85, and the smoke is lighter where it is denser.
// Drawn over the content and in the margin above and beside it.
[[ stitchable ]] half4 xeerpeSmoke(float2 pos, SwiftUI::Layer layer, float4 bounds, float time, float amount,
                                   float height, half4 tint) {
    float2 lo = bounds.xy, hi = bounds.xy + bounds.zw;
    half4 base = xinside(pos, bounds) ? layer.sample(pos) : half4(0.0);
    float k = (lo.y + 6.0 - pos.y) / height;
    if (k <= 0.0 || k >= 1.0) { return base; }
    float2 p = pos / 30.0;
    float2 w = float2(xfbm(p * 0.7 + float2(0.0, time * 0.35)), xfbm(p * 0.7 + float2(5.2, time * 0.3)));
    float2 q = p + float2(0.0, time * 0.6) + (w - 0.5) * (0.6 + 2.0 * k);
    float n = xfbm(q * 1.3);
    float spread = (6.0 + height * 0.5 * k) * (0.7 + 0.6 * w.y);
    float drift = (w.x - 0.5) * 30.0 * k;
    float src = 0.0;
    for (int i = -3; i <= 3; i++) {
        float x = pos.x + drift + float(i) * spread / 3.0;
        float on = x >= lo.x && x < hi.x ? 1.0 : 0.0;
        src += float(layer.sample(clamp(float2(x, lo.y + 2.0), lo, hi - 1.0)).a) * on * (4.0 - abs(float(i)));
    }
    src /= 16.0;
    float fade = smoothstep(0.0, 0.1, k) * pow(1.0 - k, 1.7);
    float plume = mix(0.2, 1.0, smoothstep(0.3, 0.7, xnoise(float2((pos.x + drift) / 45.0, time * 0.15))));
    float d = clamp(smoothstep(0.22, 0.8, n) * src * plume * fade * amount * 1.7, 0.0, 0.85) * float(tint.a);
    half3 c = tint.rgb * half(0.85 + 0.3 * n);
    return half4(c * half(d) + base.rgb * half(1.0 - d), half(d) + base.a * half(1.0 - d));
}

// Sparks: `count` streaks launched from `origin` around the circle at
// `speed` (0.5 to 1.5 times, by hash), falling at 260 pt/s², each drawn as
// a segment of its last 0.06 s, white-hot then `tint`, gone at 0.9 s.
[[ stitchable ]] half4 xeerpeSparks(float2 pos, SwiftUI::Layer layer, float4 bounds, float2 origin, float t,
                                    float count, float speed, half4 tint) {
    half4 base = xinside(pos, bounds) ? layer.sample(pos) : half4(0.0);
    const float life = 0.9;
    const float2 g = float2(0.0, 260.0);
    float glow = 0.0;
    float t0 = max(t - 0.06, 0.0);
    for (int i = 0; i < 32; i++) {
        if (float(i) >= count) break;
        float ang = (float(i) + xhash(float2(i, 1.7)) * 0.8) / count * 6.2831853;
        float2 vel = float2(cos(ang), sin(ang)) * speed * (0.5 + xhash(float2(i, 8.3)));
        float2 head = origin + vel * t + 0.5 * g * t * t;
        float2 tail = origin + vel * t0 + 0.5 * g * t0 * t0;
        float2 pa = pos - tail, ba = head - tail;
        float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-4), 0.0, 1.0);
        glow += smoothstep(1.6, 0.3, length(pa - ba * h));
    }
    float fade = 1.0 - t / life;
    float a = clamp(glow * fade, 0.0, 1.0) * float(tint.a);
    half3 c = mix(tint.rgb, half3(1.0, 0.97, 0.9), half(fade * fade * 0.7));
    return half4(c * half(a) + base.rgb * half(1.0 - a), half(a) + base.a * half(1.0 - a));
}

// Color bleed: chroma averaged over 6 samples reaching `amount` to the
// left, so colors smear rightward, with the pixel's own brightness kept.
// The sampling margin stays clear, here and in tracking and riso.
[[ stitchable ]] half4 xeerpeColorBleed(float2 pos, SwiftUI::Layer layer, float4 bounds, float amount) {
    if (!xinside(pos, bounds)) { return half4(0.0); }
    float2 lo = bounds.xy, hi = bounds.xy + bounds.zw - 1.0;
    const float3 lw = float3(0.299, 0.587, 0.114);
    half4 base = layer.sample(pos);
    float3 acc = float3(0.0);
    for (int i = 0; i < 6; i++) {
        acc += float3(layer.sample(clamp(pos - float2(amount * float(i) / 5.0, 0.0), lo, hi)).rgb);
    }
    acc /= 6.0;
    float3 rgb = acc - dot(acc, lw) + dot(float3(base.rgb), lw);
    return half4(half3(clamp(rgb, 0.0, float(base.a))), base.a);
}

// Tracking: rows wobble sideways by up to 0.3 `amount`; a band 10 pt tall
// rolls down every 6.7 s, shifting the rows it crosses by up to 1.25
// `amount` with noise and graying them with static.
[[ stitchable ]] half4 xeerpeTracking(float2 pos, SwiftUI::Layer layer, float4 bounds, float time, float amount) {
    if (!xinside(pos, bounds)) { return half4(0.0); }
    float2 lo = bounds.xy, hi = bounds.xy + bounds.zw - 1.0;
    float y = pos.y - lo.y;
    float band = fract(time * 0.15) * (bounds.w + 40.0) - 20.0;
    float inBand = 1.0 - smoothstep(0.0, 10.0, abs(y - band));
    float dx = amount * (0.3 * sin(y * 0.15 + time * 6.0) + 2.5 * inBand * (xhash(float2(floor(y / 2.0), floor(time * 30.0))) - 0.5));
    half4 c = layer.sample(clamp(pos + float2(dx, 0.0), lo, hi));
    float n = xhash(floor(pos) + fract(time) * 100.0);
    c.rgb = mix(c.rgb, half3(n) * c.a, half(inBand * 0.35));
    return c;
}

// Risograph: two inks multiplied on white paper. Each ink's coverage is the
// darkness of the content (transparent counts as paper) sampled `offset`
// away, one each side, so edges show a fringe of a single ink; `grain`
// speckles the coverage per point.
[[ stitchable ]] half4 xeerpeRiso(float2 pos, SwiftUI::Layer layer, float4 bounds, half4 inkA, half4 inkB,
                                  float offset, float grain) {
    if (!xinside(pos, bounds)) { return half4(0.0); }
    float2 lo = bounds.xy, hi = bounds.xy + bounds.zw - 1.0;
    const float3 lw = float3(0.299, 0.587, 0.114);
    float2 o = float2(offset, offset * 0.5);
    half4 a = layer.sample(clamp(pos + o, lo, hi));
    half4 b = layer.sample(clamp(pos - o, lo, hi));
    half4 base = layer.sample(pos);
    float ca = 1.0 - dot(float3(a.rgb) + (1.0 - float(a.a)), lw);
    float cb = 1.0 - dot(float3(b.rgb) + (1.0 - float(b.a)), lw);
    ca *= 1.0 - grain * xhash(floor(pos));
    cb *= 1.0 - grain * xhash(floor(pos) + 7.3);
    float3 rgb = mix(float3(1.0), float3(inkA.rgb), ca) * mix(float3(1.0), float3(inkB.rgb), cb);
    half alpha = max(base.a, max(a.a, b.a));
    return half4(half3(rgb) * alpha, alpha);
}
#endif

// Genie: as `progress` goes 0 to 1 the rows pinch toward `tx` (0...1 across)
// on the bottom edge, lower rows first, then the whole content slides down
// into it. With `top` = 1 the same happens toward the top edge. Points
// that map outside the content sample far away and turn clear.
[[ stitchable ]] float2 xeerpeGenie(float2 pos, float4 bounds, float progress, float tx, float top) {
    float2 u = (pos - bounds.xy) / bounds.zw;
    if (top > 0.5) { u.y = 1.0 - u.y; }
    float s = smoothstep(0.3, 1.0, progress);
    float v = (u.y - s) / max(1.0 - s, 1e-4);
    float k = clamp(progress * 1.6 - (1.0 - u.y) * 0.9, 0.0, 1.0);
    k = k * k * (3.0 - 2.0 * k);
    float w = mix(1.0, 0.04, k);
    float x = (u.x - mix(0.0, tx - 0.02, k)) / w;
    if (progress >= 1.0 || v < 0.0 || v > 1.0 || x < 0.0 || x > 1.0) { return float2(-1e5); }
    if (top > 0.5) { v = 1.0 - v; }
    return bounds.xy + float2(x, v) * bounds.zw;
}

// Light direction for the finishes: from the top left with no tilt, moving
// toward where the view tilts.
static float2 xlight(float2 tilt) { return normalize(float2(-0.35, -0.75) + tilt * 1.2); }

#if !TARGET_OS_WATCH
// Bevel: 12 directions at half and full `width` look for clear space (the
// outside of the view counts as clear). Their sum is the outward normal of
// the facet, and how close the clear space is sets how much of a facet the
// pixel is. Facets facing the light brighten toward white, the others
// darken. Interior pixels and the sampling margin are left as they are.
[[ stitchable ]] half4 xeerpeBevel(float2 pos, SwiftUI::Layer layer, float4 bounds, float width, float2 light, float intensity) {
    if (!xinside(pos, bounds)) { return half4(0.0); }
    half4 base = layer.sample(pos);
    if (base.a <= 0.0h) { return base; }
    float2 outward = float2(0.0);
    float edge = 0.0;
    for (int i = 0; i < 12; i++) {
        float th = float(i) * 0.52359878;
        float2 d = float2(cos(th), sin(th));
        for (int k = 1; k <= 2; k++) {
            float2 q = pos + d * width * 0.5 * float(k);
            float a = xinside(q, bounds) ? float(layer.sample(q).a) : 0.0;
            outward += d * (1.0 - a) / float(k);
            edge = max(edge, (1.0 - a) * (k == 1 ? 1.0 : 0.6));
        }
    }
    if (edge <= 0.01 || length(outward) < 1e-3) { return base; }
    float facing = dot(normalize(outward), xlight(light));
    float k = edge * intensity;
    half3 rgb = base.rgb + half3(base.a) * half(max(facing, 0.0) * k * 0.8);
    rgb *= half(1.0 - max(-facing, 0.0) * k * 0.6);
    return half4(min(rgb, half3(base.a)), base.a);
}
#endif

// Brushed metal. Linear: grain from slow noise along x and a hash per half
// point of y, and a highlight band across rows that follows the light's y.
// Radial: grain fast in radius and slow around, and two opposite highlight
// lobes at the light's angle. Grain shifts the brightness by up to ±17%
// of `intensity`; the highlight adds white, stronger on lighter grain.
[[ stitchable ]] half4 xeerpeBrushed(float2 pos, half4 color, float4 bounds, float2 light, float intensity, float radial) {
    if (color.a <= 0.0h) { return color; }
    float2 u = (pos - bounds.xy) / bounds.zw;
    float grain, spec;
    if (radial < 0.5) {
        grain = xnoise(float2(pos.x * 0.015, pos.y * 1.7)) * 0.6 + xhash(float2(floor(pos.y * 2.0), 3.1)) * 0.4;
        float band = u.y - (0.5 + light.y * 0.45);
        spec = exp(-band * band * 18.0);
    } else {
        float2 c = pos - (bounds.xy + bounds.zw * 0.5);
        float th = atan2(c.y, c.x);
        grain = xnoise(float2(length(c) * 1.7, th * 3.0)) * 0.6 + xhash(float2(floor(length(c) * 2.0), 5.3)) * 0.4;
        float2 l = xlight(light);
        spec = pow(abs(cos(th - atan2(l.y, l.x))), 12.0);
    }
    half3 rgb = color.rgb * half(1.0 + (grain - 0.5) * 0.35 * intensity);
    rgb += half3(color.a) * half(spec * intensity * (0.6 + 0.4 * grain));
    return half4(min(rgb, half3(color.a)), color.a);
}

// Foil: crinkles are the gradient of noise at 1/12 pt; they tilt the shade
// and bend a sheen that sweeps diagonally across the view, moved by the
// light. Every opaque pixel becomes `tint` shaded that way, plus white sheen.
[[ stitchable ]] half4 xeerpeFoil(float2 pos, half4 color, float4 bounds, half4 tint, float2 light, float crinkle) {
    if (color.a <= 0.0h) { return color; }
    const float s = 0.08;
    float n0 = xnoise(pos * s);
    float2 nrm = float2(xnoise((pos + float2(1.0, 0.0)) * s) - n0, xnoise((pos + float2(0.0, 1.0)) * s) - n0) * crinkle * 12.0;
    float2 u = (pos - bounds.xy) / bounds.zw - 0.5;
    float sweep = dot(u, float2(0.86, 0.51)) - dot(light, float2(0.5, 0.35)) + dot(nrm, float2(0.7, 0.7));
    float spec = exp(-sweep * sweep * 30.0);
    float shade = 0.65 + 0.35 * (0.5 + 0.5 * sin(sweep * 6.0 + 1.0)) + dot(nrm, xlight(light));
    half3 rgb = tint.rgb * half(clamp(shade, 0.3, 1.3)) + half3(spec * 0.8);
    return half4(min(rgb, half3(1.0)) * color.a, color.a);
}

// Sparkle: one glint spot per cell of 3 `size`, kept for a `density` share
// of cells. Each flashes when a phase made of its hash and the light passes
// a peak (sin to the 10th), drawn as a soft core and two thin arms. Each
// pixel checks its cell and the 8 around it. Only adds light where the
// content is.
[[ stitchable ]] half4 xeerpeSparkle(float2 pos, half4 color, float2 light, float density, float size) {
    if (color.a <= 0.0h) { return color; }
    float cell = size * 3.0;
    float2 home = floor(pos / cell);
    float glow = 0.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 id = home + float2(i, j);
            float h = xhash(id + 0.7);
            if (h > density) continue;
            float2 c = (id + float2(xhash(id + 3.1), xhash(id + 8.4))) * cell;
            float phase = h * 40.0 + light.x * (5.0 + 6.0 * xhash(id + 1.9)) + light.y * (4.0 + 6.0 * xhash(id + 2.6));
            float on = pow(max(0.0, sin(phase)), 10.0);
            float2 d = abs(pos - c);
            float star = exp(-dot(d, d) / (size * size * 0.08))
                       + exp(-d.x / (size * 0.12)) * exp(-d.y / (size * 0.9))
                       + exp(-d.y / (size * 0.12)) * exp(-d.x / (size * 0.9));
            glow += star * on;
        }
    }
    half g = half(clamp(glow, 0.0, 1.0)) * color.a;
    return half4(min(color.rgb + half3(g), half3(color.a)), color.a);
}

// Guilloché: around the center, rings 5 pt apart each wave `lines` times
// around and drift with the radius; a second family runs the other way
// half a wave off, so the two interlace. A line is where the ring phase
// is near a whole number. Lines facing the light shine up to 30% more.
[[ stitchable ]] half4 xeerpeGuilloche(float2 pos, half4 color, float4 bounds, half4 ink, float2 light, float lines, float intensity) {
    if (color.a <= 0.0h) { return color; }
    float2 c = pos - (bounds.xy + bounds.zw * 0.5);
    float r = length(c), th = atan2(c.y, c.x);
    float s1 = r / 5.0 + 1.6 * sin(lines * th + r * 0.04);
    float s2 = r / 5.0 + 1.6 * sin(lines * th - r * 0.04 + 3.14159265);
    float line = max(smoothstep(0.38, 0.5, abs(fract(s1) - 0.5)), smoothstep(0.38, 0.5, abs(fract(s2) - 0.5)));
    float2 l = xlight(light);
    float luster = 0.7 + 0.3 * cos(th - atan2(l.y, l.x));
    float a = line * intensity * luster;
    return half4(mix(color.rgb, ink.rgb * color.a, half(a)), color.a);
}

// Pearl: a film whose thickness is slow fbm, read as a phase together with
// the position and the light, turned into color with three cosines a third
// apart and pulled halfway to white for a pastel sheen; mixed into the
// content by `intensity`.
[[ stitchable ]] half4 xeerpePearl(float2 pos, half4 color, float4 bounds, float2 light, float intensity) {
    if (color.a <= 0.0h) { return color; }
    float2 u = (pos - bounds.xy) / bounds.zw - 0.5;
    float phase = xfbm(pos * 0.012) * 1.2 + 0.4 + dot(u, float2(0.9, 0.6)) + dot(light, float2(0.6, 0.45));
    float3 irid = mix(float3(1.0), 0.5 + 0.5 * cos(6.2831853 * (phase + float3(0.0, 0.33, 0.67))), 0.55);
    float3 rgb = float3(color.rgb / color.a);
    rgb = mix(rgb, rgb * 0.55 + irid * 0.55, intensity);
    return half4(half3(clamp(rgb, 0.0, 1.0)) * color.a, color.a);
}

// Brightness of straight (not premultiplied) color, with the weights used
// throughout this file.
static float xluma(float3 rgb) { return dot(rgb, float3(0.299, 0.587, 0.114)); }

// Screen blend: lightens `a` by `b`, never past white.
static float3 xscreen(float3 a, float3 b) { return 1.0 - (1.0 - a) * (1.0 - b); }

// `tint` scaled to brightness `l`: the hue of the tint at the brightness
// of the pixel it replaces.
static float3 xtint(float3 tint, float l) { return clamp(tint * (l / max(xluma(tint), 0.05)), 0.0, 1.0); }

// Integer hash of a cell and a seed to 0...1. Unlike `xhash` it has no
// visible rows or columns at fine scales, which grain needs.
static float xcellhash(float2 cell, float seed) {
    uint x = uint(int(cell.x)) * 1597334677u ^ uint(int(cell.y)) * 3812015801u ^ uint(seed) * 2798796415u;
    x = (x ^ (x >> 16u)) * 0x7feb352du;
    x = (x ^ (x >> 15u)) * 0x846ca68bu;
    return float(x ^ (x >> 16u)) / 4294967295.0;
}

// Film grain: per cell of `size` points, the sum of two hashes minus one
// (-1...1, peaked at 0), new for each `seed`. It shifts brightness by up to
// a quarter of `amount`, fully in the mid-tones and 35% at black and
// white, as on film.
[[ stitchable ]] half4 xeerpeFilmGrain(float2 pos, half4 color, float amount, float size, float seed) {
    if (color.a <= 0.0h) { return color; }
    float2 cell = floor(pos / size);
    float n = xcellhash(cell, seed) + xcellhash(cell, seed + 101.0) - 1.0;
    float3 rgb = float3(color.rgb / color.a);
    float l = xluma(rgb);
    rgb += n * amount * 0.25 * (0.35 + 2.6 * l * (1.0 - l));
    return half4(half3(clamp(rgb, 0.0, 1.0)) * color.a, color.a);
}

// Gradient map: brightness 0...1 runs along `count` evenly spaced stops,
// darkest first, and the color found there replaces the content's by
// `amount`.
[[ stitchable ]] half4 xeerpeGradientMap(float2 pos, half4 color, device const half4 *stops, int count, float amount) {
    if (color.a <= 0.0h || count < 1) { return color; }
    float3 rgb = float3(color.rgb / color.a);
    float l = clamp(xluma(rgb), 0.0, 1.0) * float(count - 1);
    int i = min(int(l), max(count - 2, 0));
    float3 m = count == 1 ? float3(stops[0].rgb) : mix(float3(stops[i].rgb), float3(stops[i + 1].rgb), l - float(i));
    rgb = mix(rgb, m, amount);
    return half4(half3(clamp(rgb, 0.0, 1.0)) * color.a, color.a);
}

// Color grade on straight color, in this order: contrast scales the
// distance from mid-grey by 1 + `contrast`; saturation the distance from
// the pixel's own grey by 1 + `saturation`; warmth raises red against blue.
// Then the pixel moves toward the hue of `shadows` and of `highlights`, at
// its own brightness, by `split.x` and `split.y`, weighted by how dark or
// bright it is. Last, `fade`
// lifts black toward 20% grey and dims white by 6%, like a matte print.
[[ stitchable ]] half4 xeerpeGrade(float2 pos, half4 color, float contrast, float saturation, float warmth, float fade,
                                   half4 shadows, half4 highlights, float2 split) {
    if (color.a <= 0.0h) { return color; }
    float3 rgb = float3(color.rgb / color.a);
    rgb = (rgb - 0.5) * (1.0 + contrast) + 0.5;
    rgb = mix(float3(xluma(rgb)), rgb, 1.0 + saturation);
    rgb = clamp(rgb * float3(1.0 + 0.12 * warmth, 1.0 + 0.02 * warmth, 1.0 - 0.12 * warmth), 0.0, 1.0);
    float l = xluma(rgb);
    rgb = mix(rgb, xtint(float3(shadows.rgb), l), split.x * (1.0 - smoothstep(0.0, 0.55, l)));
    rgb = mix(rgb, xtint(float3(highlights.rgb), l), split.y * smoothstep(0.45, 1.0, l));
    rgb = mix(float3(fade * 0.2), float3(1.0 - fade * 0.06), rgb);
    return half4(half3(clamp(rgb, 0.0, 1.0)) * color.a, color.a);
}

// Light leak: two blobs of `tint`, a large one bleeding in from the left
// edge and a smaller one from the right, sliding along their edges over
// about 20 s of `time` and breathing slightly. Their cores burn toward
// pale yellow. Only the content's own pixels are lit.
[[ stitchable ]] half4 xeerpeLightLeak(float2 pos, half4 color, float4 bounds, float time, half4 tint, float intensity) {
    if (color.a <= 0.0h) { return color; }
    float2 u = (pos - bounds.xy) / bounds.zw;
    float t = time * 0.3;
    float2 da = (u - float2(-0.05, 0.3 + 0.22 * sin(t))) * float2(2.6, 1.2);
    float2 db = (u - float2(1.05, 0.75 + 0.18 * sin(t * 0.7 + 2.0))) * float2(3.2, 1.6);
    float a = exp(-dot(da, da) * 1.4), b = exp(-dot(db, db) * 1.6) * 0.7;
    float k = min((a + b) * 1.4, 1.0) * intensity * (0.85 + 0.15 * xnoise(float2(t * 2.0, 0.5)));
    float3 light = mix(float3(tint.rgb), float3(1.0, 0.9, 0.55), pow(a, 12.0));
    float3 rgb = float3(color.rgb / color.a);
    // Filtered through the leak's color first, so light areas take its hue
    // instead of washing out to white, then screened with it.
    rgb = xscreen(rgb * mix(float3(1.0), light, k * 0.6), light * k);
    return half4(half3(rgb) * color.a, color.a);
}

// Trading-card holo: rainbow bands running diagonally, their phase moved by
// the light so they slide as the card turns, broken by fine diagonal lines
// 7 pt apart and strongest along a sheen that follows the light. Screened
// onto the content by `intensity`.
[[ stitchable ]] half4 xeerpeHolo(float2 pos, half4 color, float4 bounds, float2 light, float intensity) {
    if (color.a <= 0.0h) { return color; }
    float2 u = (pos - bounds.xy) / bounds.zw - 0.5;
    float d = dot(u, float2(0.7071, 0.7071));
    float3 rainbow = 0.5 + 0.5 * cos(6.2831853 * (d * 2.2 + dot(light, float2(0.9, 0.6)) + float3(0.0, 0.33, 0.67)));
    float lines = 0.75 + 0.25 * sin((pos.x - pos.y) * 0.9);
    float s = d - light.x * 0.5 - light.y * 0.3;
    float sheen = exp(-s * s * 14.0);
    float3 rgb = float3(color.rgb / color.a);
    rgb = mix(rgb, xscreen(rgb, rainbow * 0.9), intensity * (0.45 + 0.55 * sheen) * lines);
    return half4(half3(clamp(rgb, 0.0, 1.0)) * color.a, color.a);
}

// Chrome: every opaque pixel reflects a horizon, as polished chrome letters
// do: white sky fading into `sky`, a dark band at the horizon, then
// `ground` brightening to white at the bottom. The reflection is read at
// the pixel's height in the view, shifted by the light and bent slightly by
// noise so the horizon is not ruler straight.
[[ stitchable ]] half4 xeerpeChrome(float2 pos, half4 color, float4 bounds, float2 light, half4 sky, half4 ground) {
    if (color.a <= 0.0h) { return color; }
    float2 u = (pos - bounds.xy) / bounds.zw;
    float v = u.y + light.y * 0.22 + light.x * (u.x - 0.5) * 0.25 + (xnoise(pos * 0.03) - 0.5) * 0.08;
    const float h = 0.55;
    float3 rgb;
    if (v < h) {
        rgb = mix(float3(1.0), float3(sky.rgb), pow(clamp(v / h, 0.0, 1.0), 1.4));
        rgb = mix(rgb, float3(0.05, 0.06, 0.12), smoothstep(h - 0.1, h, v));
    } else {
        float t = clamp((v - h) / (1.0 - h), 0.0, 1.0);
        rgb = mix(float3(0.12, 0.08, 0.06), float3(ground.rgb), sqrt(t));
        rgb = mix(rgb, float3(0.95), t * t * t);
    }
    return half4(half3(rgb) * color.a, color.a);
}

#if !TARGET_OS_WATCH
// Halation: light scattered back through the film base. Around each pixel,
// 3 rings of 12 samples out to `radius` measure how much of the neighbourhood
// is brighter than `threshold`, the nearer rings counting more; that share
// screens `tint` onto the pixel by `intensity`. Samples outside the view
// count as dark, and the sampling margin stays clear.
[[ stitchable ]] half4 xeerpeHalation(float2 pos, SwiftUI::Layer layer, float4 bounds, float radius, float threshold,
                                      half4 tint, float intensity) {
    if (!xinside(pos, bounds)) { return half4(0.0); }
    half4 base = layer.sample(pos);
    if (base.a <= 0.0h) { return base; }
    float glow = 0.0, total = 0.0;
    for (int k = 1; k <= 3; k++) {
        float w = 1.0 / float(k);
        for (int i = 0; i < 12; i++) {
            float th = (float(i) + 0.5 * float(k)) * 0.52359878;
            float2 q = pos + float2(cos(th), sin(th)) * radius * float(k) / 3.0;
            if (xinside(q, bounds)) {
                half4 s = layer.sample(q);
                glow += w * smoothstep(threshold, 1.0, float(xluma(float3(s.rgb))));
            }
            total += w;
        }
    }
    float3 rgb = xscreen(float3(base.rgb / base.a), float3(tint.rgb) * glow / total * intensity * 1.6);
    return half4(half3(clamp(rgb, 0.0, 1.0)) * base.a, base.a);
}

// ASCII: the view in cells of `cell` points. Each cell's brightness, from
// its center and four points around it, picks one of ten characters ordered
// by how much ink they have (" .:-+=*o%#"). The character is a 5x5 bitmap
// on a 6x6 grid, so neighbours keep a gap. It is drawn in `ink`, or in the
// cell's own color when `colored`, on `paper`, over the cell's alpha.
[[ stitchable ]] half4 xeerpeAscii(float2 pos, SwiftUI::Layer layer, float4 bounds, float cell, half4 ink, half4 paper, float colored) {
    if (!xinside(pos, bounds)) { return half4(0.0); }
    const uint glyphs[10] = { 0x0, 0x4, 0x20080, 0x3800, 0x23880, 0x701c0, 0xabaa0, 0x7462e, 0x19d1173, 0xafabea };
    float2 o = pos - bounds.xy;
    float2 c = bounds.xy + (floor(o / cell) + 0.5) * cell;
    float2 lo = bounds.xy, hi = bounds.xy + bounds.zw - 1.0;
    float q = cell * 0.25;
    half4 s = (layer.sample(clamp(c, lo, hi)) + layer.sample(clamp(c + float2(q, q), lo, hi))
             + layer.sample(clamp(c + float2(-q, q), lo, hi)) + layer.sample(clamp(c + float2(q, -q), lo, hi))
             + layer.sample(clamp(c + float2(-q, -q), lo, hi))) * 0.2h;
    if (s.a <= 0.0h) { return half4(0.0); }
    float3 straight = float3(s.rgb / s.a);
    int index = int(clamp(xluma(straight) * 10.0, 0.0, 9.0));
    int2 g = int2(floor(fract(o / cell) * 6.0));
    bool on = g.x < 5 && g.y < 5 && ((glyphs[index] >> uint(24 - (g.y * 5 + g.x))) & 1u) != 0u;
    float3 fg = colored > 0.5 ? clamp(straight * 1.25, 0.0, 1.0) : float3(ink.rgb);
    float3 rgb = on ? fg : float3(paper.rgb);
    return half4(half3(rgb) * s.a, s.a);
}
#endif
