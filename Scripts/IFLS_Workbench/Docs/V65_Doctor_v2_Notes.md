# V65 Notes - Doctor v2

Generated: 2026-02-06T15:03:45.697601Z

## Added
- Tools/IFLS_Workbench_Doctor_v2.lua
  - Install path check (expects Scripts/IFLS_Workbench/)
  - Dependency detection:
    - SWS (SNM_SendSysEx / CF_GetSWSVersion)
    - ReaImGui (ImGui_CreateContext)
    - JS_ReaScriptAPI (JS_* functions)
    - ReaPack (heuristic: reapack dll in UserPlugins)
  - Key file checks (_bootstrap, SafeApply, schemas, manifests, FULL package descriptor)
  - Console report + optional ReaImGui GUI
  - Clipboard copy (if ImGui clipboard functions available)

## Deep syntax scan
- Lua files scanned: 192
- Findings: 0
- None
