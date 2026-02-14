-- @description IFLS Workbench - Version Alignment Report (optional bump)
-- @version 0.82.0
-- @author IfeelLikeSnow
--
-- Scans Lua headers for @version and can optionally bump them to a target version.
-- Writes report to Docs/VersionAlignment_Report.md

local r = reaper

local function wb_root() return r.GetResourcePath().."/Scripts/IFLS_Workbench" end

local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end local d=f:read("*all"); f:close(); return d end
local function write_file(p,d) local f=io.open(p,"wb"); if not f then return false end f:write(d); f:close(); return true end

local function list_lua_files(dir)
  local files={}
  local i=0
  while true do
    local fn = r.EnumerateFiles(dir, i)
    if not fn then break end
    if fn:lower():match("%.lua$") then files[#files+1]=dir.."/"..fn end
    i=i+1
  end
  local j=0
  while true do
    local sub = r.EnumerateSubdirectories(dir, j)
    if not sub then break end
    local subdir = dir.."/"..sub
    local subfiles = list_lua_files(subdir)
    for _,p in ipairs(subfiles) do files[#files+1]=p end
    j=j+1
  end
  return files
end

local target = "0.82.0"
local bump = (r.MB("Create version alignment report.\n\nBump all @version headers to "..target.." ?", "Version Alignment", 4) == 6)

local root = wb_root()
local lua_files = list_lua_files(root)

local counts = {}
local changed = 0
local rows = {"# Version Alignment Report", "", "Target: `"..target.."`", "", "| file | version | bumped |", "|---|---:|---:|"}
for _,p in ipairs(lua_files) do
  local rel = p:gsub("^"..root.."/", "")
  local s = read_file(p) or ""
  local v = s:match("%-%-%s*@version%s+([%d%.]+)")
  v = v or "(none)"
  counts[v] = (counts[v] or 0) + 1
  local did = "no"
  if bump and v ~= target and v ~= "(none)" then
    local ns = s:gsub("(%-%-%s*@version%s+)([%d%.]+)", "%1"..target, 1)
    if ns ~= s then
      write_file(p, ns)
      changed = changed + 1
      did = "yes"
    end
  end
  rows[#rows+1] = ("| %s | %s | %s |"):format(rel, v, did)
end

rows[#rows+1] = ""
rows[#rows+1] = "## Summary"
for k,v in pairs(counts) do
  rows[#rows+1] = "- "..k..": "..tostring(v)
end
rows[#rows+1] = ""
rows[#rows+1] = "Changed files: "..tostring(changed)

local out = table.concat(rows, "\n")
local outp = root.."/Docs/VersionAlignment_Report.md"
write_file(outp, out)
r.ClearConsole(); r.ShowConsoleMsg(out.."\n")
r.MB("Wrote report:\n"..outp, "Version Alignment", 0)
