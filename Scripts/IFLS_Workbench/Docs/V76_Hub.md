# V76: Workbench Hub (ReaImGui)

Generated: 2026-02-07T20:58:27.053852Z

## Added
- `Tools/IFLS_Workbench_Hub.lua`
  - One window to launch the most important Workbench tools (MIDI Network, Devices, Patchbay, Fieldrec/IDM).
  - Includes a search box.
  - Graceful fallback if ReaImGui is missing: prints launch list to console.

## Usage
- Run `IFLS_Workbench_Hub` from the Actions list.
- Tip: assign it to a toolbar button.

## Notes
- Hub launches tools via `dofile()` using paths relative to `Scripts/IFLS_Workbench`.
- If any tool is missing (because you renamed/moved it), Hub will show a dialog with the missing path.
