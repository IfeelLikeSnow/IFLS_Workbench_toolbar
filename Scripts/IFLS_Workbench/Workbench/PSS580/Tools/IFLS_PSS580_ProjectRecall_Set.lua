-- @description IFLS PSS-580 - Project Recall: Set (store .syx path in project)
-- @version 1.05.0
-- @author IFLS
local r=reaper
local ok, p = r.GetUserFileNameForRead("", "Select .syx to recall with this project", ".syx")
if not ok or p=="" then return end
r.SetProjExtState(0, "IFLS_PSS580", "RECALL_SYX_PATH", p)
r.MB("Stored in project extstate:\n"..p, "PSS Project Recall", 0)
