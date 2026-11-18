# SwiftGFM example gallery

Explore eight small, independently authored Markdown documents. Each source in
[`Markdown/`](Markdown/) has a matching HTML fragment in [`HTML/`](HTML/) and a
browser preview in [`Images/`](Images/). The screenshots apply
[`preview.css`](preview.css); the stylesheet is not part of SwiftGFM's output.
The previews show browser rendering, which may differ with other stylesheets,
fonts, or browsers. They do not claim to reproduce GitHub.com's presentation.

| Example | Markdown | Actual HTML |
| --- | --- | --- |
| Text and emphasis | [Source](Markdown/01-text.md) | [HTML](HTML/01-text.html) |
| Ordered and nested lists | [Source](Markdown/02-lists.md) | [HTML](HTML/02-lists.html) |
| Task lists | [Source](Markdown/03-tasks.md) | [HTML](HTML/03-tasks.html) |
| Tables | [Source](Markdown/04-tables.md) | [HTML](HTML/04-tables.html) |
| Links and autolinks | [Source](Markdown/05-links.md) | [HTML](HTML/05-links.html) |
| Fenced and inline code | [Source](Markdown/06-code.md) | [HTML](HTML/06-code.html) |
| Block quotes | [Source](Markdown/07-quotes.md) | [HTML](HTML/07-quotes.html) |
| Optional footnotes | [Source](Markdown/08-footnotes.md) | [HTML](HTML/08-footnotes.html) |

## Render an example

From the repository root, run:

```sh
swift run swift-gfm html -e table -e strikethrough -e autolink -e tagfilter -e tasklist Examples/Markdown/04-tables.md > /tmp/swift-gfm-table.html
```

This explicitly selects the library's five default GFM extensions. The CLI
otherwise starts with no extensions. Add `-e footnotes` for the footnote
example: footnotes are off by default. The output is an HTML fragment; wrap it
in a page and add a stylesheet if you want a designed presentation.

In Swift, the library defaults to the five GFM extensions:

```swift
import Foundation
import SwiftGFM

let markdown = try String(contentsOfFile: "Examples/Markdown/04-tables.md", encoding: .utf8)
let html = try MarkdownEngine().render(markdown, as: .html)
print(html)
```

For footnotes, initialize the engine with
`MarkdownConfiguration(options: [.footnotes])`.

## Check and update the gallery

The following uses the built CLI to check that all committed HTML fragments
still match the Markdown inputs and their documented options:

```sh
swift build
python3 Tools/render_examples.py --binary "$(swift build --show-bin-path)/swift-gfm" --check
```

Omit `--check` to regenerate the HTML. To regenerate the screenshots as well,
pass `--chrome /path/to/Chrome`: the script opens local, temporary pages in
headless Chrome using `preview.css`. Screenshots can vary with browser version
and available fonts. Review them visually after changing an example or the
stylesheet. CI checks the HTML fragments, not image pixels.

The [GFM syntax guide](https://thorfuchs.github.io/Swift-GFM/documentation/swiftgfm/gfmsyntax/)
explains the supported constructs and configuration boundaries.
