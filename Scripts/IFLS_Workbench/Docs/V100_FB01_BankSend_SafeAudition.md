# V100: FB-01 Bank Send Wizard + Safe Audition Backup

Generated: 2026-02-09T20:32:17.396784Z

## New tools
- `Workbench/FB01/Tools/IFLS_FB01_Bank_Send_Wizard.lua`
  - Sends bank dump as 49 packets with delay (Edisyn-style concept).
  - Modes: `single` or `chunk49` (best-effort chunking).
  - Note: True Edisyn bank packet rebuild requires precise format parsing; chunk49 improves reliability on some routers but may not be accepted by FB-01 depending on firmware.

- `Workbench/FB01/Tools/IFLS_FB01_Safe_Audition_Backup.lua`
  - Records a backup of current voice (via SysEx request) into `Docs/Reports/FB01_AuditionBackup_*.syx`
  - Sends the audition voice
  - Offers revert by re-sending backup

## Library Browser
- Added button: **Safe Audition (backup->audition->revert)**

## Hub
- Added buttons for both tools under FB-01 section.

## Requirements
- SWS extension (SNM_SendSysEx)
- Track MIDI input must be configured to receive SysEx from FB-01 for backup capture.
