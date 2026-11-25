# Getting Started

Add xeerpe to a package, apply a chain to a view and drive it with a signal.

## Add the package

xeerpe needs Xcode 26 (Swift 6.2) or newer and runs on iOS 17, macOS 14,
tvOS 17, watchOS 10 and visionOS 26.

```swift
.package(url: "https://github.com/lupodevelop/swift-xeerpe.git", from: "0.1.0")
```

Then add `"xeerpe"` to your target's dependencies.

## Apply a chain

`.xeerpe(_:)` takes a chain. A single effect, or
effects joined with dots, is a chain:

```swift
photo.xeerpe(.film())
photo.xeerpe(.film().without(.lightLeak))
```

The builder form lists effects one per line:

```swift
card.xeerpe {
    .preset(.midnight, reacting: .tilt)
    .scale(.press(from: 1, to: 0.96))
    .feedback(.impact, sound: .pop, on: .press)
}
```

Two effects that change the same property of the view conflict. The chain
reports it in ``XeerpeChain/conflicts``.

## Drive an effect with a signal

A parameter that takes a ``XeerpeValue`` accepts a constant, a binding, the
pointer, tilt, press, focus or time. The effect redraws only when that
signal changes:

```swift
bar.xeerpe { .glow(.orange, radius: .binding($volume).mapped(to: 0, 14)) }
```

## Follow asynchronous work

A ``XeerpeJob`` runs async work and exposes its phase, progress and value.
``XeerpeChain/phases(_:transition:glow:duration:_:)-swift.method`` picks a chain for each
phase and moves between them:

```swift
@State private var job = XeerpeJob<String>()

orb.xeerpe {
    .phases(job) { phase in
        switch phase {
        case .pending: .aura(speed: 2).bloom(radius: 30, intensity: 0.7)
        case .failed: .aura(XeerpeGlow.ember)
        default: .aura()
        }
    }
}

job.run { report in
    await report(0.5)
    return try await fetchAnswer()
}
```

## Write your own shader

A Metal shader in your target becomes an effect that chains like the
built-in ones:

```swift
extension XeerpeEffect {
    static func scan(_ progress: XeerpeValue) -> XeerpeEffect {
        .shader("scan", claims: ["scan"], inputs: progress.inputs) { ctx in
            let p = progress.value(in: ctx)
            return .color(ShaderLibrary.bundle(.module).scan(.boundingRect, .float(p)), enabled: p > 0)
        }
    }
}
```
