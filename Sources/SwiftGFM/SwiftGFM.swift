import Foundation
internal import GitHubCMark

#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

/// Output formats directly supported by the pinned cmark-gfm renderer.
public enum MarkdownOutputFormat: String, CaseIterable, Sendable, Hashable {
    /// HTML fragment.
    case html
    /// The backend's native XML serialization of its internal AST, not XHTML.
    case xml
    /// Normalized CommonMark; not a lossless source serializer.
    case commonMark
    /// Plain-text representation produced by cmark.
    case plainText
    /// LaTeX source produced by cmark.
    case latex
    /// Unix manual-page source produced by cmark.
    case man
}

/// Built-in cmark-gfm parser extensions. Footnotes are controlled by `MarkdownOptions`.
public struct MarkdownExtensions: OptionSet, Sendable, Hashable {
    /// The underlying extension bit mask.
    public let rawValue: UInt8
    /// Creates an extension set from its raw bit mask.
    /// Unsupported bits cause parsing and rendering to throw.
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    /// Recognize GFM tables.
    public static let table = Self(rawValue: 1 << 0)
    /// Recognize tilde-delimited strikethrough.
    public static let strikethrough = Self(rawValue: 1 << 1)
    /// Recognize extended URL and email autolinks.
    public static let autolink = Self(rawValue: 1 << 2)
    /// Filter the raw HTML tags identified by the cmark tag-filter extension.
    public static let tagFilter = Self(rawValue: 1 << 3)
    /// Recognize task-list items.
    public static let taskList = Self(rawValue: 1 << 4)
    /// All five built-in GFM extensions; this does not enable footnotes.
    public static let gfm: Self = [.table, .strikethrough, .autolink, .tagFilter, .taskList]
}

/// Direct options of the pinned C library. Some affect parsing, some rendering.
public struct MarkdownOptions: OptionSet, Sendable, Hashable {
    /// The underlying cmark options bit mask.
    public let rawValue: UInt32
    /// Creates options from a cmark bit mask. Unknown option bits pass through.
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    /// Calculate source positions and include them in supported render formats.
    public static let sourcePositions = Self(rawValue: 1 << 1)
    /// Render soft line breaks as hard breaks.
    public static let hardBreaks = Self(rawValue: 1 << 2)
    /// Render soft line breaks as spaces.
    public static let noBreaks = Self(rawValue: 1 << 4)
    /// Ask cmark to validate input UTF-8. The Swift API already accepts valid Swift strings.
    public static let validateUTF8 = Self(rawValue: 1 << 9)
    /// Enable cmark's smart quotation marks, dashes, and punctuation.
    public static let smartPunctuation = Self(rawValue: 1 << 10)
    /// Use GitHub-style `<pre lang>` output for code blocks.
    public static let githubPreLanguage = Self(rawValue: 1 << 11)
    /// Allow cmark's more permissive interpretation of inline HTML tags.
    public static let liberalHTMLTags = Self(rawValue: 1 << 12)
    /// Enable cmark's footnote parsing option.
    public static let footnotes = Self(rawValue: 1 << 13)
    /// Restrict strikethrough syntax to matching pairs of exactly two tildes.
    public static let doubleTildeStrikethrough = Self(rawValue: 1 << 14)
    /// Use HTML style attributes rather than alignment attributes for tables.
    public static let tableStyleAttributes = Self(rawValue: 1 << 15)
    /// Include the remaining code-fence info string in a separate HTML attribute.
    public static let fullInfoString = Self(rawValue: 1 << 16)
    /// Render raw HTML and otherwise filtered unsafe links. This is not sanitization.
    public static let allowUnsafeHTML = Self(rawValue: 1 << 17)
}

/// Exact backend configuration. A wrap width of zero means no wrapping.
public struct MarkdownConfiguration: Sendable, Hashable {
    /// Built-in extensions to attach to the parser.
    public var extensions: MarkdownExtensions
    /// Options passed to the parser and renderer.
    public var options: MarkdownOptions
    /// Renderer wrap width; zero disables wrapping. Must fit in a nonnegative `Int32`.
    public var width: Int
    /// Creates a configuration. Defaults match cmark's zero-extension settings.
    public init(extensions: MarkdownExtensions = [], options: MarkdownOptions = [], width: Int = 0) {
        self.extensions = extensions
        self.options = options
        self.width = width
    }
    /// The C library's default settings: no extensions, safe HTML, no wrapping.
    public static let cmarkDefault = Self()
    /// GFM-related built-in extensions, with the C library's default HTML policy.
    public static let gfm = Self(extensions: .gfm)
}

/// An error reported by the Swift wrapper or its cmark backend.
public enum MarkdownEngineError: Error, Sendable, Equatable {
    /// The requested width is negative or exceeds `Int32.max`.
    case invalidWidth(Int)
    /// The extension mask contains bits not supported by the pinned backend.
    case unsupportedExtensions(UInt8)
    /// The backend failed to create a parser.
    case parserUnavailable
    /// A named backend extension could not be found or attached.
    case extensionUnavailable(String)
    /// The backend did not return a parsed root node.
    case parseFailed
    /// The backend did not return rendered output.
    case renderFailed
    /// The backend returned rendered bytes that were not valid UTF-8.
    case invalidUTF8Output
    /// A backend node has no supported Swift projection.
    case unsupportedASTNode(name: String, type: Int32)
    /// The backend returned an unexpected value for a node.
    case invalidASTNode(String)
    /// A string exposed by a backend node was not valid UTF-8.
    case invalidUTF8ASTNode(String)
}

