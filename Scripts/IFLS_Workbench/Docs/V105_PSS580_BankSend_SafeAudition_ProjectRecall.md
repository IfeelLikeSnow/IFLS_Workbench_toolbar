# V105: PSS-x80 Bank Send Wizard + Safe Audition Backup + Project Recall

Generated: 2026-02-09T22:03:30.979037Z

## New core
- `Workbench/PSS580/Core/ifls_midi_sysex_extract.lua`
  - Extract SysEx messages from recorded MIDI takes.

## Safe audition (backup -> audition -> revert)
- `Workbench/PSS580/Tools/IFLS_PSS580_Safe_Audition_Wizard.lua`
  - Records a backup for N seconds (you trigger PSS transmit)
  - Extracts SysEx from the recorded take and writes `.syx` backup into `Docs/Reports/`
  - Sends audition `.syx` and can revert by sending backup
  - Stores last backup path in ExtState: `IFLS_PSS580/SAFE_BACKUP_PATH`

## Bank send wizard
- `Workbench/PSS580/Tools/IFLS_PSS580_Bank_Send_Wizard.lua`
  - Choose any `.syx` (voice or bank) and send
  - Button to open Safe Audition Wizard

## Project recall
- `IFLS_PSS580_ProjectRecall_Set.lua` (store `.syx` path in project extstate)
- `IFLS_PSS580_ProjectRecall_Apply.lua` (send stored `.syx`)
- `IFLS_PSS580_ProjectRecall_Clear.lua`

## Hub
Added buttons for Safe Audition Wizard, Bank Send Wizard, and Project Recall actions.
