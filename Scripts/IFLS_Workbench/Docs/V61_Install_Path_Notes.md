# V61 Install Layout Notes

Generated: 2026-02-06T14:37:35.156624Z

## Install path (REAPER)
Unzip so that this folder lands at:

REAPER/ResourcePath/Scripts/IFLS_Workbench/

Example:
- .../Scripts/IFLS_Workbench/_bootstrap.lua
- .../Scripts/IFLS_Workbench/Tools/...
- .../Scripts/IFLS_Workbench/Engine/...
- .../Scripts/IFLS_Workbench/Workbench/FB01/...
- .../Scripts/IFLS_Workbench/Workbench/PSS580/...

## Changes from V60 zip-layout
- Removed the extra top-level `Scripts/` container. The Workbench now sits directly under `Scripts/IFLS_Workbench/`.
- Updated JSON validator path for FB01 manifest accordingly.

## Deep Syntax Scan
- Lua files scanned: 190
- Leading-backslash fixes: 2
- Remaining findings: 0
- None
