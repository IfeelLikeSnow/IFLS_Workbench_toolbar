# V35 Research Queue Tool + Generated Issues

Timestamp: 2026-02-03T04:39:05Z

## Added
1) ReaImGui tool:
- Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Research_Queue.lua

Reads:
- REAPER_RESOURCE/Data/IFLS_Workbench/Reports/unknown_pedals_tasklist.csv (preferred)
Fallback:
- REAPER_RESOURCE/Reports/V34_unknown_pedals_tasklist.csv

Actions:
- Search/filter list
- Copy search queries (newline separated)
- Copy issue template text
- Open profile path location (Explorer/Finder)

## Tasklist now also mirrored into REAPER Data folder
- Data/IFLS_Workbench/Reports/unknown_pedals_tasklist.csv
- Data/IFLS_Workbench/Reports/unknown_pedals_tasklist.xlsx

## GitHub helper
- .github/ISSUES_GENERATED/*.md (one per unknown pedal)

## Add to REAPER toolbar (recommended)
1. Actions → Show action list
2. ReaScript: Load → select IFLS_Workbench_Research_Queue.lua
3. Add to toolbar

