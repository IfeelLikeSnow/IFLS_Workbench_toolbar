-- @description IFLS PSS-580 - Project Recall: Apply (send stored .syx)
-- @version 1.05.0
-- @author IFLS
local r=reaper
if not r.SNM_SendSysEx then r.MB("SWS required (SNM_SendSysEx).", "PSS Project Recall", 0); return end
local rv, p = r.GetProjExtState(0, "IFLS_PSS580", "RECALL_SYX_PATH")
if rv~=1 or not p or p=="" then r.MB("No recall path stored for this project.", "PSS Project Recall", 0); return end
local f=io.open(p,"rb"); if not f then r.MB("Cannot read:\n"..p, "PSS Project Recall", 0); return end
local blob=f:read("*all"); f:close()
r.SNM_SendSysEx(blob)
r.MB("Sent recall SysEx:\n"..p, "PSS Project Recall", 0)
