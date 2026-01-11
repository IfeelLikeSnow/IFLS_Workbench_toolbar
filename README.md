# IFLS Workbench Toolbar (REAPER)

This repository is laid out exactly like a **REAPER resource folder** snapshot.

## Manual install (recommended while developing)

1. In REAPER: **Options → Show REAPER resource path…**
2. Copy these folders into the resource path (merge/overwrite as needed):
   - `Scripts/`
   - `FXChains/`
   - `Effects/`
   - `Data/`
   - `MenuSets/`

After copying:
- **Actions → ReaScript: Load…** and run the scripts from `Scripts/IFLS_Workbench/...`
- **Options → Customize toolbars… → Import…** and import the `.ReaperMenu` from `MenuSets/`

## Smart Slice (AUTO)
Run:
`Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slice_Smart_AutoMode.lua`

Workflow:
- Select the item(s) you want to slice
- Run the script
- It duplicates the item(s) to `IFLS WB - SLICE`, slices automatically (regions → markers → onsets → grid), applies small fades, optionally runs ZeroCross PostFix, and mutes the source track(s).

## Dev notes
- If you generate parameter dumps, do **not** commit them (see `.gitignore`).
- If you ship a zip, always bump the version number in the filename.
