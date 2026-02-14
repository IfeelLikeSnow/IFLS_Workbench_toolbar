# V74 Changes

Generated: 2026-02-07T20:31:09.804084Z

## Included
- Updated `Workbench/MIDINetwork/Data/midinet_profile.json` (schema_version 1.1.0)
  - Added `port_map` for mioXM DIN/USB host wiring.
  - Added `connection` hints to device entries.
  - Added `to_port_hint` to routes.

## Next improvement (V75)
- Add `reaper_midi_out_name` / `reaper_midi_in_name` matching and validate against REAPER prefs.
- Device tools auto-select ports and warn if mismatch.
