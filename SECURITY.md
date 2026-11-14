# Security policy

## Supported versions

Security fixes are released for the latest minor version of the current major
version. Older versions do not receive backports.

| Version | Supported |
| --- | --- |
| 1.x (latest minor) | Yes |
| Earlier releases and unreleased commits | No |

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub's private vulnerability
reporting: open the repository's **Security** tab and choose **Report a
vulnerability**, or use
<https://github.com/ThorFuchs/Swift-GFM/security/advisories/new>.
Do not open a public issue, discussion, or pull request for a suspected
vulnerability.

A useful report includes:

- the SwiftGFM version or commit, platform, and Swift toolchain;
- the `MarkdownConfiguration` (extensions, options, width, and limits) and the
  API used (`render(_:as:)` with its format, or `parse(_:)`);
- a minimal input that reproduces the problem, and the observed and expected
  behavior.

The report is handled in the private advisory. Once a fix is available, a
release is published and the advisory is disclosed, crediting the reporter
unless they prefer otherwise.

## Vulnerabilities in cmark-gfm

SwiftGFM compiles the vendored, unmodified
[github/cmark-gfm](https://github.com/github/cmark-gfm) C source in-process.
If a problem also reproduces with the upstream `cmark-gfm` executable at the
revision named in [NOTICE](NOTICE), please also report it upstream according
to that project's security policy. When upstream publishes a fix, SwiftGFM
updates the vendored source and publishes a release as described in the
[versioning policy](README.md#versioning-and-api-stability).

## Scope

The [security model](Documentation/SECURITY-MODEL.md) describes what SwiftGFM
does and does not protect against. Documented limitations are not
vulnerabilities by themselves, for example:

- raw HTML or unsafe links in output produced with `.allowUnsafeHTML`;
- the absence of a general-purpose HTML sanitizer in either HTML mode;
- resource use when no `MarkdownResourceLimits` are configured, or C memory and
  time that those optional limits do not bound;
- calls that bypass `MarkdownEngine` and use the vendored C functions directly.

Memory-safety errors, crashes, output that bypasses the default HTML policy,
or super-linear parsing time for some input are in scope.
