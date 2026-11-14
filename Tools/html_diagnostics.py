"""Narrow, supplementary checkbox serialization diagnostic; never a pass criterion."""
from html.parser import HTMLParser

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}

class Tokens(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.tokens = []
    def handle_starttag(self, tag, attrs):
        self.tokens.append(("start", tag, tuple(sorted(attrs, key=lambda pair: (pair[0], pair[1] or "")))))
    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in VOID:
            self.handle_endtag(tag)
    def handle_endtag(self, tag):
        if tag not in VOID:
            self.tokens.append(("end", tag))
    def handle_data(self, data):
        if self.tokens and self.tokens[-1][0] == "text":
            self.tokens[-1] = ("text", self.tokens[-1][1] + data)
        else:
            self.tokens.append(("text", data))
    def handle_comment(self, data):
        self.tokens.append(("comment", data))
    def handle_decl(self, decl):
        self.tokens.append(("declaration", decl))
    def handle_pi(self, data):
        self.tokens.append(("processing-instruction", data))


def compare(expected, actual):
    """Compare simple HTML tokens, ignoring attribute order and void-tag slash only."""
    expected_parser, actual_parser = Tokens(), Tokens()
    try:
        expected_parser.feed(expected)
        expected_parser.close()
        actual_parser.feed(actual)
        actual_parser.close()
    except (ValueError, AssertionError):
        return "unavailable"
    return "equivalent_tokens" if expected_parser.tokens == actual_parser.tokens else "different_tokens"
