# SPDX-License-Identifier: Apache-2.0

"""Provenance for the unmodified test resources from the pinned C backend."""
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
DIRECTORY = ROOT / "Tests/SwiftGFMTests/Fixtures/cmark-gfm"
SOURCES = {
    "spec": ("7d8e5814befec287ac116786d81ff14e0adc9b13295b4494649e995408fd871c", 672),
    "extensions": ("a2a45e98be9fca95f564f927265a0f63beea6cae5369d1cf4bde44caa51b2a3a", 30),
    "regression": ("0920d7e8134d5e4ec3693f3f52d904b42de45e23a66c29f54fe714dc54213fd9", 26),
    "smart_punct": ("b1dcfb0e0b6f314cf087edc06f47d9271849da539acfbfac0b9d7b16f10139c9", 16),
    "extensions-full-info-string": ("dec5fc65880d74f97d5181e0b75466fbe12662cda8383d8b51fd78e06191092f", 4),
    "extensions-table-prefer-style-attributes": ("3d902a4a1ce48df5dd7910647602fbae4535d8bac6700e918280fe1d928a4cee", 1),
}
