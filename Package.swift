// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Speaklet",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "WhisperBubble", targets: ["WhisperBubble"])],
    targets: [
        .target(name: "WhisperCore"),
        .target(name: "WhisperMacSupport", dependencies: ["WhisperCore"]),
        .executableTarget(name: "WhisperBubble", dependencies: ["WhisperCore", "WhisperMacSupport"]),
        .executableTarget(name: "WhisperCoreChecks", dependencies: ["WhisperCore"], path: "Tests/WhisperCoreTests"),
        .executableTarget(name: "WhisperNativeChecks", dependencies: ["WhisperMacSupport"], path: "Tests/WhisperNativeChecks"),
        .executableTarget(name: "WhisperAccessibilityChecks", dependencies: ["WhisperCore", "WhisperMacSupport"], path: "Tests/WhisperAccessibilityChecks"),
        .executableTarget(name: "WhisperAppearancePreview", dependencies: ["WhisperMacSupport"], path: "scripts/AppearancePreview")
    ],
    swiftLanguageVersions: [.v5]
)
