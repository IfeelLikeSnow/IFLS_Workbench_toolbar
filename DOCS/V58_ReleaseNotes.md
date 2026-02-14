# V58 Release Notes

Generated: 2026-02-06T12:06:45.930913Z

## 1) CI improvements
- `.github/workflows/ifls-ci.yml` now also validates schema files themselves (json-schema-validate action)
- JSON validation patterns expanded to match `Scripts/IFLS_Workbench/Data/**`

## 2) Local validator: strict mode (schema required keys)
- `IFLS_Workbench_Validate_Data_JSON.lua`:
  - reads ExtState `IFLS_WORKBENCH_SETTINGS/validator_strict`
  - when ON: performs recursive "required keys" validation using the repo schema (shallow, best effort)

## 3) Settings UI extended
- `IFLS_Workbench_Settings.lua` now includes a checkbox for validator strict mode.

## 4) New: Preflight script
- `IFLS_Workbench_Preflight.lua` runs Doctor → SelfTest → Validate JSON.

## 5) SafeApply coverage completion
- `IFLSWB_AutoSplit_MixedContent.lua` wrapped in SafeApply.run to ensure undo safety.

## 6) Deep syntax scan report
- `Docs/V58_SyntaxScan_Report.md`
