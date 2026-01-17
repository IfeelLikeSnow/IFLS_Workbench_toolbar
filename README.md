# IFLS Workbench Toolbar

ReaPack repository for IFLS Workbench.
## New in v0.7.8
- Added FX Param Catalog exporter (no MIDI CC + toggle flags + prefer VST3).

## New in v0.7.8
- **Smart Slice** now actually slices (prints -> slices -> closes gaps) and fixes a Lua syntax error.
- Added **IFLS_Export_InstalledFX_List.lua** (dedupe + prefer VST3) which exports TSV + JSON to:
  `<REAPER resource path>/IFLS_Exports/`

## Install (ReaPack)
1. Install **ReaPack** (recommended) and restart REAPER.
2. In ReaPack: **Extensions → ReaPack → Import repositories…**
3. Paste the repository URL to `index.xml` (GitHub raw URL).
4. Synchronize packages, then install **IFLS Workbench (bundle)**.

## Install (manual ZIP)
1. In REAPER: **Options → Show REAPER resource path in explorer/finder…**
2. Unzip the ZIP **into that resource folder** (the folder that already contains `Scripts/`, `Effects/`, `Data/`, `FXChains/` …).
   - **DO NOT unzip into `Scripts/`** (that creates a nested/duplicated folder structure and breaks paths).
3. After unzip you should have (examples):
   - `<ResourcePath>/Scripts/IFLS_Workbench/...`
   - `<ResourcePath>/Effects/IFLS_Workbench/...`
   - `<ResourcePath>/Data/toolbar_icons/...`

If you accidentally ended up with something like:
`<ResourcePath>/Scripts/IFLS Workbench Toolbar/IFLS Workbench/...`

Run the repair script:
`Scripts/IFLS_Workbench/Tools/Diagnostics/IFLS_Workbench_InstallDoctor_Fix_Nested_Folders.lua`
(merges everything back to the correct locations and offers to rename the bad folder).

## Toolbar + icons
- Run: `Scripts/IFLS_Workbench/IFLS_Workbench_Install_Toolbar.lua`
- Or generate the menu file: `Scripts/IFLS_Workbench/IFLS_Workbench_Toolbar_Generate_ReaperMenu.lua`
- Then: **Options → Customize toolbars… → Import…**
- Icons are read from: `REAPER/Data/toolbar_icons/*.png`
  (REAPER does not embed PNG data inside `.ReaperMenu` files; it only references icon filenames).

## Quick testing checklist (REAPER)
1. **Dependencies**: SWS + ReaImGui installed. ReaPack optional but recommended.
2. **Toolbar visible**: open your toolbar, ensure the IFLS toolbar buttons appear and icons show.
3. **Smart Slice**
   - Select a track (or a bus/group) that plays audio.
   - Run: `IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.lua`
   - Expect:
     - new stem track created + originals muted (render action)
     - new track **"IFLS Slices"** created before the stem track
     - items on IFLS Slices get split, then gaps closed
4. **ZeroCross toggle + postfix**
   - Run: `IFLS_Workbench_Slicing_Toggle_ZeroCross.lua` (prints ON/OFF in console)
   - Run Smart Slice again and verify no clicks at slice boundaries (postfix runs when enabled)
5. **Export Installed FX**
   - Run: `Tools/IFLS_Export_InstalledFX_List.lua`
   - Check output folder: `<resource>/IFLS_Exports/`


## Docs
- [REAPER Test Plan](DOCS/REAPER_TEST_PLAN_v0.7.8.md)
- [Duplicate Removal](DOCS/DUPLICATES.md)
- [GitHub Push](DOCS/GITHUB_PUSH.md)


## ReaPack Import URL
Paste this into: Extensions → ReaPack → Import repositories…

```
https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main/index.xml
```

## Smart Slicing Modes (v0.7.8)

New optional tools:
- **Smart Slicing Mode Menu**: choose Normal / Clicks & Pops / Drones.
- **Clickify**: post-process slices into micro-clicks/pops around peaks.
- **Drone Chop**: glue + chop into longer segments with fades.

See `DOCS/IFLS_SMART_SLICING_MODES_v0.7.8.md`.

## Folder naming (0.7.8)
To reduce path issues and simplify installation, the repo uses consistent folder names without spaces:
- Effects/IFLS_Workbench/
- FXChains/IFLS_Workbench/
- Data/IFLS_Workbench/

JSFX names are unified as IFLS_Workbench_*.jsfx and show up in REAPER as "IFLS Workbench - ...".


## ReaPack install path (v0.7.11+)

Installs into:
- Scripts/IFLS_Workbench/
- Effects/IFLS_Workbench/
- Data/IFLS_Workbench/

If you previously had nested folders like `Scripts/IFLS Workbench Toolbar/IFLS Workbench/Core/...`, run the included InstallDoctor scripts to clean up.
