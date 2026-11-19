// SPDX-License-Identifier: Apache-2.0

import Foundation
internal import GitHubCMark

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
    /// Creates options from a cmark bit mask.
    /// Bits outside ``MarkdownOptions/supported`` cause parsing and rendering to throw.
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
    /// Every option this version of SwiftGFM passes to the backend.
    public static let supported: Self = [
        .sourcePositions, .hardBreaks, .noBreaks, .validateUTF8, .smartPunctuation, .githubPreLanguage,
        .liberalHTMLTags, .footnotes, .doubleTildeStrikethrough, .tableStyleAttributes, .fullInfoString,
        .allowUnsafeHTML,
    ]
}

/// Exact backend configuration. A wrap width of zero means no wrapping.
///
/// Every initializer parameter has a default, and those defaults select the
/// same configuration as ``MarkdownConfiguration/gfm`` and
/// ``MarkdownEngine/init(configuration:)``: the five built-in GFM extensions,
/// the C library's default options, and no wrapping. Pass `extensions: []` or
/// start from ``MarkdownConfiguration/cmarkDefault`` for no extensions.
public struct MarkdownConfiguration: Sendable, Hashable {
    /// Built-in extensions to attach to the parser.
    public var extensions: MarkdownExtensions
    /// Options passed to the parser and renderer.
    public var options: MarkdownOptions
    /// Renderer wrap width; zero disables wrapping. Must fit in a nonnegative `Int32`.
    public var width: Int
    /// Optional input and Swift AST projection limits. Defaults to unlimited.
    public var limits: MarkdownResourceLimits
    /// Creates a configuration with no SwiftGFM-enforced resource limits.
    /// Extensions default to ``MarkdownExtensions/gfm``.
    public init(extensions: MarkdownExtensions = .gfm, options: MarkdownOptions = [], width: Int = 0) {
        self.init(extensions: extensions, options: options, width: width, limits: .unlimited)
    }

    /// Creates a configuration with explicit input and Swift AST projection limits.
    /// Extensions default to ``MarkdownExtensions/gfm``.
    public init(
        extensions: MarkdownExtensions = .gfm, options: MarkdownOptions = [], width: Int = 0,
        limits: MarkdownResourceLimits
    ) {
        self.extensions = extensions
        self.options = options
        self.width = width
        self.limits = limits
    }
    /// The C library's default settings: no extensions, safe HTML, no wrapping.
    public static let cmarkDefault = Self(extensions: [])
    /// GFM-related built-in extensions, with the C library's default HTML policy.
    /// This is also the configuration produced by `MarkdownConfiguration()`.
    public static let gfm = Self(extensions: .gfm)
}

/// An error reported by the Swift wrapper or its cmark backend.
///
/// Inspect ``code`` to distinguish failures, and the optional context
/// properties for details. Future versions may add codes and context
/// properties without a major version change, so code that switches over
/// ``Code`` values needs a `default` case:
///
/// ```swift
/// do {
///     _ = try engine.parse(untrustedInput)
/// } catch let error as MarkdownEngineError where error.code == .resourceLimitExceeded {
///     print("rejected", error.resourceLimit!, error.limit!, error.value!)
/// }
/// ```
public struct MarkdownEngineError: Error, Sendable, Hashable, CustomStringConvertible {
    /// Identifies the kind of failure. Compare with the static members.
    public struct Code: Sendable, Hashable, CustomStringConvertible {
        private enum Value: String, Sendable {
            case invalidWidth, unsupportedExtensions, unsupportedOptions, parserUnavailable, extensionUnavailable,
                parseFailed
            case renderFailed, invalidUTF8Output, invalidResourceLimit, resourceLimitExceeded
            case unsupportedASTNode, invalidASTNode, invalidUTF8ASTNode
        }
        private let value: Value
        private init(_ value: Value) { self.value = value }

        /// The code's stable name, such as `resourceLimitExceeded`.
        public var description: String { value.rawValue }

