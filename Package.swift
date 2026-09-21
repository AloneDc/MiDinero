// swift-tools-version: 5.9
import PackageDescription

// Foundation-only logic can also be tested without an iOS simulator.
let package = Package(
    name: "MiDineroCore",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "MiDineroCore", targets: ["MiDineroCore"])],
    targets: [
        .target(name: "MiDineroCore", path: "MiDinero",
                exclude: ["App", "Features", "Intents", "Persistence", "Resources"],
                sources: ["Domain", "Services"]),
        .testTarget(name: "MiDineroCoreTests", dependencies: ["MiDineroCore"], path: "MiDineroTests/Core")
    ]
)
