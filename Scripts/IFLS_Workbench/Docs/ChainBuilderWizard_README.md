# IFLS Workbench – Chain Builder Wizard (MVP)

## What it does
- Loads:
  - `Data/IFLS_Workbench/chain_presets/*.json`
  - `Data/IFLS_Workbench/device_profiles_index.json` + `device_profiles/*.json`
  - `Data/IFLS_Workbench/patchbay.json`
- UI:
  - Select chain preset (intent)
  - Select routing device (Patchbay header)
  - Assign devices to roles (Suggest + pick)
  - Choose build method: tracks / reainsert / both
- Apply:
  - Creates a folder track + Send/Return tracks documenting the external chain.
  - Adds hardware output send + sets return record input based on patchbay suggestion.
  - Optionally adds ReaInsert on the Send track (user selects IO in ReaInsert UI).

## Why it’s useful
- Fast session setup: routing + documentation + repeatable intents (glitch/pads/drones).
- Bridges your inventory (device profiles) with patchbay routing.

## Next iteration ideas
- Use `patchbay_name` from device profiles to auto-select routing device.
- Auto-load FXChains / TrackTemplates per device id if present.
- Add conflict pre-check using recall + patchbay channels.
