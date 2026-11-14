# Getting started

Create an engine and choose the cmark backend configuration for your application.

## Render Markdown

```swift
import SwiftGFM

let engine = MarkdownEngine()
let html = try engine.render("Hello *world*!\n", as: .html)
// <p>Hello <em>world</em>!</p>
```

``MarkdownEngine/init(configuration:)`` defaults to the ``MarkdownConfiguration/gfm``
configuration, which attaches tables, strikethrough, autolinks, tag filtering,
and task lists. ``MarkdownConfiguration/cmarkDefault`` attaches no extensions.
Both retain the backend's default HTML policy.

To choose extensions and backend options explicitly:

```swift
let configuration = MarkdownConfiguration(
    extensions: [.table, .strikethrough],
    options: [.sourcePositions],
    width: 0
)
let configuredEngine = MarkdownEngine(configuration: configuration)
let xml = try configuredEngine.render("# Heading\n", as: .xml)
```

The command-line executable reads UTF-8 from standard input. Its default has no
extensions, unlike the library engine's default:

```sh
printf '# Heading\n' | swift run swift-gfm html
swift run swift-gfm --help
```

## Inspect the backend

``MarkdownEngine/backendVersion`` reports the compiled C version string, while
``MarkdownEngine/backendRevision`` identifies the vendored source revision.
See <doc:BundledConformance> for how the bundled upstream tests are exercised.
