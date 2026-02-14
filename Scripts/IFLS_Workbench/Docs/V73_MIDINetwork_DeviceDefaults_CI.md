# V73: MIDINetwork → Device Defaults + CI Luacheck

Generated: 2026-02-07T20:18:19.809824Z

## What changed
- Added `Workbench/MIDINetwork/Lib/IFLS_MIDINetwork_Lib.lua`
  - Loads `midinet_profile.json`
  - Extracts per-device default channels
  - Writes defaults to ExtState section `IFLS_WORKBENCH_DEVICES`
- Added Tool: `Tools/IFLS_MIDINetwork_Apply_DeviceDefaults.lua`
  - One-click: apply defaults from profile to ExtState (channels + policy hints)
- Added `.luacheckrc` and GitHub Action `.github/workflows/luacheck.yml`
  - CI will lint `Scripts/IFLS_Workbench/**.lua` in GitHub.

## How to use
1) Run: **IFLS_MIDINetwork_Apply_DeviceDefaults**
2) Your device tools can now read default channels from ExtState:
   - `IFLS_WORKBENCH_DEVICES / pss580_ch`
   - `IFLS_WORKBENCH_DEVICES / microfreak_ch`
   - `IFLS_WORKBENCH_DEVICES / fb01_channels_json`

## What still should be improved next
### 1) True port mapping (device -> REAPER MIDI output device id)
Right now the profile encodes channels and policy, but **port/device-id mapping is still manual**.
Next: extend schema with `reaper_midi_out_device_id` per device (or name matching), then:
- Device tools can auto-select output
- Doctor can warn if device id missing.

### 2) Device tools should actively consume defaults
Currently only the defaults + tool exist; some device tools still use their own ExtState keys.
Next: patch FB-01 + PSS-580 + MicroFreak tools to:
- fall back to `IFLS_WORKBENCH_DEVICES` when project recall is unset
- show a “Use MIDINetwork defaults” checkbox.

### 3) Replace heuristic syntax checks with luacheck output
V72 had heuristic [[ ]] warnings. CI now uses luacheck for real parsing, but locally:
- Option: add `Tools/IFLS_Run_Luacheck_Local.lua` (if user has luacheck)
- Or add a lightweight parser check (limited).

### 4) Single Hub UI
Add a Workbench “Hub” ReaImGui window:
- Topology Viewer
- Doctor
- AutoDoctor toggle
- Apply Device Defaults
- Export Wiring Sheet

