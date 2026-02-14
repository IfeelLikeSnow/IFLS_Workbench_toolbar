# V101: PSS-580 (PSS-x80) Library Browser + Send + Analyze + Safe Audition

Generated: 2026-02-09T21:05:42.453858Z

## Included patch set
- `Workbench/PSS580/library/alfonse_pss780/` : 41 single-voice `.syx` files (72 bytes each, header `F0 43 76 00`)

## New modules
### Core
- `Workbench/PSS580/Core/ifls_pss580_sysex.lua`
  - Recognize 72-byte voice dumps
  - Split SysEx messages
  - Nibble unpack/pack for VMEM (33 bytes)
  - Checksum implementation (derived from PSS-Revive)

### Tools
- `IFLS_PSS580_Analyze_SYX_File.lua`
- `IFLS_PSS580_Send_Voice_SYX.lua`
- `IFLS_PSS580_Library_Browser.lua`
- `IFLS_PSS580_Safe_Audition_ManualBackup.lua`

## Notes
- Safe Audition is implemented as **manual backup capture** because the PSS-x80 dump-request command is not fully standardized in all references.
  You trigger the voice transmit/dump on the keyboard during a short recording window, then the tool sends audition and offers revert.
