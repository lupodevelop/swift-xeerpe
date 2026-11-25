// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "xeerpe",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .tvOS(.v17),
        .visionOS(.v26),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "xeerpe", targets: ["xeerpe"]),
    ],
    targets: [
        .target(name: "xeerpe", resources: [.process("Shaders")]),
        .executableTarget(name: "xeerpe-preview", dependencies: ["xeerpe"], path: "Showcase", resources: [.process("Shaders")]),
        .testTarget(name: "xeerpeTests", dependencies: ["xeerpe"]),
        .testTarget(name: "ShowcaseTests", dependencies: ["xeerpe", "xeerpe-preview"]),
    ]
)
