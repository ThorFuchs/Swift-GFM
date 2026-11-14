# GitHub cmark-gfm API inventory and wrapper assessment

**Implementation update:** The main `SwiftGFM` target now wraps the pinned GitHub sources with one `render(_:as:)` method and a shared lock. The original experiment and measurements below remain historical; see [WRAPPER-API.md](WRAPPER-API.md) for the current product and qualification.

Inspected [github/cmark-gfm](https://github.com/github/cmark-gfm) at commit `27d942c8b0a62d192f616e5bf3578f4b6a89e180` (its version string is `0.29.0.gfm.13`). This was repository HEAD when checked on 2026-11-13. The [main public header](https://github.com/github/cmark-gfm/blob/27d942c8b0a62d192f616e5bf3578f4b6a89e180/src/cmark-gfm.h), [extension API header](https://github.com/github/cmark-gfm/blob/27d942c8b0a62d192f616e5bf3578f4b6a89e180/src/cmark-gfm-extension_api.h), and [core extensions header](https://github.com/github/cmark-gfm/blob/27d942c8b0a62d192f616e5bf3578f4b6a89e180/extensions/cmark-gfm-core-extensions.h) are authoritative. The exact source commit, options, attached extensions and output format are all part of a reproducible wrapper contract; `0.29.0.gfm.13` alone is not a complete provenance identifier.

## Rendering targets

| Target | C function | Notes |
| --- | --- | --- |
| HTML | `cmark_render_html` | Fragment; accepts the parser's extension list. Raw HTML and unsafe link policy must be explicit. |
| XML | `cmark_render_xml` | Serializes the internal C tree; not a validation report. |
| CommonMark | `cmark_render_commonmark` | Normalized Markdown output; not a lossless source serializer. Takes wrap width. |
| Plain text | `cmark_render_plaintext` | Takes wrap width. |
| LaTeX | `cmark_render_latex` | Takes wrap width. |
| groff man | `cmark_render_man` | A man-page fragment without a document header; takes wrap width. |

Each also has a `_with_mem` variant. All return allocated NUL-terminated buffers that the caller must release using the corresponding allocator. `cmark_markdown_to_html` is a one-shot convenience function, but does not provide the extension attachment necessary for the desired configurable GFM wrapper. The streaming parser API (`cmark_parser_new`, `feed`, `finish`, `free`) can receive chunks of input; it still finishes to an internal tree before these renderers emit output. It is not an incremental string-output API.

## Available options and built-in extensions

The C flags include:

* `CMARK_OPT_SOURCEPOS`: source-position output (and source-position behavior where used by parser/renderers).
* `CMARK_OPT_HARDBREAKS`, `CMARK_OPT_NOBREAKS`: soft-break rendering choices.
* `CMARK_OPT_UNSAFE`: allow raw HTML and otherwise filtered dangerous links. The C default omits raw HTML and filters unsafe links; neither setting alone replicates GitHub.com post-processing or is a complete sanitizer.
* `CMARK_OPT_VALIDATE_UTF8`: replace invalid UTF-8 sequences; it does not produce validation diagnostics. Swift `String` already contains valid Unicode; byte-oriented overloads would need an explicit policy.
* `CMARK_OPT_SMART`: punctuation conversion.
* `CMARK_OPT_GITHUB_PRE_LANG`, `CMARK_OPT_TABLE_PREFER_STYLE_ATTRIBUTES`, `CMARK_OPT_FULL_INFO_STRING`: output formatting choices.
* `CMARK_OPT_LIBERAL_HTML_TAG`, `CMARK_OPT_STRIKETHROUGH_DOUBLE_TILDE`, `CMARK_OPT_FOOTNOTES`: parsing/extension choices.
* `CMARK_OPT_DEFAULT` is zero. `CMARK_OPT_SAFE` and `CMARK_OPT_NORMALIZE` are legacy compatibility flags with no effect in this revision; do not market them as active controls.

The built-in named extensions are `table`, `strikethrough`, `autolink`, `tagfilter`, and `tasklist`; the CLI additionally lists `footnotes`, implemented as `CMARK_OPT_FOOTNOTES`. Registration is not the same as attaching an extension to a parser. Footnotes are an available library feature, not a claim about the pinned GFM specification. Fixed presets require a documented decision on extensions, flags, unsafe HTML and formatting. Exposing configurable combinations can faithfully wrap the library without calling every combination a formal specification profile.

## Validation and diagnostics

There is no general public `Markdown string → syntax diagnostics` API in these headers. Markdown parsers normally interpret otherwise unrecognized constructs as text; `CMARK_OPT_VALIDATE_UTF8` replaces bad byte sequences rather than returning a diagnostic list. Internal node integrity checks are not a Markdown lint or validation API. Wrapper errors could report configuration/extension lookup and detected parse/render failures, but the C default allocator can abort on allocation failure, so a Swift `throws` declaration cannot promise to recover from every failure. Linting, broken-link checks or source diagnostics would be separately designed features, not direct cmark-gfm facilities.

## Other C surfaces

The installed C headers expose many additional low-level APIs: creating/freeing and editing AST nodes; iterating trees; accessing node type, literals, links, titles, lists, source positions and user data; custom memory allocators and linked lists; registering and authoring syntax extensions with block, inline, rendering and postprocessing callbacks; and table/task-list node accessors. See the exhaustive exported-function appendix below. They are not needed for a string-in/string-out API, and exposing C pointers, allocator rules or extension callbacks publicly would substantially expand the ownership, concurrency and compatibility surface. We can use an internal C tree while exposing only rendered strings.

Version APIs `cmark_version` and `cmark_version_string` are useful to expose, together with the wrapper's recorded full Git commit. The output width and documented options above are useful candidates for a typed Swift configuration. No Swift AST, C pointers, arbitrary extension callbacks, arena allocator or public linter are required for the initial surface.

## Literal-source SwiftPM feasibility experiment

[GitHubCMarkProbe](../Experiments/GitHubCMarkProbe) builds the actual GitHub source, not swift-cmark. The complete copied `src` and `extensions` directories and `COPYING` match the pinned checkout byte for byte; a recorded 72-file SHA-256 inventory is checked by a regression test. The experiment adds SwiftPM manifest, forwarding headers, and CMake-generated headers separately. Its `config.h` and export/version headers were generated for this Linux build; they are not yet a portable or macOS-qualified packaging solution. It is an experimental executable, not the production library, and uses the default allocator.

On Linux with Swift 6.4.2, for each of the 670 upstream-enabled source examples and the extension flags specified for that example, the probe's six outputs were compared byte-for-byte with the pinned C CLI, with `--unsafe` and default wrap width: **670/670 matches for each of HTML, XML, CommonMark, plaintext, LaTeX and man** (4,020 comparisons). The two upstream-disabled task-list fixtures were excluded and recorded. A separate exploratory matrix of 3 inputs, 14 individual option settings, two extension sets and six formats produced **504/504** byte matches. These are parity checks against that executable, not proof of all inputs, all combinations, all error cases, concurrent safety, or formal GFM specification conformance. The CLI and probe can have different error-handling behavior (e.g. unknown extension exit codes) and the source corpus itself mixes per-example extension settings.

The CLI reference and Swift probe binary hashes, commands, fixture hash and per-case results are in the generated reports. All source comparisons were successful, not inferred. No production API or remote fork was created.

### Critical concurrency finding

The **GitHub** C revision inspected here differs materially from our earlier swift-cmark experiment: its `cmark_gfm_core_extensions_ensure_registered` uses a mutable static registration flag without a once primitive; `src/inlines.c` contains mutable global character tables modified while extensions are processed; `src/arena.c` contains global arena state. The earlier 2,000-call stress test used Swift's *different* cmark fork and does not establish thread safety here. A production Swift `Sendable` wrapper needs a proven process-wide synchronization/initialization strategy, or a separately justified upstream change; do not share a mutable parser/tree across tasks or use the global arena concurrently without proof. Other linked cmark copies or symbol interposition can complicate a wrapper-local lock. Benchmark and audit before claiming parallel reuse.

## Reproduction

With Swift 6.4.2 and a C compiler, build `Experiments/GitHubCMarkProbe` with SwiftPM. Build the pinned C CLI using `Tools/build-references.sh "$PWD/.references"`. Then:

```sh
python3 Tools/compare_github_cmark_probe.py --probe "$PWD/Experiments/GitHubCMarkProbe/.build/debug/github-cmark-probe" --reference "$PWD/.references/cmark-gfm-build/src/cmark-gfm" --report Artifacts/github-cmark-probe-six-formats.json
python3 Tools/check_github_cmark_options.py --probe "$PWD/Experiments/GitHubCMarkProbe/.build/debug/github-cmark-probe" --reference "$PWD/.references/cmark-gfm-build/src/cmark-gfm" --report Artifacts/github-cmark-probe-options.json
python3 -m unittest discover -s Tools -p 'test_*.py'
```

The tests run one input per process to compare successful outputs. They do not compare concurrent execution or every CLI failure/status. Swift's `String` API would need its own direct in-process integration tests before being considered a faithful wrapper.

## Exported functions in the three public headers

The following inventory was extracted from the pinned header declarations. It is provided for review; use the original headers for full signatures, macros, ownership and documentation. Other source-internal headers may contain exported implementation symbols but are not automatically proposed as supported wrapper APIs.

### `src/cmark-gfm.h` (89 functions)

- `cmark_markdown_to_html`
- `cmark_get_default_mem_allocator`
- `cmark_get_arena_mem_allocator`
- `cmark_arena_reset`
- `cmark_llist_append`
- `cmark_llist_free_full`
- `cmark_llist_free`
- `cmark_node_new`
- `cmark_node_new_with_mem`
- `cmark_node_new_with_ext`
- `cmark_node_new_with_mem_and_ext`
- `cmark_node_free`
- `cmark_node_next`
- `cmark_node_previous`
- `cmark_node_parent`
- `cmark_node_first_child`
- `cmark_node_last_child`
- `cmark_node_parent_footnote_def`
- `cmark_iter_new`
- `cmark_iter_free`
- `cmark_iter_next`
- `cmark_iter_get_node`
- `cmark_iter_get_event_type`
- `cmark_iter_get_root`
- `cmark_iter_reset`
- `cmark_node_get_user_data`
- `cmark_node_set_user_data`
- `cmark_node_set_user_data_free_func`
- `cmark_node_get_type`
- `cmark_node_get_type_string`
- `cmark_node_get_literal`
- `cmark_node_set_literal`
- `cmark_node_get_heading_level`
- `cmark_node_set_heading_level`
- `cmark_node_get_list_type`
- `cmark_node_set_list_type`
- `cmark_node_get_list_delim`
- `cmark_node_set_list_delim`
- `cmark_node_get_list_start`
- `cmark_node_set_list_start`
- `cmark_node_get_list_tight`
- `cmark_node_set_list_tight`
- `cmark_node_get_item_index`
- `cmark_node_set_item_index`
- `cmark_node_get_fence_info`
- `cmark_node_set_fence_info`
- `cmark_node_set_fenced`
- `cmark_node_get_fenced`
- `cmark_node_get_url`
- `cmark_node_set_url`
- `cmark_node_get_title`
- `cmark_node_set_title`
- `cmark_node_get_on_enter`
- `cmark_node_set_on_enter`
- `cmark_node_get_on_exit`
- `cmark_node_set_on_exit`
- `cmark_node_get_start_line`
- `cmark_node_get_start_column`
- `cmark_node_get_end_line`
- `cmark_node_get_end_column`
- `cmark_node_unlink`
- `cmark_node_insert_before`
- `cmark_node_insert_after`
- `cmark_node_replace`
- `cmark_node_prepend_child`
- `cmark_node_append_child`
- `cmark_consolidate_text_nodes`
- `cmark_node_own`
- `cmark_parser_new`
- `cmark_parser_new_with_mem`
- `cmark_parser_free`
- `cmark_parser_feed`
- `cmark_parser_finish`
- `cmark_parse_document`
- `cmark_parse_file`
- `cmark_render_xml`
- `cmark_render_xml_with_mem`
- `cmark_render_html`
- `cmark_render_html_with_mem`
- `cmark_render_man`
- `cmark_render_man_with_mem`
- `cmark_render_commonmark`
- `cmark_render_commonmark_with_mem`
- `cmark_render_plaintext`
- `cmark_render_plaintext_with_mem`
- `cmark_render_latex`
- `cmark_render_latex_with_mem`
- `cmark_version`
- `cmark_version_string`

### `src/cmark-gfm-extension_api.h` (66 functions)

- `cmark_plugin_register_syntax_extension`
- `cmark_find_syntax_extension`
- `cmark_syntax_extension_free`
- `cmark_syntax_extension_new`
- `cmark_syntax_extension_add_node`
- `cmark_syntax_extension_set_emphasis`
- `cmark_syntax_extension_set_open_block_func`
- `cmark_syntax_extension_set_match_block_func`
- `cmark_syntax_extension_set_match_inline_func`
- `cmark_syntax_extension_set_inline_from_delim_func`
- `cmark_syntax_extension_set_special_inline_chars`
- `cmark_syntax_extension_set_get_type_string_func`
- `cmark_syntax_extension_set_can_contain_func`
- `cmark_syntax_extension_set_contains_inlines_func`
- `cmark_syntax_extension_set_commonmark_render_func`
- `cmark_syntax_extension_set_plaintext_render_func`
- `cmark_syntax_extension_set_latex_render_func`
- `cmark_syntax_extension_set_xml_attr_func`
- `cmark_syntax_extension_set_man_render_func`
- `cmark_syntax_extension_set_html_render_func`
- `cmark_syntax_extension_set_html_filter_func`
- `cmark_syntax_extension_set_commonmark_escape_func`
- `cmark_syntax_extension_set_private`
- `cmark_syntax_extension_get_private`
- `cmark_syntax_extension_set_postprocess_func`
- `cmark_syntax_extension_set_opaque_alloc_func`
- `cmark_syntax_extension_set_opaque_free_func`
- `cmark_parser_set_backslash_ispunct_func`
- `cmark_parser_get_line_number`
- `cmark_parser_get_offset`
- `cmark_parser_get_column`
- `cmark_parser_get_first_nonspace`
- `cmark_parser_get_first_nonspace_column`
- `cmark_parser_get_indent`
- `cmark_parser_is_blank`
- `cmark_parser_has_partially_consumed_tab`
- `cmark_parser_get_last_line_length`
- `cmark_parser_add_child`
- `cmark_parser_advance_offset`
- `cmark_parser_feed_reentrant`
- `cmark_parser_attach_syntax_extension`
- `cmark_node_set_type`
- `cmark_node_get_string_content`
- `cmark_node_set_string_content`
- `cmark_node_get_syntax_extension`
- `cmark_node_set_syntax_extension`
- `cmark_inline_parser_advance_offset`
- `cmark_inline_parser_get_offset`
- `cmark_inline_parser_set_offset`
- `cmark_inline_parser_get_chunk`
- `cmark_inline_parser_in_bracket`
- `cmark_node_unput`
- `cmark_inline_parser_peek_char`
- `cmark_inline_parser_peek_at`
- `cmark_inline_parser_is_eof`
- `cmark_inline_parser_take_while`
- `cmark_inline_parser_push_delimiter`
- `cmark_inline_parser_remove_delimiter`
- `cmark_inline_parser_get_last_delimiter`
- `cmark_inline_parser_get_line`
- `cmark_inline_parser_get_column`
- `cmark_inline_parser_scan_delimiters`
- `cmark_manage_extensions_special_characters`
- `cmark_parser_get_syntax_extensions`
- `cmark_arena_push`
- `cmark_arena_pop`

### `extensions/cmark-gfm-core-extensions.h` (9 functions)

- `cmark_gfm_core_extensions_ensure_registered`
- `cmark_gfm_extensions_get_table_columns`
- `cmark_gfm_extensions_set_table_columns`
- `cmark_gfm_extensions_get_table_alignments`
- `cmark_gfm_extensions_set_table_alignments`
- `cmark_gfm_extensions_get_table_row_is_header`
- `cmark_gfm_extensions_set_table_row_is_header`
- `cmark_gfm_extensions_get_tasklist_item_checked`
- `cmark_gfm_extensions_set_tasklist_item_checked`

For the same-process linking model, global C state and conservative wrapper designs, see [cmark-gfm concurrency and process isolation](CMARK-CONCURRENCY.md).
