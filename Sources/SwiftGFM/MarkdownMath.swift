// SPDX-License-Identifier: Apache-2.0

/// A formula captured before Markdown inline interpretation.
public struct MarkdownMathOccurrence: Sendable, Hashable {
    /// Zero-based occurrence order in the resulting document stream.
    public let index: Int
    /// TeX source between the delimiters, retaining its original spelling.
    public let literal: String
    /// Delimited source suitable for an escaped fallback.
    public let source: String
    /// Whether the formula is a display block rather than inline content.
    public let displayMode: Bool
}

/// One piece of an HTML document stream with math positions kept separate.
public enum MarkdownMathPart: Sendable, Hashable {
    /// An HTML fragment; neighboring pieces need not be complete HTML documents.
    case html(String)
    /// A formula to render separately at this position.
    case math(MarkdownMathOccurrence)
}

/// The result of an opt-in math-aware HTML parse.
public struct MarkdownMathDocument: Sendable, Hashable {
    /// Pieces in document order. Render formulas after the parser call returns.
    public let parts: [MarkdownMathPart]
    /// A table was present; math recognition is not supported in table cells.
    public let containsTablesWithoutMath: Bool
}

/// Failures specific to the opt-in math parser.
public enum MarkdownMathError: Error, Sendable, Equatable {
    /// Unsafe raw HTML is incompatible with guaranteed HTML-text insertion positions.
    case unsafeHTML
    /// NUL is normalized by cmark before callbacks, so original bytes cannot be promised.
    case nulInSource
    /// An opening display fence had no closing fence in its Markdown container.
    case unclosedDisplay
    /// The math parser could not safely complete or exceeded its scanning budget.
    case parserUnavailable
    /// The rendered output could not be divided safely at every math position.
    case invalidDocumentStream
}
