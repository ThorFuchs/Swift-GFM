// SPDX-License-Identifier: Apache-2.0

/// Identifies a resource measured by an optional SwiftGFM limit.
///
/// Future versions may add resources without a major version change, so code
/// that switches over these values needs a `default` case.
public struct MarkdownResourceLimit: Sendable, Hashable, CustomStringConvertible {
    private enum Value: String, Sendable { case inputUTF8Bytes, astNodes, astDepth }
    private let value: Value
    private init(_ value: Value) { self.value = value }

    /// The resource's stable name, such as `astDepth`.
    public var description: String { value.rawValue }

    /// Number of UTF-8 bytes in the original input string.
    public static let inputUTF8Bytes = Self(.inputUTF8Bytes)
    /// Number of nodes copied into the Swift AST, including the document root.
    public static let astNodes = Self(.astNodes)
    /// Depth of the Swift AST, counting the document root as depth one.
    public static let astDepth = Self(.astDepth)
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
