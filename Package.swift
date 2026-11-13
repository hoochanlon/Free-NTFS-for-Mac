// swift-tools-version: 6.0
import PackageDescription

let homebrewPrefix = "/opt/homebrew"
let homebrewInclude = "\(homebrewPrefix)/include"
let ntfsStatic = "\(homebrewPrefix)/lib/libntfs-3g.a"
let intlStatic = "\(homebrewPrefix)/opt/gettext/lib/libintl.a"

let package = Package(
    name: "Nigate",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Nigate", targets: ["Nigate"]),
        .executable(name: "NigateFSKitExtension", targets: ["NigateFSKitExtension"]),
        .library(name: "NigateFSKitCore", targets: ["NigateFSKitCore"]),
        .library(name: "NigateNTFSEngine", targets: ["NigateNTFSEngine"])
    ],
    targets: [
        .target(
            name: "NigateFSKitCore",
            path: "macos/Sources/NigateFSKitCore"
        ),
        .target(
            name: "NigateNTFSEngine",
            path: "macos/Sources/NigateNTFSEngine",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags([
                    "-I\(homebrewInclude)"
                ])
            ]
        ),
        .executableTarget(
            name: "NigateFSKitExtension",
            dependencies: [
                "NigateFSKitCore",
                "NigateNTFSEngine"
            ],
            path: "macos/Sources/NigateFSKitExtension",
            exclude: [
                "NigateFSKitExtension.entitlements",
                "NigateFSKitExtension-local.entitlements",
                "NigateFSKitExtension-Bridging-Header.h"
            ],
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedFramework("FSKit"),
                .linkedFramework("CoreFoundation"),
                .linkedLibrary("iconv"),
                .unsafeFlags([
                    ntfsStatic,
                    intlStatic
                ])
            ]
        ),
        .executableTarget(
            name: "Nigate",
            dependencies: ["NigateFSKitCore"],
            path: "macos/Sources/Nigate",
            exclude: [
                "Nigate.entitlements"
            ],
            resources: [
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/AppIcon-white.icns"),
                .copy("Resources/avatar.svg"),
                .copy("Resources/Locales"),
                .copy("Resources/Help")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("DiskArbitration"),
                .linkedFramework("IOKit"),
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("FSKit")
            ]
        ),
        .testTarget(
            name: "NigateTests",
            dependencies: ["Nigate", "NigateFSKitCore"],
            path: "Tests/NigateTests"
        )
    ]
)
