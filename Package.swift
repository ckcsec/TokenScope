// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TokenScope",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TokenScope", targets: ["TokenScope"])
    ],
    targets: [
        .executableTarget(
            name: "TokenScope",
            path: "Sources/TokenScope",
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        ),
        .testTarget(
            name: "TokenScopeTests",
            dependencies: ["TokenScope"],
            path: "Tests/TokenScopeTests"
        )
    ]
)
