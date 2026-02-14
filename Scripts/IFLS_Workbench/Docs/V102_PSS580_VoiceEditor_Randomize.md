# V102: PSS-580 Voice Editor + Randomize/Locks/Templates

Generated: 2026-02-09T21:12:53.649913Z

## Added
- `Workbench/PSS580/Tools/IFLS_PSS580_Voice_Editor.lua`
  - ReaImGui voice editor
  - Load 72-byte voice dumps -> decode VMEM (33 bytes)
  - Randomize:
    - intensity 0..1
    - modes: full / constrained_env / constrained_pitch / constrained_level (heuristic scopes)
    - locks per VMEM byte
  - Templates: Organ, BassDrum, Snare, HiHat, Drone (heuristic raw-byte starters)
  - Export `.syx` and Send via SWS `SNM_SendSysEx`

## Core updated
- `Workbench/PSS580/Core/ifls_pss580_sysex.lua` now includes `randomize_vmem(...)`

## Notes
- Parameter-level UI (operator envelopes etc.) requires VMEM->VCED mapping table (planned V103).
