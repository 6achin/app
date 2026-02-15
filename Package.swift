// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BusinessAccountingApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "BusinessAccountingApp", targets: ["BusinessAccountingApp"])
    ],
    targets: [
        .executableTarget(
            name: "BusinessAccountingApp",
            path: "Sources"
        )
    ]
)
