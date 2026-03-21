// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AmonKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(name: "AmonKit", targets: ["AmonKit"])
    ],
    targets: [
        .target(
            name: "AmonKit",
            path: "Sources/AmonKit"
        ),
        .testTarget(
            name: "AmonKitTests",
            dependencies: ["AmonKit"],
            path: "Tests/AmonKitTests"
        )
    ]
)
