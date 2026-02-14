-- @description IFLS Workbench - Tools/Diagnostics/IFLS_Workbench_Diagnostics.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS: Diagnostics (ReaPack/Dependencies/Paths)
-- @version 0.1
-- @author I feel like snow
-- @about
--   Prints a quick diagnostics report for common IFLS Workbench install issues:
--   - Missing dependencies (ReaImGui, SWS, ReaPack)
--   - Missing IFLS script files
--   - Duplicate installs (same filename in multiple folders)
--   Safe: does not modify anything.

--
--
local r = reaper

local function msg(s) r.ShowConsoleMsg(tostring(s) .. "\n") end

local function exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

local function find_files_by_name(root, filename, out)
  out = out or {}
  local sep = package.config:sub(1,1)

  local function scan(dir)
    local p = io.popen((sep == "\\" and ('dir /b /s "'..dir..'"') or ('find "'..dir..'" -type f')))
    if not p then return end
    for line in p:lines() do
      if line:lower():sub(-#filename) == filename:lower() then
        table.insert(out, line)
      end
    end
    p:close()
  end

  scan(root)
  return out
end

local res = r.GetResourcePath()
msg("=== IFLS Diagnostics ===")
msg("REAPER: " .. (r.GetAppVersion() or "?"))
msg("Resource path: " .. res)

-- dependencies
local deps = {
  {name="ReaImGui", ok = (r.ImGui_CreateContext ~= nil)},
  {name="SWS (optional but recommended)", ok = (r.CF_ShellExecute ~= nil)},
  {name="ReaPack (recommended)", ok = (r.ReaPack_GetVersion ~= nil)},
}
msg("\nDependencies:")
for _,d in ipairs(deps) do
  msg(string.format("  - %-28s : %s", d.name, d.ok and "OK" or "MISSING"))
end

-- key IFLS files
local must = {
  "Scripts/IFLS_Workbench/IFLS_Workbench_Explode_Fieldrec.lua",
  "Scripts/IFLS_Workbench/IFLS_Workbench_PolyWAV_Toolbox.lua",
  "Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slice_Direct.lua",
  "Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Menu_Slicing_Dropdown.lua",
  "Scripts/IFLS_Workbench/IFLS_Workbench_Install_Toolbar.lua",
}
msg("\nCore IFLS files:")
for _,rel in ipairs(must) do
  local p = res .. "/" .. rel
  msg(string.format("  - %-90s : %s", rel, exists(p) and "OK" or "MISSING"))
end

-- duplicates (common when zips are extracted twice or old repos still present)
msg("\nDuplicate filename scan (IFLS_*):")
local suspects = {
  "IFLS_Workbench_Install_Toolbar.lua",
  "IFLS_Workbench_PolyWAV_Toolbox.lua",
  "IFLS_Workbench_Explode_Fieldrec.lua",
  "IFLS_Workbench_Slice_Direct.lua",
  "IFLS_Workbench_Menu_Slicing_Dropdown.lua",
}

local dup_found = false
for _,fn in ipairs(suspects) do
  local hits = find_files_by_name(res .. "/Scripts", fn, {})
  if #hits > 1 then
    dup_found = true
    msg("  * " .. fn .. " (found " .. #hits .. " copies):")
    for _,h in ipairs(hits) do msg("      - " .. h) end
  end
end
if not dup_found then
  msg("  (no obvious duplicates found)")
end

msg("\nIf you see:")
msg("  - 'Could not resolve hostname: Scripts' -> your index.xml has invalid URLs (needs full raw.githubusercontent.com URLs).")
msg("  - 'URL rejected: Malformed input' -> your index.xml has leading/trailing spaces in <source> URLs.")
msg("  - 'Conflict: ... already owned by another package' -> uninstall old IFLS packages in ReaPack first, then reinstall.")
msg("\nDone.")
