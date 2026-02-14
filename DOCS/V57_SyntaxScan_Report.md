# V57 Deep Syntax Scan (Pre-zip)

Generated: 2026-02-06T12:02:30.370315Z

## Summary
- Lua files scanned: 185
- Leading-backslash blockers fixed: 1
- Remaining findings (heuristic): 0

### Remaining findings
- None

## SafeApply adoption summary
Wrapped Undo blocks with SafeApply in:
- Scripts/IFLS_Workbench/Tools/IFLSWB_Create_Fieldrec_IDM_Template.lua
- Scripts/IFLS_Workbench/Tools/IFLSWB_RS5K_Rack_From_SelectedItems.lua
- Scripts/IFLS_Workbench/Tools/IFLS_Export_FX_ParamCatalog_NoMidiCC_Toggles_VST3Preferred.lua
- Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Chain_Builder_Wizard.lua
- Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Dump_All_FX_Params_EnumInstalledFX_PreferVST3_StrongMatch_Resume_CSV_NDJSON.lua
- Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Dump_All_FX_Params_EnumInstalledFX_Resume_CSV_NDJSON.lua
- Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Reamp_Print_Toggle_From_FXBus.lua
- Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Select_Items_On_IFLS_Slices_Tracks.lua
- Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Insert_JSFX_ifls_workbench_drone_granular_texture.lua
- Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Insert_JSFX_ifls_workbench_dynamic_meter_v1_peaknorm_out.lua
- Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Insert_JSFX_ifls_workbench_euclid_slicer_tempo_synced_euclidean_gate.lua
- Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Insert_JSFX_ifls_workbench_idm_chopper_tempo_synced_gate.lua
- Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Insert_JSFX_ifls_workbench_reampsuite_analyzer_fft.lua
- Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Menu_JSFX_All.lua
- Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Menu_JSFX_DSP_Tools.lua

Notes:
- Heuristic scan strips strings/comments and looks for common REAPER breakages.
- CI Luacheck (already in repo) remains the authoritative lint.
