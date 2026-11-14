# GFM reporting views

For the production wrapper's tests against the pinned **cmark-gfm repository's bundled fixtures**, see [BUNDLED-CMARK-QA.md](BUNDLED-CMARK-QA.md). Those backend-fidelity checks are distinct from the published-specification views described below.

The pinned published GFM HTML has 677 numbered examples. Neither reporting view currently qualifies Swift-GFM: the candidate wrapper is available but extraction from the published HTML has not been fully verified against its exact source, and the per-example reference settings remain provisional. `qualification_eligible` is explicitly false for GFM reports. Actual and expected HTML are compared as bytes; no normalization changes pass/fail.

## Published examples

`--view published` runs every published example, preserving identifiers, order, input and expected output. For cases matching the historical source exactly, extension labels come from that source. For the 15 others, including the two historical disabled examples, `Tools/gfm_published_config.py` supplies documented provisional settings derived from the published specification sections. The report records the setting, provenance, historical mapping note, actual command and reproduction command per case. Unmapped configurations are skipped with a reason; skipped cases always fail the command. The scope remains `incomplete` even with zero skips because the extracted source and settings are not fully verified. An incomplete published run exits nonzero even if its executed cases all pass.

This view currently expects a **cmark-gfm-compatible executable**: the harness appends `-e NAME` to select per-example reference extensions. Do not point it at a command that does not support those flags. It is a reference experiment, not a fixed-profile candidate run.

```sh
python3 Tools/conformance.py gfm --view published --renderer-version 'cmark-gfm 0.29.0.gfm.0 b8eb2e00de094999f978e9cb02b1a78d810812d3' --report Artifacts/gfm-published.json -- "$PWD/.references/cmark-gfm-2019-build/src/cmark-gfm" --unsafe
```

## Fixed-profile subset

`--view fixed` invokes the **identical user-supplied command** for each case. Its versioned [manifest](../Fixtures/gfm/fixed-profile-v1.json) selects 17 original published examples and includes two explicitly project-authored interaction cases. It covers key GFM features and combinations but is an exploratory subset, not the 677-example corpus. Each project-authored expected output is identified as such and explains how it was composed; it must not be presented as an official fixture. The report includes the manifest hash, published corpus total and subset total. A zero exit from a passing fixed-subset run means only that this invocation passed its selected cases, never that the profile is qualified.

```sh
python3 Tools/conformance.py gfm --view fixed --renderer-version 'cmark-gfm 27d942c8b0a62d192f616e5bf3578f4b6a89e180' --report Artifacts/gfm-fixed.json -- "$PWD/.references/cmark-gfm-build/src/cmark-gfm" --unsafe -e table -e strikethrough -e tasklist -e autolink -e tagfilter
```

Both views support `--example ID` before `--`, including interaction IDs. Reports provide a per-case reproduction command. Test executables must read one case from standard input and write HTML to standard output. `--renderer-version` is a user assertion, not a cryptographic verification of the executable.

## Supplemental evidence

For task-list cases 279, 280 and the task-list interaction, the harness also compares simple HTML tokens with attribute order and void-element slash ignored. When this secondary check agrees but bytes differ, it records `renderer_serialization_likely`; strict status remains failed. This is a diagnostic, not proof of AST equivalence, browser behavior, or safety. Other differences remain `unclassified` pending separate parser and renderer evidence.

A Linux reference run with cmark-gfm 0.29.0.gfm.0 produced **671 passed, 6 failed, 0 skipped** in the published view, which remains incomplete. The 0.29.0.gfm.13 fixed-subset run produced **13 passed, 6 failed, 0 skipped** of 19. These count reference behavior, not Swift-GFM behavior. See [the 15-example investigation](GFM-15-INVESTIGATION.md) and [reproduction details](REPRODUCTION.md).
