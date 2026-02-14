# V92: Unified FB-01 Library Browser (Workbench + external patch repo)

Generated: 2026-02-09T17:41:11.569946Z

## Added
- `Workbench/FB01/Tools/IFLS_FB01_Library_Browser_v2.lua`
- `Workbench/FB01/Pack_v8/Scripts/IFLS_FB01_Replay_SYX_File_FromPath.lua`
- `Workbench/FB01/Lib/ifls_fb01_library_path.lua` (already in v91, used here)

## Hub
- Added button: "FB-01 Library Browser (v2)"

## Sound Editor
- Added "Library" tab with a button to open the browser.

## Sources
- Workbench curated manifest:
  - `Workbench/FB01/PatchLibrary/Patches/manifest.json` (if present)
- External repo manifests:
  - `Scripts/IFLS_FB01_PatchLibrary/FB01/Manifests/*.json`

## Configuration
- Default external path: `ResourcePath/Scripts/IFLS_FB01_PatchLibrary`
- Optional override: ExtState `IFLS_FB01/LIBRARY_PATH`
