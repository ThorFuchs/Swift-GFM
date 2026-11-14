// SPDX-License-Identifier: Apache-2.0

import Foundation
import GitHubCMark
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

// Experimental CLI only: one parse per process. Not a concurrent library API.
func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}
var arguments = Array(CommandLine.arguments.dropFirst())
guard !arguments.isEmpty else { fail("usage: github-cmark-probe FORMAT [options] [-e extension]") }
let format = arguments.removeFirst()
let formats = ["html", "xml", "commonmark", "plaintext", "latex", "man"]
guard formats.contains(format) else { fail("unknown format") }
var options: Int32 = CMARK_OPT_DEFAULT
var width: Int32 = 0
var extensions: [String] = []
while !arguments.isEmpty {
    let arg = arguments.removeFirst()
    switch arg {
    case "-e":
        guard !arguments.isEmpty else { fail("missing extension") }
        let name = arguments.removeFirst()
        if name == "footnotes" { options |= CMARK_OPT_FOOTNOTES } else { extensions.append(name) }
    case "--width":
        guard !arguments.isEmpty, let value = Int32(arguments.removeFirst()) else { fail("invalid width") }
        width = value
    case "--unsafe": options |= CMARK_OPT_UNSAFE
    case "--sourcepos": options |= CMARK_OPT_SOURCEPOS
    case "--hardbreaks": options |= CMARK_OPT_HARDBREAKS
    case "--nobreaks": options |= CMARK_OPT_NOBREAKS
    case "--smart": options |= CMARK_OPT_SMART
    case "--validate-utf8": options |= CMARK_OPT_VALIDATE_UTF8
    case "--github-pre-lang": options |= CMARK_OPT_GITHUB_PRE_LANG
    case "--liberal-html-tag": options |= CMARK_OPT_LIBERAL_HTML_TAG
    case "--strikethrough-double-tilde": options |= CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE
    case "--table-prefer-style-attributes": options |= CMARK_OPT_TABLE_PREFER_STYLE_ATTRIBUTES
    case "--full-info-string": options |= CMARK_OPT_FULL_INFO_STRING
    default: fail("unknown option \(arg)")
    }
}
cmark_gfm_core_extensions_ensure_registered()
guard let parser = cmark_parser_new(options) else { fail("could not allocate parser") }
defer { cmark_parser_free(parser) }
for name in extensions {
    guard let ext = cmark_find_syntax_extension(name), cmark_parser_attach_syntax_extension(parser, ext) != 0 else { fail("unknown or unavailable extension: \(name)") }
}
let input = FileHandle.standardInput.readDataToEndOfFile()
let bytes = Array(input) + [0]
bytes.withUnsafeBufferPointer { buffer in
    buffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
        cmark_parser_feed(parser, $0, input.count)
    }
}
guard let root = cmark_parser_finish(parser) else { fail("could not finish parsing") }
defer { cmark_node_free(root) }
let output: UnsafeMutablePointer<CChar>?
switch format {
case "html": output = cmark_render_html(root, options, cmark_parser_get_syntax_extensions(parser))
case "xml": output = cmark_render_xml(root, options)
case "commonmark": output = cmark_render_commonmark(root, options, width)
case "plaintext": output = cmark_render_plaintext(root, options, width)
case "latex": output = cmark_render_latex(root, options, width)
case "man": output = cmark_render_man(root, options, width)
default: fail("unknown format")
}
guard let output else { fail("render failed") }
defer { free(output) }
FileHandle.standardOutput.write(Data(bytes: output, count: strlen(output)))
