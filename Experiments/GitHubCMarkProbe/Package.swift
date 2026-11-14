// swift-tools-version: 6.4
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(name: "GitHubCMarkProbe", products: [.executable(name: "github-cmark-probe", targets: ["github-cmark-probe"])], targets: [
    .target(name: "GitHubCMark", path: "Vendor", exclude: ["COPYING", "UPSTREAM_SHA256.json", "src/main.c", "src/case_fold_switch.inc", "src/entities.inc", "src/CMakeLists.txt", "src/scanners.re", "src/libcmark-gfm.pc.in", "src/config.h.in", "src/cmark-gfm_version.h.in", "extensions/CMakeLists.txt", "extensions/ext_scanners.re"], sources: ["src", "extensions"], publicHeadersPath: "include", cSettings: [.headerSearchPath("src"), .headerSearchPath("extensions"), .headerSearchPath("generated"), .define("CMARK_GFM_STATIC_DEFINE"), .define("CMARK_GFM_EXTENSIONS_STATIC_DEFINE")]),
    .executableTarget(name: "github-cmark-probe", dependencies: ["GitHubCMark"])
], swiftLanguageModes: [.v6])
