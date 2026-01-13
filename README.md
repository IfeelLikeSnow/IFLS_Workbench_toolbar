# IFLS Workbench Toolbar

ReaPack repository for IFLS Workbench.
## New in v0.7.5
- Added FX Param Catalog exporter (no MIDI CC + toggle flags + prefer VST3).

## New in v0.7.4
- **Smart Slice** now actually slices (prints -> slices -> closes gaps) and fixes a Lua syntax error.
- Added **IFLS_Export_InstalledFX_List.lua** (dedupe + prefer VST3) which exports TSV + JSON to:
  `<REAPER resource path>/IFLS_Exports/`

## Install (ReaPack)
1. Install **ReaPack** (recommended) and restart REAPER.
2. In ReaPack: **Extensions → ReaPack → Import repositories…**
3. Paste the repository URL to `index.xml` (GitHub raw URL).
4. Synchronize packages, then install **IFLS Workbench (bundle)**.

## Install (manual ZIP)
- Unzip this repository into:
  `C:\Users\<YOU>\AppData\Roaming\REAPER\`
  so that you get folders like `Scripts/IFLS_Workbench/...` and `Data/toolbar_icons/...`.

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
- [REAPER Test Plan](DOCS/REAPER_TEST_PLAN_v0.7.5.md)
- [Duplicate Removal](DOCS/DUPLICATES.md)
- [GitHub Push](DOCS/GITHUB_PUSH.md)


## ReaPack Import URL
Paste this into: Extensions → ReaPack → Import repositories…

```
https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main/index.xml
```
