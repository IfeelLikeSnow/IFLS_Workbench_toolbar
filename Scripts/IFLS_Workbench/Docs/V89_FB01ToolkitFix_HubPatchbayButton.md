# V89: FB-01 toolkit fix + Hub integration + Patchbay button fix

Generated: 2026-02-09T16:44:01.874991Z

## FB-01
- Added missing launcher: `Workbench/FB01/Pack_v8/IFLS_FB01_Toolkit.lua`
- This fixes `Workbench/FB01/Current/IFLS_FB01_Toolkit_Current.lua` pointing to a missing file in v88.

## Hub
- Added device buttons:
  - FB-01 Toolkit (Current)
  - FB-01 Toolkit (Pack v8)
- Fixed Patchbay cheatsheet button placement (no longer nested inside ApplyPorts button block).

## Notes
- FB-01 Pack v8 toolkit uses `gfx.showmenu` to avoid ReaImGui dependency.
