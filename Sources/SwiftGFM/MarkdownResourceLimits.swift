// SPDX-License-Identifier: Apache-2.0

/// Identifies a resource measured by an optional SwiftGFM limit.
public enum MarkdownResourceLimit: String, Sendable, Hashable {
    /// Number of UTF-8 bytes in the original input string.
    case inputUTF8Bytes
    /// Number of nodes copied into the Swift AST, including the document root.
    case astNodes
    /// Depth of the Swift AST, counting the document root as depth one.
    case astDepth
}

/// Optional bounds checked by SwiftGFM; `nil` means no bound for that resource.
///
/// Input size is checked before invoking cmark. AST node and depth bounds apply
/// only to `parse(_:)` and are checked while copying the already-parsed C tree.
/// They do not bound cmark's own allocation, rendered output, or execution time.
public struct MarkdownResourceLimits: Sendable, Hashable {
    /// Maximum UTF-8 byte count in the original input; applies to parse and render.
    public var maximumInputUTF8Bytes: Int?
    /// Maximum number of nodes copied to a Swift AST, including the document root.
    public var maximumASTNodes: Int?
    /// Maximum Swift AST depth, counting the document root as depth one.
    public var maximumASTDepth: Int?

    /// Creates limits. Values must be nonnegative; validation occurs on use.
    public init(
        maximumInputUTF8Bytes: Int? = nil,
        maximumASTNodes: Int? = nil,
        maximumASTDepth: Int? = nil
    ) {
        self.maximumInputUTF8Bytes = maximumInputUTF8Bytes
        self.maximumASTNodes = maximumASTNodes
        self.maximumASTDepth = maximumASTDepth
    }

    /// A configuration with no SwiftGFM-enforced limits.
    public static let unlimited = Self()
}
