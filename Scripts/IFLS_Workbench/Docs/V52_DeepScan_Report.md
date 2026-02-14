# V52 Deep Scan Report (Repo-wide)

Generated: 2026-02-05T13:07:33.372593Z

This report covers **the whole merged repo ZIP**, not only FB-01 patches. It focuses on:
- syntax/safety checks for Lua ReaScripts
- dependency guards (SWS/ReaImGui/JS)
- SysEx correctness risks
- suggested next engineering steps (governance + tests)

## Inventory
- Lua scripts found: 29
- Uses ReaImGui: 11
- Uses SWS SysEx: 12
- Uses JS_ReaScriptAPI dialogs: 3

## Key fixes included in V52
1) **Removed accidental leading backslash** from V51 added scripts (was a hard syntax error).
2) Added **ReaImGui guards** to:
   - `Workbench/FB01/Pack_v2/Scripts/IFLS_FB01_CC_MixPanel.lua`
   - `Workbench/FB01/Pack_v3/Scripts/IFLS_FB01_SysEx_Toolkit.lua`
   - `Workbench/FB01/Pack_v5/Scripts/IFLS_FB01_SysEx_Toolkit.lua`
3) Upgraded `IFLS_FB01_AutoDump_Record_Adaptive.lua` to **V52**:
   - auto-select latest recorded item
   - optional **auto-export** `.syx` into project directory (frames SysEx correctly)

## SysEx correctness (important)
REAPER's ReaScript API documents that SysEx text/sysex events are typically **payload without F0/F7**. citeturn0search0  
V50 already fixed export/store/import to frame/unframe safely; V52 keeps that invariant and extends it in AutoDump export.

## Workbench (non-FB01) tools – Observations
The Workbench toolset under `Scripts/IFLS_Workbench/Tools` is structured well (viewer, chain builder, recall/apply, conflict view).
Common operational risks in production:
- **Missing dependency guards** (ReaImGui / SWS) in some entrypoints (now mitigated via Doctor script).
- **Hard-coded paths** for JSON locations can break when repo layout evolves.
- **No unit-test / self-test** scripts: regressions are easy when adding new device types.

### Top REAPER APIs used (by frequency)


## New in V52: Workbench Doctor
`Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Doctor.lua`
- Prints a console report and a summary dialog:
  - SWS present?
  - ReaImGui present?
  - JS_ReaScriptAPI present? (optional)
  - key Workbench files + JSONs present?

This gives you a **single “first-run health check”** for any machine.

## Recommended engineering roadmap (the “rest”)
### A) Make data paths resilient
- Centralize paths in one module (e.g. `Scripts/IFLS_Workbench/_bootstrap.lua`)
- Let tools resolve:
  - `Data/gear.json`, `Data/patchbay.json`, `Data/profiles/*.json`
  - fallback search + user-config path in ExtState

### B) Add a self-test suite (in REAPER)
Create scripts that run without hardware:
- JSON schema validation (gear + patchbay)
- routing engine conflict tests (pure Lua)
- UI smoke test (open/close ImGui loop safely)

### C) Better safety for “Apply”
For routing/recall tools:
- Always wrap Apply inside `Undo_BeginBlock2/Undo_EndBlock2`
- Optional “dry-run plan” view + diff of what will change
- Rollback if an API call fails mid-apply

### D) FB-01 Librarian (next after V52)
Now that capture/export/replay is robust:
- parse bank dumps into 48 patch names (needs one real recorded dump to verify offsets)
- tag & search inside Workbench
- integrate with Chain Builder (choose patch + hardware chain + VST chain)

## Known remaining uncertainties (needs real dump evidence)
- Whether your recorded FB-01 dumps arrive as:
  - one large framed message, or
  - multiple frames, or
  - unframed payload chunks
V52 tools handle all of these operationally (export/replay), but **name parsing (V53+)** requires a confirmed format.

