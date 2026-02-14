# V60 Release Notes (PSS580 module upgrade)

Generated: 2026-02-06T13:01:40.102136Z

## Added
- PSS580 Importer UI:
  - `Scripts/IFLS_Workbench/PSS580/IFLS_PSS580_ImportSYX_UpdateManifest.lua`
  - Imports a .syx into `Workbench/PSS580/Patches/syx/`
  - Updates `Workbench/PSS580/Patches/manifest.json`
  - Optional: sets imported patch as Project Recall (portable via ProjectExtState)

- PSS580 Track Template Creator:
  - `Scripts/IFLS_Workbench/PSS580/IFLS_PSS580_Create_Tracks_Template.lua`
  - Creates SEQ / RECALL(SEND) / CAPTURE(REC) tracks with notes

## Deep syntax scan
- `Docs/V60_SyntaxScan_Report.md`
