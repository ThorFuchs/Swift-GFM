// SPDX-License-Identifier: Apache-2.0

import SwiftGFM
import Markdown

// Distinct results confirm the libraries did not accidentally interpose parsers.
let input = "www.commonmark.org\n"
let gfm = try MarkdownEngine().render(input)
let markdown = HTMLFormatter.format(Document(parsing: input, options: .disableSmartOpts))
guard gfm == "<p><a href=\"http://www.commonmark.org\">www.commonmark.org</a></p>\n",
      markdown == "<p>www.commonmark.org</p>\n" else {
    fatalError("unexpected coexistence outputs: \(gfm), \(markdown)")
}
print("SwiftGFM and Swift Markdown coexist with distinct parser behavior")
