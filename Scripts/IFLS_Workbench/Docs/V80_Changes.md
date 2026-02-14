# V80 Changes

Generated: 2026-02-07T21:32:05.517547Z

## Profile
- `Workbench/MIDINetwork/Data/midinet_profile.json` -> schema_version 1.3.0
- Core devices gained optional fields:
  - `reaper_in_exact`
  - `reaper_out_exact`

## Added
- `Workbench/MIDINetwork/Lib/IFLS_ReaperPortResolver.lua`
- `Tools/IFLS_MIDINetwork_Apply_ReaperPortNames_And_Indexes.lua`
- Docs: `Docs/V80_PortNames_And_Indexes.md`

## Updated
- Smart Hub: new item + Quick Action "Apply Port Names"

## Validation
- Deep syntax scan: `Docs/V80_SyntaxScan_Report.md`
