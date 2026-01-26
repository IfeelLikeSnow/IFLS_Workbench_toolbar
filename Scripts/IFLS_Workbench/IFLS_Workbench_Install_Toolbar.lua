-- @description IFLS Workbench: IFLS_Workbench_Install_Toolbar
-- @version 1.0.0

ï»¿-- @description IFLS Workbench: Install helpers (register scripts + open Action List / generate toolbar file)
-- @version 1.2
-- @author I feel like snow
-- @about
--   Convenience helper after installing via ReaPack/ZIP:
--   1) Registers IFLS Workbench scripts into the Action List.
--   2) Opens the Action List (so you can search/add to toolbars).
--   3) Optional: generate a Floating Toolbar import file (.ReaperMenu).
--

local r = reaper
local sep = package.config:sub(1,1)

local function join(a, b)
  if not a or a == "" then return b end
  local last = a:sub(-1)
  if last == "/" or last == "\\" then return a .. b end
  return a .. sep .. b
end

local function script_dir()
  local src = debug.getinfo(1, "S").source
  src = src:gsub("^@", "")
  return src:match("^(.*)[/\\].-$") or r.GetResourcePath()
end

local function is_excluded_dir(name)
  name = (name or ""):lower()
  return name == "lib" or name == "_private" or name == ".git"
end

local function collect_scripts(dir, out)
  out = out or {}

  local i = 0
  while true do
    local fn = r.EnumerateFiles(dir, i)
    if not fn then break end
    if fn:lower():sub(-4) == ".lua" then
      table.insert(out, join(dir, fn))
    end
    i = i + 1
  end

  local j = 0
  while true do
    local dn = r.EnumerateSubdirectories(dir, j)
    if not dn then break end
    if not is_excluded_dir(dn) then
      collect_scripts(join(dir, dn), out)
    end
    j = j + 1
  end

  return out
end

local base = script_dir()
local scripts = collect_scripts(base, {})
table.sort(scripts)

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

local added = 0
local total = #scripts
for idx, p in ipairs(scripts) do
  local sp = p:gsub("\\", "/") -- normalize
  local commit = (idx == total)
  local cmd_id = r.AddRemoveReaScript(true, 0, sp, commit)
  if cmd_id and cmd_id ~= 0 then added = added + 1 end
end

r.PreventUIRefresh(-1)
r.Undo_EndBlock("IFLS Workbench: register scripts", -1)

local info = string.format([[IFLS Workbench helper finished.

Registered/updated: %d scripts
Total found: %d

Next:
- Actions > Show action list... and search for "IFLS".
- Add the scripts to a toolbar via: right-click toolbar > Customize... > Add.]], added, total)


-- Try to install FXChains/MenuSets assets from the Data cache (ReaPack "Assets" package).
do
  local assets = r.GetResourcePath() .. "/Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Install_Assets_From_Data.lua"
  local f = io.open(assets, "rb")
  if f then
    f:close()
    IFLSWB_ASSETS_DO_NOT_AUTORUN = true
    pcall(dofile, assets)
    if type(IFLSWB_InstallAssetsFromData) == "function" then
      pcall(IFLSWB_InstallAssetsFromData, {silent=true})
    end
    IFLSWB_ASSETS_DO_NOT_AUTORUN = nil
  end
end

local ret = r.ShowMessageBox(info .. "\n\nGenerate a Floating Toolbar import file now?", "IFLS Workbench", 4)
if r.ShowActionList then r.ShowActionList() end

if ret == 6 then
  local gen = r.GetResourcePath() .. "/Scripts/IFLS_Workbench/IFLS_Workbench_Toolbar_Generate_ReaperMenu.lua"
  local f = io.open(gen, "rb")
  if f then f:close(); dofile(gen) end
end
