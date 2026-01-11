# IFLS Workbench Toolbar

REAPER Workbench scripts + assets (MicFX + Slicing) with toolbar generator.

## Install (manual)
Extract this ZIP into your REAPER resource folder:
`Options -> Show REAPER resource path...`

It will create/update:
- Scripts/IFLS_Workbench/...
- Scripts/IFLS/...
- FXChains/IFLS Workbench/...
- Effects/IFLS Workbench/...
- Data/IFLS Workbench/...
- MenuSets/...

## Toolbar
Run:
`Scripts/IFLS_Workbench/IFLS_Workbench_Toolbar_Generate_ReaperMenu.lua`

Then import the generated `.ReaperMenu` from `MenuSets/`.

## Notes
Avoid having a second copy under `Scripts/IFLS_Workbench_toolbar/...` (duplicates).
