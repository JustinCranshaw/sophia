// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Sophia",
    platforms: [.macOS(.v14)],
    targets: [
        // Notebook files, record checks, and the Claude Code process. No UI.
        .target(name: "SophiaCore"),
        .target(name: "SophiaReader", resources: [.copy("Reader")]),
        // The Mac app.
        .executableTarget(name: "Sophia", dependencies: ["SophiaCore", "SophiaReader"]),
        // Sophia's notebook tools, served to Claude Code over stdio.
        .executableTarget(name: "sophia-mcp", dependencies: ["SophiaCore"]),
        // Checks for SophiaCore; runs without Xcode: swift run sophia-checks
        .executableTarget(name: "sophia-checks", dependencies: ["SophiaCore"]),
        .executableTarget(name: "sophia-reader-checks", dependencies: ["SophiaReader"], resources: [.copy("Fixtures")]),
    ]
)
