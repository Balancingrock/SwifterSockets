import PackageDescription

let package = Package(
    name: "SwifterSockets",
    dependencies: [
        .Package(url: "../BRUtils", Version(0, 3, 0))
    ]
)
