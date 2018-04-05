import PackageDescription

let package = Package(
    name: "SwifterSockets",
    dependencies: [
        .Package(url: "https://github.com/Balancingrock/BRUtils", Version(0, 11, 0))
    ]
)
