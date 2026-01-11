-- @description IFLS Workbench: Syntax scan (loadfile) for all .lua scripts in this repo folder
-- @version 1.0.0
-- @author IFLS
-- @about
--   Runs Lua "loadfile" on every .lua in Scripts/IFLS_Workbench and prints syntax errors to ReaScript console.

local r = reaper

local function msg(s) r.ShowConsoleMsg(tostring(s).."\n") end
local function join(a,b)
  local sep = package.config:sub(1,1)
  if a:sub(-1) ~= sep then a=a..sep end
  return a..b
end

local base = join(r.GetResourcePath(), "Scripts")
local target = join(base, "IFLS_Workbench")

-- simple recursive directory walk
local function walk(dir, out)
  local i = 0
  while true do
    local f = r.EnumerateFiles(dir, i)
    if not f then break end
    if f:sub(-4):lower() == ".lua" then
      out[#out+1] = join(dir, f)
    end
    i=i+1
  end
  i = 0
  while true do
    local sub = r.EnumerateSubdirectories(dir, i)
    if not sub then break end
    walk(join(dir, sub), out)
    i=i+1
  end
end

local files={}
walk(target, files)
table.sort(files)

msg("=== IFLS Syntax Scan ===")
msg("Folder: "..target)
msg("Files: "..tostring(#files))
msg("")

local ok_count, err_count = 0, 0
for _,path in ipairs(files) do
  local chunk, err = loadfile(path)
  if chunk then
    ok_count = ok_count + 1
  else
    err_count = err_count + 1
    msg("ERROR: "..path)
    msg("  "..tostring(err))
    msg("")
  end
end

msg(string.format("Done. OK=%d  ERR=%d", ok_count, err_count))
