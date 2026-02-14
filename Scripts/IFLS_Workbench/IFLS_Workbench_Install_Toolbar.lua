-- @description IFLS Workbench - IFLS_Workbench_Install_Toolbar.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Install helper (register scripts + toolbar setup)
-- @version 1.2.1
-- @author I feel like snow
-- @about
--   Runs after installing via ReaPack or ZIP:
--   - Registers scripts into the Action List
--   - Installs assets / generates menus (if present)
--   If a nested/wrong ZIP install is detected, it offers to run Install Doctor.

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

-- Detect nested manual installs (e.g. .../Scripts/IFLS_Workbench_Toolbar/Scripts/IFLS_Workbench/...)
local rp = r.GetResourcePath()
local function norm(p) return (p or ""):gsub("\","/"):lower() end
local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

local nb = norm(base)
local nested = false
do
  local first = nb:find("/scripts/")
  if first then
    local second = nb:find("/scripts/", first+1)
    if second then nested = true end
  end
  if nb:find("/scripts/ifls_workbench_toolbar") or nb:find("/scripts/ifls workbench toolbar") then
    nested = true
  end
end

if nested then
  local doc = join(base, "Tools/Diagnostics/IFLS_Workbench_InstallDoctor_Fix_Nested_Folders.lua")
  local msg = "Nested/wrong ZIP install detected.

" ..
              "Your current path is:
  " .. base .. "

" ..
              "This usually happens when a GitHub ZIP was extracted into <ResourcePath>/Scripts/
" ..
              "creating an extra wrapper folder (e.g. IFLS_Workbench_Toolbar).

" ..
              "Run Install Doctor now to merge everything back to:
  " .. join(rp, "Scripts/IFLS_Workbench") .. "

" ..
              "Recommended: YES (then restart REAPER)."
  local ret = r.ShowMessageBox(msg, "IFLS Workbench - Install helper", 4)
  if ret == 6 then
    if file_exists(doc) then
      dofile(doc)
    else
      r.ShowMessageBox("InstallDoctor script not found at:
" .. doc .. "

Please run it from:
Scripts/IFLS_Workbench/Tools/Diagnostics/ (if already installed correctly).", "IFLS Workbench - Install helper", 0)
    end
  end
  return
end

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
