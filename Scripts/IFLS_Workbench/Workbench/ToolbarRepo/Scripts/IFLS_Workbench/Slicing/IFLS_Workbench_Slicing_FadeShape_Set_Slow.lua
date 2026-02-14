-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_FadeShape_Set_Slow.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Slicing FadeShape Set â€“ Slow (10/14 ms)
-- @version 1.0
-- @about Auto-added @about (please replace with a real description).

local set = dofile((reaper.GetResourcePath().."/Scripts/IFLS_Workbench/Slicing/_IFLS_Slicing_FadeCommon.lua"))
set("slow", 10, 14)
