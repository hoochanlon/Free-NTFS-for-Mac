// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Nigate",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Nigate", targets: ["Nigate"]),
        .executable(name: "NigateFSKitExtension", targets: ["NigateFSKitExtension"]),
        .library(name: "NigateFSKitCore", targets: ["NigateFSKitCore"])
    ],
    targets: [
        .target(
            name: "NigateFSKitCore",
            path: "macos/Sources/NigateFSKitCore"
        ),
        .executableTarget(
            name: "NigateFSKitExtension",
            dependencies: ["NigateFSKitCore"],
            path: "macos/Sources/NigateFSKitExtension",
            exclude: [
                "NigateFSKitExtension.entitlements"
            ],
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedFramework("FSKit")
            ]
        ),
        .executableTarget(
            name: "Nigate",
            dependencies: ["NigateFSKitCore"],
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
            dependencies: ["Nigate", "NigateFSKitCore"],
            path: "Tests/NigateTests"
        )
    ]
)
