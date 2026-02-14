# IFLS Workbench – Test Plan (v0.7.8)

This checklist verifies core installation + toolbar + slicing + loudness + JSFX.

## 0) Prerequisites
- REAPER 7.x
- (Optional) SWS Extension (for some transient actions)
- (Optional) ReaImGui (for Control Panel UI)

## 1) Install / Update
### ReaPack install
1. Extensions → ReaPack → Import repositories… (your repo URL)
2. Synchronize packages
3. Install “IFLS Workbench (bundle)”
4. Restart REAPER (recommended)

### Manual ZIP install
Copy these repo folders into your REAPER resource path:
- Scripts/
- Effects/
- FXChains/
- Data/
- MenuSets/ (optional)
- DOCS/ (optional)

Resource path: Options → Show REAPER resource path…

## 2) Icons in toolbar icon chooser
If icons do not show up:
1. Run: Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Install_Toolbar_Icons.lua
2. Re-open the toolbar icon chooser
3. Filter: IFLSWB_

## 3) Register scripts
Run:
- Scripts/IFLS_Workbench/IFLS_Workbench_Install_Toolbar.lua
This should register all scripts under Scripts/IFLS_Workbench (excluding lib).

## 4) JSFX Pack
1. Open FX browser
2. Search: “IFLS Workbench -”
3. Verify these appear:
   - Drone Granular Texture
   - Granular Hold
   - Euclid Slicer
   - IDM Chopper + BusTone variants
   - Dynamic Meter v1
   - ReampSuite Analyzer FFT
   - RoundRobin NoteChannelCycler
   - Stereo Alternator
   - MIDIProcessor
   - Drum RR & Velocity Mapper

## 5) JSFX Menu + Inserts
1. Select a track
2. Run: IFLS Workbench: JSFX Menu (DSP Tools)
3. Choose “Dynamic Meter…” → Verify inserted as last FX
4. Run quick inserts:
   - Insert JSFX: Dynamic Meter
   - Insert JSFX: Analyzer FFT
   - Insert JSFX: Euclid Slicer
   - Insert JSFX: IDM Chopper
   - Insert JSFX: Drone Granular

## 6) Slicing
1. Put an audio item on a track
2. Run: Smart Slice (PrintBus → Slice)
3. Verify:
   - items are split
   - fades applied (if enabled)
   - ZeroCross toggle & postfix works

## 7) TailTrim + Spread
1. Select the sliced items
2. Run TailTrim selected slices
3. Run Spread slices with gaps
4. Verify gaps and tails behave as expected

## 8) Loudness (LUFS + Clamp)
1. Select a few audio items
2. Run LUFS AutoGain/Clamp (Prompt) once, set target/clamp
3. Run NoPrompt version to confirm defaults apply

## 9) Control Panel (ReaImGui)
1. Run: IFLS Workbench Slicing Control Panel (ReaImGui)
2. Verify tabs:
   - Slicing
   - PostFX
   - Loudness
   - JSFX (if present)
3. Run actions from panel and confirm they match toolbar actions.

## 10) Diagnostics + Duplicate cleanup
Run:
- IFLS_Workbench_Diagnostics.lua
- IFLS_Workbench_Cleanup_Duplicate_Workbench_Scripts.lua
Verify they report clean install (or offer fixes).
