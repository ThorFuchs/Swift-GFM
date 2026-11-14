// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(name: "CoexistenceProbe", dependencies: [
    .package(path: "../.."),
    .package(url: "https://github.com/swiftlang/swift-markdown.git", revision: "ea1d88be47afe8a731b3971d7b3fb7a3a6db1a5a")
], targets: [.executableTarget(name: "CoexistenceProbe", dependencies: [
    .product(name: "SwiftGFM", package: "Swift-GFM"),
    .product(name: "Markdown", package: "swift-markdown")
])], swiftLanguageModes: [.v6])
