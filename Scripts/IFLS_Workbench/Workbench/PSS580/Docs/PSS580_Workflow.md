# Yamaha PSS-580 in REAPER (IFLS Workbench Module)

Generated: 2026-02-06

## Goals
- Banks 1–5 patch recall per REAPER project (manual button)
- Library browser with tags/search (ReaImGui)
- Patches stored as `.syx` in repo, and embedded in project via ProjectExtState for portability.

## MIDI wiring (recommended)
- 1824c MIDI OUT -> OUT Thru box -> PSS-580 MIDI IN
- PSS-580 MIDI OUT -> IN Thru box -> 1824c MIDI IN

## Scripts
- Patch Browser: `Scripts/IFLS_Workbench/PSS580/IFLS_PSS580_Browser.lua`
- Send Project Recall (button): `Scripts/IFLS_Workbench/PSS580/IFLS_PSS580_Send_Project_Recall.lua`
- Capture/Export helper: `Scripts/IFLS_Workbench/PSS580/IFLS_PSS580_CaptureDump_Helper.lua`

## Library
- Manifest: `Workbench/PSS580/Patches/manifest.json`
- SysEx files: `Workbench/PSS580/Patches/syx/*.syx`

## Notes
- PSS-x80 series commonly stores 5 user patch banks and uses SysEx bulk transfer workflows.
- Some devices pause briefly while receiving SysEx; use the post-send delay setting.

Sources (background reading):
- PSS x80 series SysEx capture workflow and bank slots: yamahamusicians forum.
- PSS-580 SysEx receive pauses briefly: stereoninjamusic.
- Electra One panel notes for PSS-480 (also applies to 580/680/780): electra.one.

## V60 additions
- Import .syx -> library + manifest update (optional set as project recall)
- Create Tracks Template script
