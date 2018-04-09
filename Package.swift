// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "SwifterSockets",
    products: [
        .library(
            name: "SwifterSockets", targets: ["SwifterSockets"])
    ],
    dependencies: [
        .package(url: "https://github.com/Balancingrock/BRUtils", from: "0.11.1")
    ],
    targets: [
        .target(
            name: "SwifterSockets",
            dependencies: ["BRUtils"]
        )
    ]
)
