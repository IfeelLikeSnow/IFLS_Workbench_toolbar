-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Tools/Diagnostics/IFLS_Workbench_Cleanup_Duplicate_Workbench_Scripts.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS: Cleanup helper (find duplicate IFLS scripts)
-- @version 0.1
-- @author I feel like snow
-- @about
--   Safe cleanup helper for "duplicate script installs":
--   - Finds multiple copies of common IFLS scripts in REAPER/Scripts
--   - Opens the Scripts folder so you can remove old copies manually

--
local r = reaper
local res = r.GetResourcePath()
local scripts_dir = res .. "/Scripts"

local function msg(s) r.ShowConsoleMsg(tostring(s) .. "\n") end

local sep = package.config:sub(1,1)

local function scan_for(filename)
  local hits = {}
  local cmd = (sep == "\\")
    and ('dir /b /s "'..scripts_dir..'\\'..filename..'" 2>nul')
    or ('find "'..scripts_dir..'" -type f -name "'..filename..'" 2>/dev/null')
  local p = io.popen(cmd)
  if not p then return hits end
  for line in p:lines() do
    if line and line ~= "" then table.insert(hits, line) end
  end
  p:close()
  return hits
end

msg("=== IFLS Cleanup (duplicates) ===")
local suspects = {
  "IFLS_Workbench_Install_Toolbar.lua",
  "IFLS_Workbench_PolyWAV_Toolbox.lua",
  "IFLS_Workbench_Explode_Fieldrec.lua",
  "IFLS_Workbench_Slice_Direct.lua",
  "IFLS_Workbench_Menu_Slicing_Dropdown.lua",
}

local any=false
for _,fn in ipairs(suspects) do
  local hits = scan_for(fn)
  if #hits > 1 then
    any=true
    msg("\n" .. fn .. " -> " .. #hits .. " copies:")
    for _,h in ipairs(hits) do msg("  - " .. h) end
  end
end

if not any then
  msg("\nNo obvious duplicates found. ðŸŽ‰")
else
  msg("\nRecommendation: keep ONLY the newest copy (this repo), delete older duplicates.")
end

-- Open Scripts folder (SWS preferred; fallback to OS)
if r.CF_ShellExecute then
  r.CF_ShellExecute((scripts_dir:gsub("/", sep)))
else
  r.ShowMessageBox("Open this folder manually:\n\n"..scripts_dir, "IFLS Cleanup", 0)
end
