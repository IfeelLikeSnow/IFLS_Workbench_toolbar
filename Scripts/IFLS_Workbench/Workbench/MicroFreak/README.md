# MicroFreak (IFLS Workbench Module)

This module provides:
- CC parameter mapping (based on MicroFreak manual Appendix D)
- A ReaImGui CC panel for hands-on control from REAPER
- SysEx librarian helper (send .syx preset banks exported from Arturia MIDI Control Center)

## Recommended workflow
1) Use **CC Panel** for realtime automation / performance control.
2) Use **SysEx Librarian** to send preset banks (.syx) created/exported by Arturia MIDI Control Center.

## Files
- Data/microfreak_cc_map.json
- Tools:
  - IFLS_MicroFreak_CC_Panel.lua
  - IFLS_MicroFreak_SysEx_Librarian.lua
