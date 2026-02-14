# V53 – Roadmap & Governance Additions (Deep Scan)

Generated: 2026-02-05T17:06:56.035844Z

## What V53 adds
- `Scripts/IFLS_Workbench/_bootstrap.lua` (central path/deps/helpers)
- `Scripts/IFLS_Workbench/Engine/IFLS_SafeApply.lua` (undo + safe apply wrapper)
- `Scripts/IFLS_Workbench/Tools/IFLS_Workbench_SelfTest.lua` (offline tests)
- Doctor updated to use bootstrap data path override when present

## Why
As the repo grows (more devices, routing logic, recall presets), you need:
1) A **single source of truth** for paths + dependency checks
2) A **repeatable test** you can run after updates
3) A **safe apply** wrapper so all project modifications are undoable and failures are user-friendly

## Recommended next steps (V54+)
1) **JSON schema validation**
   - Ship schemas for `gear.json`, `patchbay.json`, `profiles/*.json`
   - Validate in `SelfTest` and in CI.
2) **CI smoke test**
   - Lint Lua (luacheck) + run JSON schema check in GitHub Actions.
3) **Safe Apply adoption**
   - Wrap Recall-Apply, Conflict resolve, Chain insert operations in `SafeApply.run()`.
4) **Config UI**
   - Provide a small settings panel to set `data_root` override, default MIDI ports, etc.
