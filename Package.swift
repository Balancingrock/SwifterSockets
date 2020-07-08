// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SwifterSockets",
    platforms: [.macOS(.v10_12), .iOS(.v8)],
    products: [.library(name: "SwifterSockets", targets: ["SwifterSockets"])],
    dependencies: [],
    targets: [.target(name: "SwifterSockets")],
    swiftLanguageVersions: [.v4, .v4_2, .v5]
)
