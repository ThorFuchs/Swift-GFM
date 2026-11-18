# Pinned cmark-gfm test fixtures

The `.txt` files are unmodified copies from `test/` in
https://github.com/github/cmark-gfm/tree/27d942c8b0a62d192f616e5bf3578f4b6a89e180/test.
They are included as SwiftPM test resources so `swift test` works offline and
without a Ruby, Python, or external cmark runtime. They do not ship in the
SwiftGFM library target.

| File | SHA-256 |
| --- | --- |
| `spec.txt` | `7d8e5814befec287ac116786d81ff14e0adc9b13295b4494649e995408fd871c` |
| `extensions.txt` | `a2a45e98be9fca95f564f927265a0f63beea6cae5369d1cf4bde44caa51b2a3a` |
| `extensions-full-info-string.txt` | `dec5fc65880d74f97d5181e0b75466fbe12662cda8383d8b51fd78e06191092f` |
| `extensions-table-prefer-style-attributes.txt` | `3d902a4a1ce48df5dd7910647602fbae4535d8bac6700e918280fe1d928a4cee` |

The spec and extension fixtures identify the CommonMark Spec and CC BY-SA 4.0;
see the adjacent [LICENSE](LICENSE). Upstream's full source
license notices are in `Vendor/GitHubCMark/COPYING`. The NUL in the full-info
fixture is intentional; do not normalize fixture bytes.

The previously bundled `regression.txt` and `smart_punct.txt` have been removed
from this source snapshot because their individual license provenance remains
unresolved. For provenance, their original SHA-256 values were respectively
`0920d7e8134d5e4ec3693f3f52d904b42de45e23a66c29f54fe714dc54213fd9` and
`b1dcfb0e0b6f314cf087edc06f47d9271849da539acfbfac0b9d7b16f10139c9`.
They remain in earlier Git history and the published 1.0.0 source tag.
Thirteen independently authored cases, adapted from SwiftMD, exercise selected
behaviors separately; they are not a complete replacement for the 42 removed
upstream cases. CI may also test the upstream files from a separately acquired,
pinned checkout; that does not determine the rights for their use.

`entities-reference.json` is a derived test fixture, not an upstream file. It
contains the exact HTML emitted by the independently built pinned cmark-gfm
executable for each of the 2,125 names in the unmodified vendored
`src/entities.inc`. Its SHA-256 is
`c78fc9b632768373163b22b1268107d238b136ea3fa48f3122fab610358c0996`.
Reproduce or check it with `Tools/generate_cmark_entity_fixture.py --reference
/path/to/cmark-gfm --check`; the backend checkout revision must be verified
independently.
