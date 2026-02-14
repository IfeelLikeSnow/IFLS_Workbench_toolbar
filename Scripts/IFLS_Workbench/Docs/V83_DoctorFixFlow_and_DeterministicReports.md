# V83: Doctor Fix Flow + Deterministic Reports

Generated: 2026-02-07T21:47:10.918001Z

## What improved vs V82
### Doctor
- Generates a deterministic summary report at:
  - `Docs/MIDINetwork_Doctor_Report.md`
- Detects devices where:
  - `reaper_in_contains` or `reaper_out_contains` is set **but** corresponding `reaper_*_exact` is empty
- Offers:
  - **Fix now** -> runs `Apply REAPER Port Names + Indexes`
  - then re-runs Doctor automatically

### Reports + pointers
- PortMatcher now writes a deterministic report:
  - `Docs/MIDINetwork_PortMatcher_Report.md`
- Wiring export sets latest pointer when `Docs/MIDINetwork_WiringSheet.md` exists
- Pointers stored in:
  - `Docs/IFLS_LatestReports.json`

## How to use
1. Run Doctor
2. If prompted, choose **Fix now**
3. Open reports from Hub -> Reports section
