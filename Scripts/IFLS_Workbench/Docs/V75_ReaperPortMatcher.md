# V75: REAPER Port Matcher + Profile Hints

Generated: 2026-02-07T20:36:46.301831Z

## Web research basis
REAPER exposes MIDI device enumeration via:
- `GetNumMIDIInputs` / `GetMIDIInputName`
- `GetNumMIDIOutputs` / `GetMIDIOutputName`  
(see REAPER API docs). 

## Added
- Tool: `Tools/IFLS_MIDINetwork_ReaperPortMatcher.lua`

## Profile update
- `midinet_profile.json` bumped to `schema_version: 1.2.0`
- Core devices include:
  - `reaper_in_contains: "mioXM"`
  - `reaper_out_contains: "mioXM"`

Adjust these strings if your REAPER port names differ.

## How to use
1) Open REAPER → Preferences → MIDI Devices, note your port names.
2) Edit per-device `reaper_in_contains`/`reaper_out_contains` if needed.
3) Run **IFLS_MIDINetwork_ReaperPortMatcher** → generates:
   - `Docs/MIDINetwork_ReaperPortMatch_Report.md`
