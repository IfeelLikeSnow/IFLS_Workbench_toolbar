# IFLS Workbench Data Integration Pack

This pack adds:
- JSON Schema for Workbench data (gear + patchbay)
- Python converter: Excel (.xlsx) -> JSON
- GitHub Action to auto-regenerate JSON on changes
- ReaImGui Lua viewer for Gear & Patchbay

## Quick start (local)
1. Put your Excel files in `SourceData/` (names in workflow assume:
   - `Geraeteliste.xlsx`
   - `Patchbay Übersicht.xlsx`)
2. Generate JSON:
   - `python -m pip install -r requirements.txt`
   - `python tools/excel_to_json.py --gear-xlsx "SourceData/Geraeteliste.xlsx" --patchbay-xlsx "SourceData/Patchbay Übersicht.xlsx" --out-dir "Data/IFLS_Workbench"`
3. Copy `Data/IFLS_Workbench` + `Scripts/IFLS_Workbench` into your REAPER resource path.

## REAPER
Run:
`Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Gear_And_Patchbay_View.lua`

Requires ReaImGui (install via ReaPack: ReaTeam Extensions).
