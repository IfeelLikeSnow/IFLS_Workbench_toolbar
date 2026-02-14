# V56 Release Notes

Generated: 2026-02-06T11:58:47.416104Z

## 1) SafeApply adoption
- `IFLS_Workbench_HW_Recall_Apply.lua`: wrapped the apply operation in `SafeApply.run()` (Undo + error surface, no UI refresh spam).
- `IFLS_Workbench_External_Insert_Wizard.lua`: wrapped track/routing creation in `SafeApply.run()`.

## 2) Local JSON validation (no GitHub needed)
- New tool: `Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Validate_Data_JSON.lua`
  - Decodes gear.json / patchbay.json using an available JSON module
  - Performs lightweight schema checks (required keys + basic types)
  - Validates FB-01 manifest if present
- `IFLS_Workbench_SelfTest.lua` now points to this validator for deeper checks.

## 3) Deep syntax scan report
- `Docs/V56_SyntaxScan_Report.md`
