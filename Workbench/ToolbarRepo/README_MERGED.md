# IFLSWB Merged All-in-One Pack

This ZIP is a consolidated kit built by comparing multiple IFLSWB patch/pack zips.
It keeps the newest/most relevant scripts and omits legacy duplicates.

## Included (current)
### Fieldrec SmartSlicer v3 (recommended)
- Scripts/IFLS_Workbench/Slicing/IFLSWB_Fieldrec_SmartSlicer_Core.lua
- Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_Hits.lua
- Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_Textures.lua
- Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_ModeMenu.lua
- Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_HQ_Toggle.lua (toolbar toggle)

### Reamp Print (FX Bus -> Print Track)
- Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Reamp_Print_Toggle_From_FXBus.lua

### PrintBus Smart Slice (pre-analyze + peak tail detect) - patched
- Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.lua

### Helpers / Templates
- Tools/IFLSWB_Generate_Fieldrec_SmartSlicer_Toolbar_ReaperMenu.lua
- Tools/IFLSWB_SmartSlicer_Store_CommandIDs_Helper.lua
- Tools/IFLSWB_Create_Fieldrec_IDM_Template.lua
- Tools/IFLSWB_RS5K_Rack_From_SelectedItems.lua
- TrackTemplates/IFLSWB_Fieldrec_Slice_RS5k_Rack_Template.RTrackTemplate

### Optional tooling
- tools/Apply-IFLSWB-SmartSlicing-Upgrade.ps1
- reaper/IFLSWB_TestSuite_CompileAll.lua

## Omitted legacy files
See CLEANUP_REPORT.csv for full details (what existed, what was kept, replacement hints).


## Reamp Print Toggle (Topology Auto-Find)
This build updates the Reamp Print script to detect FX/Coloring/Master buses via routing topology first (sends/receives graph), with name fallback.
