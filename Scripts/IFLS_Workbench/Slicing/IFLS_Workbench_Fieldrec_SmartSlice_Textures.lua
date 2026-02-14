-- @description IFLS Workbench - Slicing/IFLS_Workbench_Fieldrec_SmartSlice_Textures.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench - Fieldrec SmartSlice (TEXTURES) [v3]
-- @version 3.0.0
-- @author IFLS Workbench
-- @about
--   Slices selected items (or items on selected tracks) into longer chunks for textures/scrapes.
--   Includes: iterative threshold calibration + hysteresis/backtrack + HQ zero-cross snap (toggle).
--   HQ toggle is stored in ExtState (IFLSWB_SmartSlicer/HQ). Default is ON in v3.

--

local core = dofile((reaper.GetResourcePath().."/Scripts/IFLS_Workbench/Slicing/IFLSWB_Fieldrec_SmartSlicer_Core.lua"))
core.run("textures")
