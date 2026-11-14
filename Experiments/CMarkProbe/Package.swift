// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "CMarkProbe",
    products: [.executable(name: "cmark-probe", targets: ["cmark-probe"]), .executable(name: "cmark-stress", targets: ["cmark-stress"])],
    dependencies: [.package(url: "https://github.com/swiftlang/swift-cmark.git", revision: "437611671145d47e6d9679761b8a5987766f4ae5")],
    targets: [.executableTarget(name: "cmark-probe", dependencies: [
        .product(name: "cmark-gfm", package: "swift-cmark"),
        .product(name: "cmark-gfm-extensions", package: "swift-cmark")
    ]), .executableTarget(name: "cmark-stress", dependencies: [
        .product(name: "cmark-gfm", package: "swift-cmark"),
        .product(name: "cmark-gfm-extensions", package: "swift-cmark")
    ])], swiftLanguageModes: [.v6]
)
