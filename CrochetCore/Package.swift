// swift-tools-version: 6.2

// 編み図エンジン CrochetCore のパッケージ定義（package.json に相当）。
// 方針は docs/tech-spec.md 4-1 を参照。
// - SwiftUI / UIKit / SwiftData は import しない（Foundation と CoreGraphics は可）
// - Swift 6 言語モード
// - platforms に macOS も書くのは、Mac 上で `swift test` を通すため（アプリは iOS 専用）

import PackageDescription

let package = Package(
    name: "CrochetCore",
    platforms: [
        .iOS("26.0"),
        .macOS("26.0"),
    ],
    products: [
        .library(name: "CrochetCore", targets: ["CrochetCore"]),
    ],
    targets: [
        .target(name: "CrochetCore"),
        .testTarget(name: "CrochetCoreTests", dependencies: ["CrochetCore"]),
    ],
    swiftLanguageModes: [.v6]
)
