-- @description IFLS: Diagnostics (ReaPack / ReaImGui / Paths)
-- @version 1.0.0
-- @author I feel like snow
-- @about
--   Quick sanity checks for IFLS packages:
--   - REAPER version / resource path
--   - ReaImGui availability
--   - Basic directory existence
--
--   Safe to run anytime.

local r = reaper

local function yesno(v) return v and "YES" or "NO" end

local lines = {}
local function add(s) lines[#lines+1] = tostring(s) end

add("IFLS Diagnostics")
add("----------------")
add("REAPER version: " .. (r.GetAppVersion() or "?"))
add("Resource path : " .. (r.GetResourcePath() or "?"))
add("")
add("ReaImGui installed: " .. yesno(type(r.ImGui_CreateContext) == "function"))
if type(r.ImGui_GetVersion) == "function" then
  add("ReaImGui version  : " .. tostring(r.ImGui_GetVersion()))
end
add("")
local scripts_path = r.GetResourcePath() .. "\\Scripts"
add("Scripts folder exists: " .. yesno(r.EnumerateFiles(scripts_path, 0) ~= nil))
add("")
add("If you see missing-script errors on toolbar buttons, it usually means:")
add("- you still have old actions pointing to deleted script paths, OR")
add("- your ReaPack index.xml contains relative/whitespace URLs (common).")
add("")
add("Next steps:")
add("1) Extensions > ReaPack > Manage repositories: remove old IFLS repos")
add("2) Import the repo again using the raw index.xml URL")
add("3) ReaPack: Synchronize packages")

r.ClearConsole()
for _,l in ipairs(lines) do
  r.ShowConsoleMsg(l .. "\n")
end
r.MB(table.concat(lines, "\n"), "IFLS Diagnostics", 0)
