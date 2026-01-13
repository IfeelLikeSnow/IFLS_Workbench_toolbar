# IFLS Slicing Control Panel (ReaImGui) — v0.7.6

## What it is
A single UI window that controls your IFLS slicing workflow:
- Mode: Normal / Clicks & Pops / Drones
- PostFX: TailTrim + Spread gaps (seconds or beats)
- Routing helpers (select items on IFLS Slices tracks, route items to IFLS Slices)
- Advanced: optional Dynamic Split hook via NamedCommand ID

## Requirements
- **ReaImGui extension** (distributed via ReaPack in the default ReaTeam Extensions repository).
  - Install: Extensions -> ReaPack -> Browse packages -> search "ReaImGui" and install.
  - Restart REAPER.

## Install
Put the panel script here:
`%APPDATA%\REAPER\Scripts\IFLS_Workbench\Tools\IFLS_Workbench_Slicing_Control_Panel_ReaImGui.lua`

Then in REAPER:
Actions -> ReaScript -> Load... -> select the file.

## How it runs your pipeline
The panel *registers and runs* existing IFLS scripts by file path (using AddRemoveReaScript + Main_OnCommand).
You can edit paths at the top of the panel script if you rename any of the IFLS scripts.

## Beats-to-seconds
If you choose gap units "beats", the panel converts beats to seconds using TimeMap2_beatsToTime (if available),
then stores seconds for the existing spread tool.

## Dynamic Split Hook
If you want a Dynamic Split step, create a custom action or script that performs it, then paste its Named Command ID
(from the Action List) into the Advanced tab. The panel runs it via NamedCommandLookup.
