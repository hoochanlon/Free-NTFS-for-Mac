// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nigate",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Nigate", targets: ["Nigate"])
    ],
    targets: [
        .executableTarget(
            name: "Nigate",
            path: "macos/Sources/Nigate",
            exclude: [
                "Resources/AppIcon-white.icns"
            ],
            resources: [
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/Locales"),
                .copy("Resources/Help")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("DiskArbitration"),
                .linkedFramework("IOKit"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement")
            ]
        ),
        .testTarget(
            name: "NigateTests",
            dependencies: ["Nigate"],
            path: "Tests/NigateTests"
        )
    ]
)
