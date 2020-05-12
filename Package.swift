// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SwifterSockets",
    products: [
        .library(
            name: "SwifterSockets", targets: ["SwifterSockets"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SwifterSockets"
        )
    ]
)
