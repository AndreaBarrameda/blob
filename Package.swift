// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VirtualAssistant",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "VirtualAssistant",
            dependencies: [],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/VirtualAssistant/Info.plist"
                ])
            ]
        )
    ]
)
