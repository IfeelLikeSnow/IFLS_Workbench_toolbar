# V93: FB-01 Save/Random/Templates

Generated: 2026-02-09T17:52:39.856612Z

## Sound Editor additions
- Randomize buttons: Voice / Ops / All
- Save/Load patch state (JSON) to disk
- Templates menu (Organ/Synth/BD/SD/HH) as starting points

## New tool
- `Workbench/FB01/Tools/IFLS_FB01_Dump_Save_Wizard.lua`
  - Requests Voice/Set/Bank dumps, records into a MIDI item, exports to .syx.
  - Requires track input configured to FB-01 MIDI IN.
