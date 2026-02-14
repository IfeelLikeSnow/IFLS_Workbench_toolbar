# V79: Smart Hub UX Upgrade

Generated: 2026-02-07T21:18:24.128308Z

## What changed
- Hub rewritten to:
  - show dependency status (ReaImGui / SWS)
  - disable buttons when dependencies are missing
  - provide quick actions (Doctor, Port Matcher, Export Wiring)
  - optional: show/hide script paths

## Dependency detection
- ReaImGui: checks `reaper.ImGui_CreateContext`
- SWS: checks `reaper.CF_ShellExecute`

## Notes
- Buttons include per-item `requires` metadata.
- If ReaImGui is missing entirely, Hub prints a launch list to REAPER console (fallback mode).
