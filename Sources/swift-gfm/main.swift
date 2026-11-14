// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftGFM

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Android)
import Android
#elseif canImport(WASILibc)
import WASILibc
#elseif canImport(ucrt)
import ucrt
#endif

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(2)
}
var args = Array(CommandLine.arguments.dropFirst())
let usage = "usage: swift-gfm {html|xml|commonmark|plaintext|latex|man} [options] [-e extension] [file ...]"
guard !args.isEmpty else { fail(usage) }
let name = args.removeFirst()
if name == "--version" || name == "-V" {
    print("cmark-gfm \(MarkdownEngine.backendVersion) (\(MarkdownEngine.backendRevision))")
    exit(0)
}
let format: MarkdownOutputFormat
switch name {
case "html": format = .html
case "xml": format = .xml
case "commonmark": format = .commonMark
case "plaintext": format = .plainText
case "latex": format = .latex
case "man": format = .man
case "--help", "-h":
    print(usage)
    print("       swift-gfm --version | --help")
    print("Reads UTF-8 Markdown from the files in order, or from standard input when no file")
    print("is given or a file is '-'. Default: cmark options and no extensions.")
    print("Options: --unsafe --sourcepos --hardbreaks --nobreaks --smart --validate-utf8")
    print("         --github-pre-lang --liberal-html-tag --strikethrough-double-tilde")
    print("         --table-prefer-style-attributes --full-info-string --width N")
    print("Extensions: table strikethrough autolink tagfilter tasklist footnotes")
    exit(0)
default: fail("unknown output format: \(name)")
}
var config = MarkdownConfiguration.cmarkDefault
var files: [String] = []
while !args.isEmpty {
    let arg = args.removeFirst()
    switch arg {
    case "-e", "--extension":
        guard !args.isEmpty else { fail("missing extension name") }
        switch args.removeFirst() {
        case "table": config.extensions.insert(.table)
        case "strikethrough": config.extensions.insert(.strikethrough)
        case "autolink": config.extensions.insert(.autolink)
        case "tagfilter": config.extensions.insert(.tagFilter)
        case "tasklist": config.extensions.insert(.taskList)
        case "footnotes": config.options.insert(.footnotes)
        default: fail("unknown extension")
        }
    case "--width":
        guard !args.isEmpty, let value = Int(args.removeFirst()), value >= 0 else { fail("invalid width") }
        config.width = value
    case "--unsafe": config.options.insert(.allowUnsafeHTML)
    case "--sourcepos": config.options.insert(.sourcePositions)
    case "--hardbreaks": config.options.insert(.hardBreaks)
    case "--nobreaks": config.options.insert(.noBreaks)
    case "--smart": config.options.insert(.smartPunctuation)
    case "--validate-utf8": config.options.insert(.validateUTF8)
    case "--github-pre-lang": config.options.insert(.githubPreLanguage)
    case "--liberal-html-tag": config.options.insert(.liberalHTMLTags)
    case "--strikethrough-double-tilde": config.options.insert(.doubleTildeStrikethrough)
    case "--table-prefer-style-attributes": config.options.insert(.tableStyleAttributes)
    case "--full-info-string": config.options.insert(.fullInfoString)
    case "--":
        files.append(contentsOf: args)
        args.removeAll()
    case "-":
        files.append(arg)
    default:
        if arg.hasPrefix("-") { fail("unknown option: \(arg)") }
        files.append(arg)
    }
}
// Like cmark-gfm, concatenate all inputs before parsing them as one document.
var input = Data()
for file in files.isEmpty ? ["-"] : files {
    if file == "-" {
        input.append(FileHandle.standardInput.readDataToEndOfFile())
    } else {
        guard let data = FileManager.default.contents(atPath: file) else { fail("cannot read file: \(file)") }
        input.append(data)
    }
}
guard let source = String(data: input, encoding: .utf8) else { fail("input is not valid UTF-8") }
do {
    let result = try MarkdownEngine(configuration: config).render(source, as: format)
    FileHandle.standardOutput.write(Data(result.utf8))
} catch {
    fail("render failed: \(error)")
}
