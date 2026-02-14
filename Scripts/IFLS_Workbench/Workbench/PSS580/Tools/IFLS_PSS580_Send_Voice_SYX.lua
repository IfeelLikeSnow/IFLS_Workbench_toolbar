-- @description IFLS PSS-580 - Send Voice .syx (72-byte dump)
-- @version 1.01.0
-- @author IFLS
local r=reaper
if not r.SNM_SendSysEx then r.MB("SWS not found.", "PSS Send", 0); return end
local ok, path = r.GetUserFileNameForRead("", "Select PSS-x80 voice .syx", ".syx")
if not ok or path=="" then return end
local f=io.open(path,"rb"); if not f then r.MB("Cannot read.", "PSS Send", 0); return end
local blob=f:read("*all"); f:close()
r.SNM_SendSysEx(blob)
r.MB("Sent file (as-is):\n"..path, "PSS Send", 0)