        /// The configured width is negative or exceeds `Int32.max`; ``MarkdownEngineError/value`` holds it.
        public static let invalidWidth = Self(.invalidWidth)
        /// The extension mask contains bits not supported by the pinned backend;
        /// ``MarkdownEngineError/value`` holds the unsupported bits.
        public static let unsupportedExtensions = Self(.unsupportedExtensions)
        /// The option mask contains bits outside ``MarkdownOptions/supported``;
        /// ``MarkdownEngineError/value`` holds the unsupported bits.
        public static let unsupportedOptions = Self(.unsupportedOptions)
        /// The backend failed to create a parser.
        public static let parserUnavailable = Self(.parserUnavailable)
        /// A named backend extension could not be found or attached;
        /// ``MarkdownEngineError/detail`` holds its backend name.
        public static let extensionUnavailable = Self(.extensionUnavailable)
        /// The backend did not return a parsed root node.
        public static let parseFailed = Self(.parseFailed)
        /// The backend did not return rendered output.
        public static let renderFailed = Self(.renderFailed)
        /// The backend returned rendered bytes that were not valid UTF-8.
        public static let invalidUTF8Output = Self(.invalidUTF8Output)
        /// A resource limit was configured with a negative value; ``MarkdownEngineError/resourceLimit``
        /// identifies it and ``MarkdownEngineError/value`` holds the configured value.
        public static let invalidResourceLimit = Self(.invalidResourceLimit)
        /// An input or Swift AST projection exceeded a limit; ``MarkdownEngineError/resourceLimit``,
        /// ``MarkdownEngineError/limit``, and ``MarkdownEngineError/value`` hold the kind,
        /// configured bound, and observed value.
        public static let resourceLimitExceeded = Self(.resourceLimitExceeded)
        /// A backend node has no supported Swift projection; ``MarkdownEngineError/detail``
        /// holds its backend type name and ``MarkdownEngineError/value`` its backend type code.
        public static let unsupportedASTNode = Self(.unsupportedASTNode)
        /// The backend returned an unexpected value for a node; ``MarkdownEngineError/detail``
        /// describes the context.
        public static let invalidASTNode = Self(.invalidASTNode)
        /// A string exposed by a backend node was not valid UTF-8; ``MarkdownEngineError/detail``
        /// describes the context.
        public static let invalidUTF8ASTNode = Self(.invalidUTF8ASTNode)
    }

    /// The kind of failure.
    public let code: Code
    /// The resource limit involved, for limit-related codes.
    public let resourceLimit: MarkdownResourceLimit?
    /// The configured bound, for ``Code/resourceLimitExceeded``.
    public let limit: Int?
    /// The offending or observed number; each ``Code`` documents its meaning.
    public let value: Int?
    /// A backend name or context description; each ``Code`` documents its meaning.
    public let detail: String?

    private init(
        _ code: Code, resourceLimit: MarkdownResourceLimit? = nil, limit: Int? = nil, value: Int? = nil,
        detail: String? = nil
    ) {
        self.code = code
        self.resourceLimit = resourceLimit
        self.limit = limit
        self.value = value
        self.detail = detail
    }

    /// A human-readable summary of the failure and its context.
    public var description: String {
        var parts = ["MarkdownEngineError.\(code)"]
        if let resourceLimit { parts.append("resource: \(resourceLimit)") }
        if let limit { parts.append("limit: \(limit)") }
        if let value { parts.append("value: \(value)") }
        if let detail { parts.append("detail: \(detail)") }
        return parts.count == 1 ? parts[0] : "\(parts[0]) (\(parts.dropFirst().joined(separator: ", ")))"
    }

