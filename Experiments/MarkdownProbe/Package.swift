// swift-tools-version: 6.4
import PackageDescription
let package = Package(name: "MarkdownProbe", products: [.executable(name: "markdown-probe", targets: ["markdown-probe"])], dependencies: [.package(url: "https://github.com/swiftlang/swift-markdown.git", revision: "ea1d88be47afe8a731b3971d7b3fb7a3a6db1a5a")], targets: [.executableTarget(name: "markdown-probe", dependencies: [.product(name: "Markdown", package: "swift-markdown")])], swiftLanguageModes: [.v6])