/// A value facade over the pinned GitHub cmark-gfm backend.
/// Calls through this module are serialized because the backend has global state.
public struct MarkdownEngine: Sendable {
    /// Git commit of the vendored GitHub cmark-gfm source.
    public static let backendRevision = "27d942c8b0a62d192f616e5bf3578f4b6a89e180"
    private static let gate = NSLock()
    /// The configuration used for every operation on this engine.
    public let configuration: MarkdownConfiguration
    /// Creates an engine. The default enables the built-in GFM extensions.
    public init(configuration: MarkdownConfiguration = .gfm) { self.configuration = configuration }

    /// Runtime version string reported by the vendored C library.
    public static var backendVersion: String {
        gate.withLock { String(cString: swiftgfm_cmark_version_string()) }
    }

    /// Render using the exact requested C options and extensions.
    ///
    /// All wrapper calls are serialized within this module. The XML format is
    /// cmark-gfm's native AST serialization; use `.sourcePositions` to request
    /// positions. Calls bypassing this wrapper are outside its safety boundary.
    ///
    /// - Parameters:
    ///   - source: Markdown input as a Swift string.
    ///   - format: The backend renderer to use; defaults to HTML.
    /// - Returns: The backend's rendered UTF-8 output as a Swift string.
    /// - Throws: ``MarkdownEngineError`` if configuration or backend execution fails.
    public func render(_ source: String, as format: MarkdownOutputFormat = .html) throws -> String {
        try withParsedRoot(source) { parser, root, flags, width in
            let output: UnsafeMutablePointer<CChar>?
            switch format {
            case .html:
                output = swiftgfm_cmark_render_html(root, flags, swiftgfm_cmark_parser_get_syntax_extensions(parser))
            case .xml: output = swiftgfm_cmark_render_xml(root, flags)
            case .commonMark: output = swiftgfm_cmark_render_commonmark(root, flags, width)
            case .plainText: output = swiftgfm_cmark_render_plaintext(root, flags, width)
            case .latex: output = swiftgfm_cmark_render_latex(root, flags, width)
            case .man: output = swiftgfm_cmark_render_man(root, flags, width)
            }
            guard let output else { throw MarkdownEngineError.renderFailed }
            defer { free(output) }
            guard let result = String(validatingCString: output) else { throw MarkdownEngineError.invalidUTF8Output }
            return result
        }
    }

    /// Parse into an independently owned, read-only Swift tree.
    ///
    /// Enable `.sourcePositions` to include backend source ranges. The AST is a
    /// projection, not a lossless source serializer.
    ///
    /// - Parameter source: Markdown input retained in the returned document.
    /// - Returns: A read-only Swift snapshot of the configured cmark parse.
    /// - Throws: ``MarkdownEngineError`` if configuration, parsing, or projection fails.
    public func parse(_ source: String) throws -> MarkdownDocument {
        try withParsedRoot(source) { _, root, _, _ in
            let tree = try copyMarkdownTree(
                root, includeSourcePositions: configuration.options.contains(.sourcePositions))
            return MarkdownDocument(source: source, configuration: configuration, root: tree)
        }
    }

    private func withParsedRoot<T>(_ source: String, _ body: (OpaquePointer, OpaquePointer, Int32, Int32) throws -> T)
        throws -> T
    {
        guard configuration.width >= 0, let width = Int32(exactly: configuration.width) else {
            throw MarkdownEngineError.invalidWidth(configuration.width)
        }
        let unknown = configuration.extensions.rawValue & ~MarkdownExtensions.gfm.rawValue
        guard unknown == 0 else { throw MarkdownEngineError.unsupportedExtensions(unknown) }
        return try Self.gate.withLock {
            let flags = Int32(bitPattern: configuration.options.rawValue)
            swiftgfm_cmark_gfm_core_extensions_ensure_registered()
            guard let parser = swiftgfm_cmark_parser_new(flags) else { throw MarkdownEngineError.parserUnavailable }
            defer { swiftgfm_cmark_parser_free(parser) }
            let names: [(MarkdownExtensions, String)] = [
                (.table, "table"), (.strikethrough, "strikethrough"), (.autolink, "autolink"),
                (.tagFilter, "tagfilter"), (.taskList, "tasklist"),
            ]
            for (ext, name) in names where configuration.extensions.contains(ext) {
                guard let pointer = swiftgfm_cmark_find_syntax_extension(name),
                    swiftgfm_cmark_parser_attach_syntax_extension(parser, pointer) != 0
                else {
                    throw MarkdownEngineError.extensionUnavailable(name)
                }
            }
            let bytes = Array(source.utf8) + [0]
            bytes.withUnsafeBufferPointer { buffer in
                buffer.baseAddress!.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
                    swiftgfm_cmark_parser_feed(parser, $0, buffer.count - 1)
                }
            }
            guard let root = swiftgfm_cmark_parser_finish(parser) else { throw MarkdownEngineError.parseFailed }
            defer { swiftgfm_cmark_node_free(root) }
            return try body(parser, root, flags, width)
        }
    }

}
