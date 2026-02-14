# V80: Apply REAPER Port Names + ExtState Port Indexes

Generated: 2026-02-07T21:32:05.235564Z

## Added
- Lib: `Workbench/MIDINetwork/Lib/IFLS_ReaperPortResolver.lua`
- Tool: `Tools/IFLS_MIDINetwork_Apply_ReaperPortNames_And_Indexes.lua`

## Profile update
- `midinet_profile.json` bumped to `schema_version: 1.3.0`
- Core devices gain optional:
  - `reaper_in_exact`
  - `reaper_out_exact`

## What the tool does
- Enumerates REAPER MIDI ports.
- Matches per device:
  - exact (preferred)
  - contains (fallback)
- Writes:
  1) `reaper_*_exact` into the profile (only when safe/unique unless overwrite is confirmed)
  2) ExtState indexes into section `IFLS_WORKBENCH_DEVICES`:
     - `<device_id>_midi_in_idx`
     - `<device_id>_midi_out_idx`

## Output
- Report: `Docs/MIDINetwork_ApplyPorts_Report.md`

## Next suggested improvement (V81)
- Patch device modules to prefer ExtState port indexes automatically.
