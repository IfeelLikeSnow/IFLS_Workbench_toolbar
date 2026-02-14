# V104: PSS580 Bank Workflow + Library UX + Realtime Editing + Tests + Release Stubs

Generated: 2026-02-09T21:49:38.391215Z

## 1) Bank Workflow
- `Workbench/PSS580/Tools/IFLS_PSS580_Bank_Import_Export.lua`
  - export5: merge 5 voice dumps into one multi-message .syx
  - import_bank: split multi-message .syx into per-voice .syx
  - batch_split_folder: split all .syx in folder into voices

## 2) Library UX (tags + favorites)
- Sidecar index: `Workbench/PSS580/library/pss_library_index.json`
- Tool: `IFLS_PSS580_Library_Tag_Favorite.lua`
- Browser:
  - Favorites-only toggle
  - Type filter
  - Star + [type] label display
  - Tag/Favorite button in details pane

## 3) Realtime Editing
- Voice Editor:
  - Live Send (throttled) + throttle ms slider
  - Send now
  - Diff vs Loaded (console)

## 4) Validation & Tests
- Tool: `IFLS_PSS580_Run_Tests_Report.lua`
  - checksum verification
  - VCED<->VMEM roundtrip verification
  - deterministic outputs:
    - `Docs/Reports/PSS580_TestReport.json`
    - `Docs/Reports/PSS580_TestReport.md`

## 5) ReaPack / Release Engineering
- Added `ReaPack/stable` and `ReaPack/nightly` placeholders + `ReaPack/RELEASE_NOTES.md`
- Next (CI): add GitHub Actions to generate index.xml and attach artifacts to releases.
