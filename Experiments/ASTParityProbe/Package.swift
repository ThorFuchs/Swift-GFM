// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "ASTParityProbe", dependencies: [.package(path: "../..")], targets: [
    .executableTarget(name: "ASTParityProbe", dependencies: [.product(name: "SwiftGFM", package: "Swift-GFM")])
], swiftLanguageModes: [.v6])
