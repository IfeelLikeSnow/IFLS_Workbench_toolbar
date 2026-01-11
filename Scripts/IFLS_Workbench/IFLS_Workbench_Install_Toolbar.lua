-- @description IFLS Workbench: Install helpers (register ALL scripts + open toolbar customization)
-- @version 1.1
-- @author I feel like snow
-- @about
--   Convenience helper after installing via ReaPack/ZIP:
--   1) Ensures the IFLS Workbench scripts are registered in the Action List.
--   2) Opens the toolbar customization dialog so you can add the actions quickly.
--
--   Note: ReaPack usually registers scripts automatically. This helper is safe to run anyway.

local r = reaper

local sep = package.config:sub(1,1)

local function script_dir()
  local src = debug.getinfo(1, "S").source
  return (src:match("@(.*[\\/])") or "")
end

local function register(path)
  -- section 0 = Main
  r.AddRemoveReaScript(true, 0, path, true)
end

local base = script_dir()

-- Recursively register every .lua script under this folder (except /lib)
local function is_excluded_dir(name)
  name = (name or ""):lower()
  return name == "lib" or name == "_private" or name == ".git"
end

local function join(a,b)
  if not a or a == "" then return b end
  local last = a:sub(-1)
  if last == "/" or last == "\" then return a .. b end
  return a .. sep .. b
end

local function collect_scripts(dir, out)
  out = out or {}
  -- files
  local i = 0
  while true do
    local fn = r.EnumerateFiles(dir, i)
    if not fn then break end
    if fn:lower():match("%.lua$") then
      out[#out+1] = (join(dir, fn))
    end
    i = i + 1
  end
  -- subdirs
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

local scripts = collect_scripts(base, {})
table.sort(scripts)

local added = 0
local total = #scripts
for idx, p in ipairs(scripts) do
  -- Normalize slashes
  local sp = p:gsub("\","/")
  -- Add to main section (0). Optimize commit for bulk add.
  local commit = (idx == total)
  local cmd_id = r.AddRemoveReaScript(true, 0, sp, commit)
  if cmd_id and cmd_id ~= 0 then added = added + 1 end
end

r.ShowMessageBox(
  string.format(
    "IFLS Workbench helper finished.

Registered/updated: %d scripts
Total found: %d

Next: Actions > Show action list... and search for 'IFLS Workbench'.
To add toolbar buttons: right-click a toolbar > Customize... > Add action.",
    added, total
  ),
  "IFLS Workbench", 0
)

-- Open toolbar customization window (native action)
-- Options: Customize toolbars...
r.Main_OnCommand(42174, 0)
