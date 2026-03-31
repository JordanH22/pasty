// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pasty",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.7.0")
    ],
    targets: [
        .executableTarget(
            name: "Pasty",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Pasty",
            exclude: ["Info.plist", "Pasty.entitlements"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
