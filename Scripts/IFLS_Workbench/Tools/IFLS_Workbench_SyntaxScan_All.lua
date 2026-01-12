-- @description IFLS Workbench: Syntax scan all IFLS scripts (loadfile)
-- @version 1.0
-- @author IFLS
-- @about
--   Scans Scripts/IFLS_Workbench for .lua files and attempts to compile them with loadfile().
--   Writes a report to the REAPER console and to Scripts/IFLS_Workbench/_ParamDumps/syntax_scan.txt

local r = reaper

local function join(a,b) return a .. "/" .. b end

local function scandir(dir, out)
  local i = 0
  while true do
    local fn = r.EnumerateFiles(dir, i)
    if not fn then break end
    if fn:lower():sub(-4) == ".lua" then
      out[#out+1] = join(dir, fn)
    end
    i = i + 1
  end

  i = 0
  while true do
    local dn = r.EnumerateSubdirectories(dir, i)
    if not dn then break end
    if dn ~= "." and dn ~= ".." then
      scandir(join(dir, dn), out)
    end
    i = i + 1
  end
end

local base = (r.GetResourcePath() .. "/Scripts/IFLS_Workbench"):gsub("\\","/")
local out = {}
scandir(base, out)

local report = {}
report[#report+1] = "=== IFLS Syntax Scan ==="
report[#report+1] = "Base: " .. base
report[#report+1] = "Files: " .. tostring(#out)
report[#report+1] = ""

local errCount = 0
for _, path in ipairs(out) do
  local chunk, err = loadfile(path)
  if not chunk then
    errCount = errCount + 1
    report[#report+1] = "[ERROR] " .. path
    report[#report+1] = "        " .. tostring(err)
  end
end

report[#report+1] = ""
report[#report+1] = "Errors: " .. tostring(errCount)

local text = table.concat(report, "\n")
r.ShowConsoleMsg(text .. "\n")

local dumpDir = (r.GetResourcePath() .. "/Scripts/IFLS_Workbench/_ParamDumps"):gsub("\\","/")
r.RecursiveCreateDirectory(dumpDir, 0)
local f = io.open(dumpDir .. "/syntax_scan.txt", "w")
if f then f:write(text); f:close() end

r.ShowMessageBox("Syntax scan finished.\nErrors: " .. tostring(errCount) .. "\n\nSee console + _ParamDumps/syntax_scan.txt", "IFLS", 0)
