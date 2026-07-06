// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "RelayDog",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "RelayDogCore", targets: ["RelayDogCore"]),
        .library(name: "RelayDogApp", targets: ["RelayDogApp"]),
        .executable(name: "relaydogd", targets: ["relaydogd"]),
        .executable(name: "RelayDogMenuBar", targets: ["RelayDogMenuBar"])
    ],
    targets: [
        .target(name: "RelayDogCore"),
        .target(
            name: "RelayDogApp",
            dependencies: ["RelayDogCore"],
            resources: [.process("Resources")]
        ),
        .executableTarget(name: "relaydogd", dependencies: ["RelayDogCore"]),
        .executableTarget(
            name: "RelayDogMenuBar",
            dependencies: ["RelayDogApp"],
            exclude: ["Resources"]
        ),
        .testTarget(name: "RelayDogCoreTests", dependencies: ["RelayDogCore"]),
        .testTarget(name: "RelayDogAppTests", dependencies: ["RelayDogApp", "RelayDogCore"])
    ]
)
