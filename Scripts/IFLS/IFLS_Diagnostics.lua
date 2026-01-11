-- IFLS_Diagnostics.lua
-- Simple diagnostic helper (safe: read-only)
local r = reaper

local function msg(s) r.ShowConsoleMsg(tostring(s) .. "\n") end

r.ClearConsole()

msg("IFLS Diagnostics")
msg("----------------")
msg("REAPER resource path: " .. (r.GetResourcePath() or ""))
msg("ReaPack installed: " .. (r.APIExists and tostring(r.APIExists("ReaPack_BrowsePackages")) or "unknown"))
msg("ReaImGui installed: " .. (r.APIExists and tostring(r.APIExists("ImGui_CreateContext")) or "unknown"))

-- List potential duplicate IFLS scripts by filename (read-only)
local script_root = r.GetResourcePath() .. "/Scripts"
local targets = { "IFLS_Workbench", "IFLS" }

local function collect_lua_files(dir, out)
  out = out or {}
  local i = 0
  while true do
    local fn = r.EnumerateFiles(dir, i)
    if not fn then break end
    if fn:lower():match("%.lua$") then
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

local all = collect_lua_files(script_root, {})
local by_base = {}
for _, p in ipairs(all) do
  local base = p:match("([^/\\]+)$") or p
  by_base[base] = by_base[base] or {}
  table.insert(by_base[base], p)
end

local dup_count = 0
for base, paths in pairs(by_base) do
  if #paths > 1 and base:lower():find("ifls") then
    dup_count = dup_count + 1
    msg("")
    msg("DUPLICATE: " .. base)
    for _, p in ipairs(paths) do msg("  " .. p) end
  end
end

msg("")
msg("Duplicate IFLS filenames found: " .. dup_count)
r.ShowMessageBox("Diagnostics written to REAPER console.\n\nOpen: View -> Console", "IFLS Diagnostics", 0)
