# V82: Doctor Fixes + Hub Status + Release Stubs (optional)

Generated: 2026-02-07T21:44:05.006284Z

## Doctor: Fix offered
- Doctor can now offer:
  - "Fix: set profile port names" (runs Apply REAPER Port Names + Indexes)
- This helps move from `contains` hints to stable `reaper_*_exact` strings.

## Hub: Status panels + open latest reports
- Hub shows AutoDoctor running/heartbeat (best-effort via ExtState).
- Hub adds "Open latest report" buttons (requires SWS to open files).
- A small pointer store is added:
  - `Docs/IFLS_LatestReports.json`
  - written by tools where available (apply ports; best-effort for wiring/portmatcher/doctor)

## Release engineering (optional)
- Added stub GitHub Actions workflows:
  - `.github/workflows/reapack-nightly.yml`
  - `.github/workflows/reapack-stable.yml`
These are placeholders to wire up later.

## Version alignment tool (optional)
- `Tools/IFLS_Workbench_VersionAlignment_ReportAndOptionalBump.lua`
  - builds a report
  - can optionally bump @version headers to 0.82.0 (asks first)
