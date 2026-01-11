-- IFLS_Cleanup_Duplicate_IFLS_Scripts.lua
-- SAFETY: This script only REPORTS duplicates by default.
-- If you want auto-cleanup, modify at your own risk.
local r = reaper
local function msg(s) r.ShowConsoleMsg(tostring(s) .. "\n") end

r.ClearConsole()
msg("IFLS Cleanup (report-only)")
msg("--------------------------")
msg("This script does NOT delete anything. It only reports duplicates.")
msg("Run IFLS_Diagnostics.lua for a full report too.")

local script_root = r.GetResourcePath() .. "/Scripts"

local function collect_lua_files(dir, out)
  out = out or {}
  local i = 0
  while true do
    local fn = r.EnumerateFiles(dir, i)
    if not fn then break end
    if fn:lower():match("%.lua$") and fn:lower():find("ifls") then
      out[#out+1] = dir .. "/" .. fn
    end
    i = i + 1
  end
  i = 0
  while true do
    local sub = r.EnumerateSubdirectories(dir, i)
    if not sub then break end
    collect_lua_files(dir .. "/" .. sub, out)
    i = i + 1
  end
  return out
end

local files = collect_lua_files(script_root, {})
local map = {}
for _, p in ipairs(files) do
  local base = p:match("([^/\\]+)$") or p
  map[base] = map[base] or {}
  table.insert(map[base], p)
end

local dup = 0
for base, paths in pairs(map) do
  if #paths > 1 then
    dup = dup + 1
    msg("")
    msg("DUPLICATE: " .. base)
    for _, p in ipairs(paths) do msg("  " .. p) end
  end
end

msg("")
msg("Duplicate IFLS script names: " .. dup)
r.ShowMessageBox("Duplicate report written to Console.\n(No files were deleted.)", "IFLS Cleanup (report-only)", 0)
