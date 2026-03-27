// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pasty",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "Pasty",
            path: "Pasty",
            exclude: ["Info.plist", "Pasty.entitlements"]
        )
    ]
)
