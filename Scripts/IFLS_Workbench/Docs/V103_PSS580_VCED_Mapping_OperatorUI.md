# V103: PSS-x80 (PSS-580) VCED↔VMEM Mapping + Operator UI + Safe Random Scopes

Generated: 2026-02-09T21:21:41.667600Z

## Core improvements
- `Workbench/PSS580/Core/ifls_pss580_sysex.lua`
  - Added full **VMEM field layout** (33 bytes)
  - Added **VCED decode/encode** functions:
    - `vmem_to_vced(vmem)`
    - `vced_to_vmem(vced)`
  - Added safe randomization in decoded domain:
    - `randomize_vced(vced, intensity, locks, scope)`
    - preserves all reserved/unknown bits (`D_*`) to avoid "unk param" flags

## UI improvements
- `Workbench/PSS580/Tools/IFLS_PSS580_Voice_Editor.lua`
  - Now shows **real parameters** (Carrier/Modulator) instead of raw bytes
  - Lock per parameter (checkbox)
  - Random scopes:
    - `global`, `ops_env`, `ops_pitch`, `ops_timbre`, `full`
  - Templates (conservative starter patches)

## Notes
- Some fields marked `D_*` / reserved are kept and round-tripped. For new patches they are zeroed by templates.
