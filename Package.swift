// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "Paper analysis tool",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Paper analysis tool",
            targets: ["Paper analysis tool"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Cocoanetics/DTCoreText.git", from: "1.6.25")
    ],
    targets: [
        .target(
            name: "Paper analysis tool",
            dependencies: ["DTCoreText"]),
        .testTarget(
            name: "Paper analysis toolTests",
            dependencies: ["Paper analysis tool"]),
    ]
) 