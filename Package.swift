// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "OutputTray", platforms: [.macOS(.v14)], products: [.executable(name: "OutputTray", targets: ["OutputTray"])], targets: [.executableTarget(name: "OutputTray"), .testTarget(name: "OutputTrayTests", dependencies: ["OutputTray"])])
