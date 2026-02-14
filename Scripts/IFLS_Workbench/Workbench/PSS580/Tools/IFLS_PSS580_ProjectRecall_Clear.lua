-- @description IFLS PSS-580 - Project Recall: Clear
-- @version 1.05.0
-- @author IFLS
local r=reaper
r.SetProjExtState(0, "IFLS_PSS580", "RECALL_SYX_PATH", "")
r.MB("Cleared project recall path.", "PSS Project Recall", 0)
