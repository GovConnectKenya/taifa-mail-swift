// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TaifaMailSDK",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(name: "TaifaMailSDK", targets: ["TaifaMailSDK"])
    ],
    targets: [
        .target(name: "TaifaMailSDK"),
        .testTarget(
            name: "TaifaMailSDKTests",
            dependencies: ["TaifaMailSDK"]
        )
    ]
)
