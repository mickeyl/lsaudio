// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "lsaudio",
    platforms: [
        // The CoreAudio process object API (kAudioHardwarePropertyProcessObjectList) requires macOS 14.
        .macOS(.v14),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "lsaudio",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
