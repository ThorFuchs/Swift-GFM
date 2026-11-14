// SPDX-License-Identifier: Apache-2.0

import Foundation
import cmark_gfm
import cmark_gfm_extensions
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

// Research-only process: all C registry use is single-threaded. This executable
// is not a library API and has not been qualified for concurrent invocation.
let args = CommandLine.arguments.dropFirst()
guard let mode = args.first, ["commonmark", "gfm", "xml-commonmark", "xml-gfm"].contains(mode), args.count == 1 else {
    FileHandle.standardError.write(Data("usage: cmark-probe commonmark|gfm|xml-commonmark|xml-gfm\n".utf8))
    exit(2)
}
let useGFM = mode.hasSuffix("gfm")
let xml = mode.hasPrefix("xml-")
let input = FileHandle.standardInput.readDataToEndOfFile()
let bytes = Array(input) + [0]
cmark_gfm_core_extensions_ensure_registered()
guard let parser = cmark_parser_new(CMARK_OPT_SOURCEPOS) else {
    FileHandle.standardError.write(Data("failed to allocate parser\n".utf8))
    exit(2)
}
defer { cmark_parser_free(parser) }
if useGFM {
    for name in ["table", "strikethrough", "tasklist", "autolink", "tagfilter"] {
        guard let ext = cmark_find_syntax_extension(name), cmark_parser_attach_syntax_extension(parser, ext) != 0 else {
            FileHandle.standardError.write(Data("failed to attach \(name)\n".utf8))
            exit(2)
        }
    }
}
bytes.withUnsafeBufferPointer { buffer in
    buffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
        cmark_parser_feed(parser, $0, input.count)
    }
}
guard let root = cmark_parser_finish(parser) else {
    FileHandle.standardError.write(Data("failed to finish parser\n".utf8))
    exit(2)
}
defer { cmark_node_free(root) }
let output = xml ? cmark_render_xml(root, CMARK_OPT_SOURCEPOS) : cmark_render_html(root, CMARK_OPT_UNSAFE, cmark_parser_get_syntax_extensions(parser))
guard let output else {
    FileHandle.standardError.write(Data("failed to render document\n".utf8))
    exit(2)
}
defer { free(output) }
FileHandle.standardOutput.write(Data(bytes: output, count: strlen(output)))
