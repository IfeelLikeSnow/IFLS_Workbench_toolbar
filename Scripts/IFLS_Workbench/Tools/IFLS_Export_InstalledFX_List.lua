-- @description IFLS: Export Installed FX list (EnumInstalledFX)
-- @version 1.0
-- @author IFLS

local fn = reaper.GetResourcePath() .. "/IFLS_InstalledFX_List.txt"
local f = io.open(fn, "w")
if not f then
  reaper.MB("Kann Datei nicht schreiben:\n" .. fn, "IFLS", 0)
  return
end

if not reaper.EnumInstalledFX then
  f:write("EnumInstalledFX nicht verfügbar in dieser REAPER-Version.\n")
  f:close()
  reaper.MB("EnumInstalledFX nicht verfügbar.\nBitte REAPER 7.x verwenden.", "IFLS", 0)
  return
end

local i = 0
while true do
  local ok, name, ident = reaper.EnumInstalledFX(i)
  if not ok then break end
  f:write(string.format("%05d\t%s\t%s\n", i, name or "", ident or ""))
  i = i + 1
end

f:close()
reaper.MB("Export fertig:\n" .. fn, "IFLS", 0)
