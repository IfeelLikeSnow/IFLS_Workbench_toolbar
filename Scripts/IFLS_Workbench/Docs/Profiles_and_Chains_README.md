# IFLS Workbench – Mixed Device Profiles + Chain Presets

## Language policy (Mixed)
- **Controls:** English (short labels)
- **Notes/Warnings:** Deutsch

## What’s included
- `Data/IFLS_Workbench/device_profiles/*.json`  (priority devices: Synths + LoFi/Mod/Time + Routing)
- `Data/IFLS_Workbench/docs_generated/devices/*.md` (human readable)
- `Data/IFLS_Workbench/chain_presets/*.json` (intents: glitch/idm drums, pads, drones, toy synth degrade)

## How to map devices to patchbay
Add/maintain `patchbay_name` in each profile (exact header used in Patchbay matrix).
This avoids brittle fuzzy matching.

## Next steps
1. Add `patchbay_name` to the top 20 devices you use most.
2. Add manual-based enrichment (controls, modes) to those devices.
3. Extend the Wizard to pick from gear.json + apply chain presets automatically.
