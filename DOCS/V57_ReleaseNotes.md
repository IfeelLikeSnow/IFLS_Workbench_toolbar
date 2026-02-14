# V57 Release Notes

Generated: 2026-02-06T12:02:51.399545Z

## 1) SafeApply adoption expanded
Converted additional Tools that contained explicit Undo blocks into `SafeApply.run()` wrappers:
- Fieldrec IDM template builder
- RS5K rack builder
- FX parameter catalog exporters
- Chain Builder Wizard
- FX param dumpers (resume variants)
- Reamp print toggle
- IFLS slices item selection helper
- JSFX insert/menu helpers

This makes project modifications safer and uniformly undoable.

## 2) New: Workbench Settings panel (data_root)
- `Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Settings.lua`
  - ReaImGui UI to view/edit `data_root`
  - Optional folder picker via JS_ReaScriptAPI
  - Stores to ExtState: `IFLS_WORKBENCH_SETTINGS / data_root`

## 3) Local JSON validation strengthened
- `IFLS_Workbench_Validate_Data_JSON.lua` now performs slightly deeper structure checks for gear/patchbay, while remaining schema-agnostic.

## 4) Deep syntax scan report
- `Docs/V57_SyntaxScan_Report.md`
