# V106: Hardware-first stability (PSS-x80)

Generated: 2026-02-10T22:02:02.249873Z

## What changed
- Auto-capture Safe Audition:
  - starts recording and stops as soon as a complete SysEx message (F0..F7) is detected
  - falls back to timeout stop (default 12s)
- Robust SysEx extraction from MIDI items (reassembles split SysEx across events)
- Added PSS Doctor (dependencies + routing hints)
- Added PSS Quick Setup (creates a track with notes for Variant 1 routing)

## Files
- `Workbench/PSS580/Core/ifls_midi_sysex_extract.lua`
- `Workbench/PSS580/Tools/IFLS_PSS580_Safe_Audition_Wizard.lua`
- `Workbench/PSS580/Tools/IFLS_PSS580_Doctor.lua`
- `Workbench/PSS580/Tools/IFLS_PSS580_QuickSetup.lua`
- Hub updated: Doctor + Quick Setup buttons
