// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AxeneMailer",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(name: "AxeneMailer", targets: ["AxeneMailer"])
    ],
    targets: [
        .target(name: "AxeneMailer"),
        .testTarget(
            name: "AxeneMailerTests",
            dependencies: ["AxeneMailer"]
        )
    ]
)
