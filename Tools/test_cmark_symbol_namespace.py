import pathlib
import re
import unittest
from check_cmark_symbol_namespace import BRIDGE_SYMBOLS, names

ROOT = pathlib.Path(__file__).resolve().parents[1]

class SymbolNamespaceTests(unittest.TestCase):
    def test_private_bridge_functions_are_namespaced_and_mapped(self):
        header = (ROOT / "Vendor/GitHubCMark/api/SwiftGFMCMark.h").read_text()
        functions = re.findall(r'\b(swiftgfm_cmark_[A-Za-z0-9_]+)\s*\(', header)
        self.assertTrue(functions)
        self.assertEqual(len(functions), len(set(functions)), "duplicate bridge declaration")
        upstream = set(names())
        for function in functions:
            self.assertIn(function.removeprefix("swiftgfm_"), upstream)
        bridge_functions = set(re.findall(r'\b(swiftgfm_bridge_[A-Za-z0-9_]+)\s*\(', header))
        self.assertEqual(bridge_functions, BRIDGE_SYMBOLS)

if __name__ == "__main__":
    unittest.main()
