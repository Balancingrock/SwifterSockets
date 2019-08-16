// swift-tools-version:5.0

import PackageDescription

let package = Package(
    name: "SwifterSockets",
    products: [
        .library(
            name: "SwifterSockets", targets: ["SwifterSockets"])
    ],
    dependencies: [
        .package(url: "https://github.com/Balancingrock/BRUtils", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SwifterSockets",
            dependencies: ["BRUtils"]
        )
    ]
)
