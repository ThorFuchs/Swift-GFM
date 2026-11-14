// SPDX-License-Identifier: Apache-2.0

import Foundation
import Dispatch
import cmark_gfm
import cmark_gfm_extensions
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

// Diagnostic only: each invocation owns all C allocations on the calling thread.
func render(_ source: String, useGFM: Bool) -> String? {
    cmark_gfm_core_extensions_ensure_registered()
    guard let parser = cmark_parser_new(CMARK_OPT_DEFAULT) else { return nil }
    defer { cmark_parser_free(parser) }
    if useGFM {
        for name in ["table", "strikethrough", "tasklist", "autolink", "tagfilter"] {
            guard let ext = cmark_find_syntax_extension(name), cmark_parser_attach_syntax_extension(parser, ext) != 0 else { return nil }
        }
    }
    let bytes = Array(source.utf8) + [0]
    bytes.withUnsafeBufferPointer { buffer in
        buffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
            cmark_parser_feed(parser, $0, buffer.count - 1)
        }
    }
    guard let root = cmark_parser_finish(parser) else { return nil }
    defer { cmark_node_free(root) }
    guard let output = cmark_render_html(root, CMARK_OPT_UNSAFE, cmark_parser_get_syntax_extensions(parser)) else { return nil }
    defer { free(output) }
    return String(cString: output)
}

final class Results: @unchecked Sendable {
    private let lock = NSLock()
    private var failures = 0
    func recordFailure() { lock.lock(); failures += 1; lock.unlock() }
    func count() -> Int { lock.lock(); defer { lock.unlock() }; return failures }
}
let results = Results()
let iterations = 2_000
DispatchQueue.concurrentPerform(iterations: iterations) { index in
    let gfm = index % 2 == 1
    let source = gfm ? "~~x~~\n" : "*x*\n"
    let expected = gfm ? "<p><del>x</del></p>\n" : "<p><em>x</em></p>\n"
    if render(source, useGFM: gfm) != expected { results.recordFailure() }
}
let count = results.count()
print("Concurrent independent parses: \(iterations), failures: \(count)")
if count != 0 { exit(1) }
