# V82 Changes

Generated: 2026-02-07T21:44:05.193770Z

## Doctor + Hub
- Doctor offers fix: run Apply Port Names tool when `reaper_*_exact` is missing.
- Hub adds status panel (AutoDoctor heartbeat) and "Open latest report" buttons.

## Report pointers
- Added `Workbench/MIDINetwork/Lib/IFLS_ReportPointers.lua`
- Latest pointers stored in `Docs/IFLS_LatestReports.json` (best-effort).

## Optional engineering
- Added GitHub Actions stubs for ReaPack stable/nightly.
- Added version alignment tool:
  - `Tools/IFLS_Workbench_VersionAlignment_ReportAndOptionalBump.lua`

## Validation
- Deep syntax scan: `Docs/V82_SyntaxScan_Report.md`
