# SPDX-License-Identifier: Apache-2.0

import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from check_documentation_links import documentation_files, links


class DocumentationLinkTests(unittest.TestCase):
    def test_links_and_fenced_examples(self):
        source = """[guide](guide.md#setup)
![image](not-a-document-link.png)
[reference]: <other file.md>
```markdown
[example](missing.md)
```
~~~
[another example](missing-too.md)
~~~
"""
        self.assertEqual(
            list(links(source)), [(1, "guide.md#setup"), (2, "not-a-document-link.png"), (3, "other file.md")]
        )

    def test_build_artifacts_are_not_treated_as_project_docs(self):
        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "README.md").write_text("# Root\n")
            docs = root / "Experiments/example"
            (docs / ".build").mkdir(parents=True)
            (docs / "README.md").write_text("# Example\n")
            (docs / ".build/README.md").write_text("[broken](missing.md)\n")
            self.assertEqual(
                {path.relative_to(root).as_posix() for path in documentation_files(root)},
                {"README.md", "Experiments/example/README.md"},
            )


if __name__ == "__main__":
    unittest.main()
