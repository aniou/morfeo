# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2025-07-20
### Fixed
- a2560x, c256: handling ps2 keycodes when CPU/IRQ is too slow.

  In that case codes are enqueued in GUI and passed again as soon
  as it is possible. Additional IRQ is triggered on every try.

  It doesn't look nice, but missing keys during typing in c256
  is far worse.

## 2025-07-12
### Added
- a2560x: model/submodel/version support 
- general: CHANGELOG introduced

