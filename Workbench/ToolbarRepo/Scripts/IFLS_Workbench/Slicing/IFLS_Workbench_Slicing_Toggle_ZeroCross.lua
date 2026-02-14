-- @version 0.0.1


-- @description IFLS Workbench: Toggle Zero-Cross Respect (Slicing)
-- @version 1.0
-- @about Auto-added @about (please replace with a real description).

local r = reaper
local _, v = r.GetProjExtState(0, "IFLS_SLICING", "ZC_RESPECT")
local new = (v == "1") and "0" or "1"
r.SetProjExtState(0, "IFLS_SLICING", "ZC_RESPECT", new)
r.ShowConsoleMsg(string.format("[IFLS] Zero-Cross Respect: %s\n", (new=="1") and "ON" or "OFF"))
