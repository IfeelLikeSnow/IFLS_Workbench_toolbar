# V55 Merge: IFLS_Workbench + IFLS_Workbench_toolbar

Generated: 2026-02-06T11:52:18.801873Z

## What was merged
- Base: IFLS_Workbench_Repo_Merge_FB01_v54_ALL_IN_ONE.zip
- Added: IFLS_Workbench_toolbar (main branch ZIP)

## Where toolbar repo lives now
- Full source: `Workbench/ToolbarRepo/`
- Installed scripts copied into: `Scripts/` (same relative layout as in toolbar repo)

## Entry point
- New convenience installer script:
  - `Scripts/IFLS_Workbench/Toolbar/IFLS_Workbench_Toolbar_Installer_Entry.lua`
  - Runs `Scripts/IFLS_Workbench/IFLS_Workbench_Install_Toolbar.lua` (from toolbar repo)

## Deep syntax scan
- Performed before packaging:
  - Leading-backslash syntax blockers: none found
  - Guard issues (SWS/ReaImGui/JS): none found by heuristic scan
  - Risky SysEx API signature patterns: none found by heuristic scan

Note: A full Lua parser-based lint (Luacheck) is already included via CI in V54; run it in GitHub CI or locally for authoritative lint results.
