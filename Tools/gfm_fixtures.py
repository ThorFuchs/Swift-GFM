"""Extract numbered examples from the published GFM 0.29 HTML specification."""
from html.parser import HTMLParser

class Examples(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.examples = []
        self.depth = 0
        self.field = None
        self.row = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "div" and attrs.get("class") == "example":
            if self.depth:
                raise ValueError("nested example")
            self.depth = 1
            self.row = {"example": int(attrs["id"].removeprefix("example-")), "section": "published GFM specification"}
            return
        if not self.depth:
            return
        if tag == "div":
            self.depth += 1
        if tag == "code" and attrs.get("class") in ("language-markdown", "language-html"):
            self.field = "markdown" if attrs["class"] == "language-markdown" else "html"
            if self.field in self.row:
                raise ValueError("duplicate example field")
            self.row[self.field] = ""

    def handle_endtag(self, tag):
        if not self.depth:
            return
        if tag == "code" and self.field:
            self.field = None
        if tag == "div":
            self.depth -= 1
            if not self.depth:
                if not all(k in self.row for k in ("markdown", "html")):
                    raise ValueError(f"missing field in {self.row}")
                # The specification explicitly uses the arrow glyph to denote a tab.
                for field in ("markdown", "html"):
                    self.row[field] = self.row[field].replace("→", "\t")
                self.examples.append(self.row)

    def handle_data(self, data):
        if self.field:
            self.row[self.field] += data


def extract(raw):
    parser = Examples()
    parser.feed(raw.decode("utf-8"))
    parser.close()
    cases = parser.examples
    if parser.depth or [x["example"] for x in cases] != list(range(1, 678)):
        raise ValueError("unexpected published GFM example sequence")
    return cases
