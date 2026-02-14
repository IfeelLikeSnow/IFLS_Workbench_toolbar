# V81: Device modules adopt MIDINetwork port defaults

Generated: 2026-02-07T21:37:55.536958Z

## Goal
Make device tools (MicroFreak / PSS-580 / FB-01) prefer the single source of truth:
- ExtState port indexes written by `Apply REAPER Port Names + Indexes`
- fallback: existing UI/manual selection

## Added
- `Workbench/MIDINetwork/Lib/IFLS_DevicePortDefaults.lua`

## Updated
- `Workbench/MicroFreak/IFLS_MicroFreak_Lib.lua` (defaults to device_id `microfreak`)
- `PSS580/IFLS_PSS580_Lib.lua` (defaults to device_id `pss580`)
- FB-01 Pack_v8 SysEx send scripts (defaults to device_id `fb01`)

## How to use
1. Run: `Tools/IFLS_MIDINetwork_Apply_ReaperPortNames_And_Indexes.lua`
2. Then your device tools can send without re-selecting output device each time (where supported).
