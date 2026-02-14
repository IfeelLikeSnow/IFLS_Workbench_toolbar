# V68 MicroFreak Recall + Library Browser

Generated: 2026-02-06T15:53:54.765576Z

## Added
- Workbench/MicroFreak/IFLS_MicroFreak_Lib.lua
- Workbench/MicroFreak/Patches/manifest.json
- Workbench/MicroFreak/Patches/syx/ (library folder)
- Tools:
  - IFLS_MicroFreak_Library_Browser.lua
  - IFLS_MicroFreak_Send_Project_Recall.lua

## Updated
- Tools/IFLS_MicroFreak_CC_Panel.lua
  - Save CC snapshot to Project Recall
  - Load & Send CC snapshot from Project Recall

## How Project Recall works
Stored in ProjectExtState (per project):
- recall_syx: library-relative .syx file (from MicroFreak library)
- recall_out_dev: MIDI output device id
- recall_channel: MIDI channel
- recall_cc_json: CC snapshot values

## Dependencies
- ReaImGui: Browser UI
- SWS: SysEx send (.syx)
- JS_ReaScriptAPI optional: better file import dialog
