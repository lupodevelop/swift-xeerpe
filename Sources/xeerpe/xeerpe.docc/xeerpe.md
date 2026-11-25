# ``xeerpe``

Chainable visual effects for SwiftUI, drawn with Metal shaders.

## Overview

A chain is a list of effects applied to a view. Effects take signals (time,
pointer, tilt, a binding, the progress of an async job), so they move only
when something they read changes.

```swift
import xeerpe

card.xeerpe {
    .preset(.midnight, reacting: .tilt)
    .scale(.press(from: 1, to: 0.96))
    .feedback(.impact, sound: .pop, on: .press)
}
```

Every effect is a static function on ``XeerpeEffect`` and a method of the
same name on ``XeerpeChain``, so effects can be listed in a builder or
chained one after the other.

## Topics

### Essentials

- <doc:GettingStarted>
- ``XeerpeChain``
- ``XeerpeEffect``
- ``XeerpeBuilder``

### Signals

- ``XeerpeSignal``
- ``XeerpeValue``
- ``XeerpeVector``
- ``XeerpeValueConvertible``
- ``XeerpeMixable``
- ``XeerpeContext``
- ``XeerpeInput``
- ``XeerpeWave``
- ``XeerpeTrigger``
- ``XeerpeTap``

### Asynchronous work

- ``XeerpeJob``
- ``XeerpePhase``

### Looks and palettes

- ``XeerpePreset``
- ``XeerpePalette``
- ``XeerpeGradient``
- ``XeerpeStop``
- ``XeerpeGlow``
- ``XeerpeGlass``
- ``XeerpeCatalog``
- ``XeerpeCategory``
- ``XeerpeLayer``

### Transitions and reveals

- ``XeerpeTransition``
- ``XeerpeReveal``
- ``XeerpeGenieTransition``
- ``XeerpeTextRise``
- ``XeerpeEdge``

### Motion, sound and haptics

- ``XeerpeMotion``
- ``XeerpeSound``

### Your own shaders

- ``XeerpeShaderPass``
- ``XeerpeSlot``
- ``XeerpeProperty``

### Shapes

- ``Superellipse``
- ``XeerpeShapeSignal``
