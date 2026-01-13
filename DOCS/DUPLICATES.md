# Duplicate Removal Guide (REAPER)

This project commonly ends up duplicated in two places:

1) **Canonical (keep):**
```
<REAPER resource path>/Scripts/IFLS_Workbench/...
```

2) **Duplicate (remove/quarantine):** (example)
```
<REAPER resource path>/Scripts/IFLS Workbench Toolbar/IFLS_Workbench/...
```

If you have both, REAPER may execute the wrong copy (toolbar buttons can point to the "other" registration).

## Fast manual method (safe)
1. REAPER → **Options → Show REAPER resource path**
2. Close REAPER
3. Go to:
   - `Scripts/`
4. Rename the duplicate folder, for example:
   - `Scripts/IFLS Workbench Toolbar` → `Scripts/_DISABLED_IFLS Workbench Toolbar`
5. Start REAPER and run Smart Slice again.

## Automated method (recommended)
Run:
- `Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Eliminate_Duplicate_Installations_v0.7.5.lua`

It will:
- dry-run preview
- move duplicates into:
  `Scripts/_IFLS_QUARANTINE/<timestamp>/...`
- optionally clean up Action List registrations
- write a report to:
  `<resource>/IFLS_Exports/IFLS_DuplicateCleanup_Report_<timestamp>.txt`

## Sanity check
After cleanup, only one canonical folder should exist:
`Scripts/IFLS_Workbench/`
