-- @description IFLS Workbench - Fieldrec SmartSlice HQ Toggle (Zero-Cross Snap) [v3]
-- @version 3.0.0
-- @author IFLS Workbench
-- @about Toolbar toggle for HQ Mode. HQ = snap split points to nearest zero crossing.

-- Register as a toggle action:
-- The action state is persisted using ExtState IFLSWB_SmartSlicer/HQ (default ON).

local core = dofile(reaper.GetResourcePath().."/Scripts/IFLS_Workbench/Slicing/IFLSWB_Fieldrec_SmartSlicer_Core.lua")
core.toggle_hq()