    /// An ``Code/invalidWidth`` error for the given width.
    public static func invalidWidth(_ width: Int) -> Self { Self(.invalidWidth, value: width) }
    /// An ``Code/unsupportedExtensions`` error for the given unsupported bits.
    public static func unsupportedExtensions(_ bits: UInt8) -> Self { Self(.unsupportedExtensions, value: Int(bits)) }
    /// An ``Code/unsupportedOptions`` error for the given unsupported bits.
    public static func unsupportedOptions(_ bits: UInt32) -> Self { Self(.unsupportedOptions, value: Int(bits)) }
    /// A ``Code/parserUnavailable`` error.
    public static let parserUnavailable = Self(.parserUnavailable)
    /// An ``Code/extensionUnavailable`` error for the given backend extension name.
    public static func extensionUnavailable(_ name: String) -> Self { Self(.extensionUnavailable, detail: name) }
    /// A ``Code/parseFailed`` error.
    public static let parseFailed = Self(.parseFailed)
    /// A ``Code/renderFailed`` error.
    public static let renderFailed = Self(.renderFailed)
    /// An ``Code/invalidUTF8Output`` error.
    public static let invalidUTF8Output = Self(.invalidUTF8Output)
    /// An ``Code/invalidResourceLimit`` error for a negative configured value.
    public static func invalidResourceLimit(_ resource: MarkdownResourceLimit, value: Int) -> Self {
        Self(.invalidResourceLimit, resourceLimit: resource, value: value)
    }
    /// A ``Code/resourceLimitExceeded`` error with the configured and observed values.
    public static func resourceLimitExceeded(_ resource: MarkdownResourceLimit, limit: Int, actual: Int) -> Self {
        Self(.resourceLimitExceeded, resourceLimit: resource, limit: limit, value: actual)
    }
    /// An ``Code/unsupportedASTNode`` error for a backend node type.
    public static func unsupportedASTNode(name: String, type: Int) -> Self {
        Self(.unsupportedASTNode, value: type, detail: name)
    }
    /// An ``Code/invalidASTNode`` error with a context description.
    public static func invalidASTNode(_ context: String) -> Self { Self(.invalidASTNode, detail: context) }
    /// An ``Code/invalidUTF8ASTNode`` error with a context description.
    public static func invalidUTF8ASTNode(_ context: String) -> Self { Self(.invalidUTF8ASTNode, detail: context) }
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
                root, includeSourcePositions: configuration.options.contains(.sourcePositions),
                limits: configuration.limits)
            return MarkdownDocument(source: source, configuration: configuration, root: tree)
        }
    }

    /// Produce an HTML document stream with opt-in math positions kept separate.
    ///
    /// Inline math uses single dollars on one line; display math uses lines
    /// containing `$$` delimiters. Math is not recognized in tables, code, or image
    /// descriptions. Raw HTML must remain disabled. See the math guide for the
    /// exact delimiter rules and limitations. No caller callback runs under the lock.
    public func renderRecognizingMath(_ source: String) throws -> MarkdownMathDocument {
        guard !configuration.options.contains(.allowUnsafeHTML) else { throw MarkdownMathError.unsafeHTML }
        guard !source.utf8.contains(0) else { throw MarkdownMathError.nulInSource }
        guard source.utf8.count <= Int32.max else { throw MarkdownMathError.parserUnavailable }
        let nonce = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return try withParsedRoot(source, math: true) { parser, root, flags, _, context in
            guard let context else { throw MarkdownMathError.parserUnavailable }
            let status = nonce.withCString { swiftgfm_math_prepare(context, root, $0) }
            if status == 2 { throw MarkdownMathError.unclosedDisplay }
            guard status == 0 else { throw MarkdownMathError.parserUnavailable }
            guard let raw = swiftgfm_cmark_render_html(root, flags, swiftgfm_cmark_parser_get_syntax_extensions(parser))
            else { throw MarkdownEngineError.renderFailed }
            defer { free(raw) }
            let html = Data(bytes: raw, count: strlen(raw))
            var parts: [MarkdownMathPart] = []
            var cursor = html.startIndex
            let prefix = Data("SWIFTGFMMATH\(nonce)Z".utf8)
            for index in 0..<swiftgfm_math_count(context) {
                let marker = Data("SWIFTGFMMATH\(nonce)Z\(index)END".utf8)
                guard let match = html.range(of: prefix, in: cursor..<html.endIndex),
                    html[match.lowerBound...].starts(with: marker),
                    let htmlPart = String(data: html[cursor..<match.lowerBound], encoding: .utf8),
                    let tex = swiftgfm_math_tex(context, index), let original = swiftgfm_math_original(context, index),
                    let literal = String(validatingCString: tex), let fallback = String(validatingCString: original)
                else { throw MarkdownMathError.invalidDocumentStream }
                parts.append(.html(htmlPart))
                parts.append(
                    .math(
                        MarkdownMathOccurrence(
                            index: index, literal: literal, source: fallback,
                            displayMode: swiftgfm_math_display(context, index) != 0)))
                cursor = match.lowerBound + marker.count
            }
            guard html.range(of: prefix, in: cursor..<html.endIndex) == nil,
                let tail = String(data: html[cursor...], encoding: .utf8)
            else {
                throw MarkdownMathError.invalidDocumentStream
            }
            parts.append(.html(tail))
            return MarkdownMathDocument(
                parts: parts, containsTablesWithoutMath: swiftgfm_math_contains_table(context) != 0)
        }
    }

    private func withParsedRoot<T>(_ source: String, _ body: (OpaquePointer, OpaquePointer, Int32, Int32) throws -> T)
        throws -> T
    {
        try withParsedRoot(source, math: false) { parser, root, flags, width, _ in
            try body(parser, root, flags, width)
        }
    }

    private func withParsedRoot<T>(
        _ source: String, math: Bool,
        _ body: (OpaquePointer, OpaquePointer, Int32, Int32, OpaquePointer?) throws -> T
    ) throws -> T {
        guard configuration.width >= 0, let width = Int32(exactly: configuration.width) else {
            throw MarkdownEngineError.invalidWidth(configuration.width)
        }
        let unknown = configuration.extensions.rawValue & ~MarkdownExtensions.gfm.rawValue
        guard unknown == 0 else { throw MarkdownEngineError.unsupportedExtensions(unknown) }
        let unknownOptions = configuration.options.rawValue & ~MarkdownOptions.supported.rawValue
        guard unknownOptions == 0 else { throw MarkdownEngineError.unsupportedOptions(unknownOptions) }
        let configuredLimits: [(MarkdownResourceLimit, Int?)] = [
            (.inputUTF8Bytes, configuration.limits.maximumInputUTF8Bytes),
            (.astNodes, configuration.limits.maximumASTNodes),
            (.astDepth, configuration.limits.maximumASTDepth),
        ]
        for (kind, value) in configuredLimits {
            if let value, value < 0 { throw MarkdownEngineError.invalidResourceLimit(kind, value: value) }
        }
        if let limit = configuration.limits.maximumInputUTF8Bytes {
            let actual = source.utf8.count
            if actual > limit {
                throw MarkdownEngineError.resourceLimitExceeded(.inputUTF8Bytes, limit: limit, actual: actual)
            }
        }
        return try Self.gate.withLock {
            let flags = Int32(bitPattern: configuration.options.rawValue)
            swiftgfm_cmark_gfm_core_extensions_ensure_registered()
            let mathContext = math ? swiftgfm_math_new(source.utf8.count) : nil
            guard !math || mathContext != nil else { throw MarkdownMathError.parserUnavailable }
            defer { if let mathContext { swiftgfm_math_free(mathContext) } }
            guard let parser = swiftgfm_cmark_parser_new(flags) else { throw MarkdownEngineError.parserUnavailable }
            defer { swiftgfm_cmark_parser_free(parser) }
            if let mathContext, swiftgfm_math_attach(mathContext, parser) == 0 {
                throw MarkdownMathError.parserUnavailable
            }
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
            // Feed the string's UTF-8 storage directly; cmark takes an explicit length,
            // so neither a copy nor a NUL terminator is needed.
            var input = source
            let root: OpaquePointer? = input.withUTF8 { buffer in
                guard let base = buffer.baseAddress, !buffer.isEmpty else {
                    if let mathContext { return swiftgfm_math_parse(mathContext, parser, "", 0) }
                    return swiftgfm_cmark_parser_finish(parser)
                }
                return base.withMemoryRebound(to: CChar.self, capacity: buffer.count) {
                    if let mathContext { return swiftgfm_math_parse(mathContext, parser, $0, buffer.count) }
                    swiftgfm_cmark_parser_feed(parser, $0, buffer.count)
                    return swiftgfm_cmark_parser_finish(parser)
                }
            }
            guard let root else { throw MarkdownEngineError.parseFailed }
            defer { swiftgfm_cmark_node_free(root) }
            return try body(parser, root, flags, width, mathContext)
        }
    }

}
