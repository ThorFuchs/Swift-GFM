# Release process

Version tags use semantic versions such as `1.0.0`, without a `v` prefix.
Never move or delete a published tag. CI does not create releases; the
maintainer publishes each release explicitly.

1. Choose the version according to the
   [versioning policy](README.md#versioning-and-api-stability).
2. Move the "Unreleased" entries in [CHANGELOG.md](CHANGELOG.md) under the new
   version and merge that change to `main`.
3. Confirm that CI passed for the exact release commit on `main`, including the
   comparison with the upstream executable and the Swift version matrix.
4. Create and push an annotated tag at that commit:

   ```sh
   git tag -a 1.0.0 -m "Swift-GFM 1.0.0"
   git push origin 1.0.0
   ```

5. Publish a GitHub release for the tag with the changelog section as notes.
6. Check that a separate SwiftPM package resolves the release with
   `.package(url: "https://github.com/ThorFuchs/Swift-GFM.git", from: "1.0.0")`,
   and that the Swift Package Index picks up the new version.
