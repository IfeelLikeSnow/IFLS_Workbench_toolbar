# V64 Full Install ReaPack Packaging

Generated: 2026-02-06T14:59:12.106881Z

## Goal
Keep **all scripts** in the repo, but avoid installing hundreds of separate ReaPack packages.
Instead, provide a single ReaPack package that installs everything under `Scripts/IFLS_Workbench/...`.

ReaPack packages can include multiple files. (reapack.com upload tool / package editor docs)
- A single package can install more than one file. See ReaPack upload tool pages.

## What changed
- Removed `@provides` lines from individual Lua scripts (so they don't become separate ReaPack packages).
- Added one package descriptor:
  - `IFLS_Workbench/_packages/IFLS_Workbench_FULL.lua`
  - It lists every file under IFLS_Workbench as `@provides`, mapping to install paths under `Scripts/IFLS_Workbench/...`.

## Counts
- Lua files scanned: 190
- Files with @provides removed: 190
- Package descriptor provides entries: 757

## Deep syntax scan findings
- None
