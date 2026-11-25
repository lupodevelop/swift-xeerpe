<p align="center"><img src="Site/public/logos/xeerpe-swift.png" alt="xeerpe" width="128" height="128"></p>

# xeerpe

Chainable visual effects for SwiftUI, drawn with Metal shaders. Effects take
signals (time, pointer, tilt, a binding, the progress of an async job), so
they move only when something they read changes.

## Requirements

- Xcode 26 (Swift 6.2) or newer
- iOS 17, macOS 14, tvOS 17, watchOS 10, visionOS 26

## Install

```swift
.package(url: "https://github.com/lupodevelop/swift-xeerpe.git", from: "0.1.0")
```

and add `"xeerpe"` to your target's dependencies.

## Use

A chain is a list of effects applied to a view:

```swift
import xeerpe

card.xeerpe {
    .preset(.midnight, reacting: .tilt)
    .scale(.press(from: 1, to: 0.96))
    .feedback(.impact, sound: .pop, on: .press)
}

photo.xeerpe(.film())
photo.xeerpe(.film().without(.lightLeak))
```

Any value can be a signal:

```swift
bar.xeerpe { .glow(.orange, radius: .binding($volume).mapped(to: 0, 14)) }
```

Your own Metal shader becomes an effect that chains like the built-in ones:

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

## Showcase

A macOS app with every effect in context, grouped by use (payments,
messaging, privacy, photo and more), each with the code that makes it:

```sh
swift run xeerpe-preview
```

## License

MIT. See [LICENSE](LICENSE).
