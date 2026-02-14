-- @description IFLS Workbench - Tools/IFLS_Workbench_Doctor.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_Workbench_Doctor.lua
-- V52: Environment + repository sanity checker.
-- Prints findings to REAPER console and shows a summary dialog.
--
-- Checks:
-- - SWS installed?
-- - ReaImGui installed?
-- - JS_ReaScriptAPI installed? (optional)
-- - Required IFLS files present (routing engine, core JSONs)
-- - SysEx support note
--
-- Safe: does not modify project.

local r = reaper
local Boot_ok, Boot = pcall(require, "IFLS_Workbench/_bootstrap")
if not Boot_ok then Boot = nil end


local function ok(b) return b and "OK" or "MISSING" end
local function msg(s) r.ShowConsoleMsg(tostring(s).."\n") end

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local resource = r.GetResourcePath()
local scripts_root = resource .. "/Scripts"
local data_root = (Boot and Boot.get_data_root and Boot.get_data_root()) or (scripts_root.."/IFLS_Workbench/Data")

local checks = {}
local function add(name, pass, detail)
  checks[#checks+1] = {name=name, pass=pass, detail=detail or ""}
end

add("SWS (SNM_SendSysEx)", r.SNM_SendSysEx ~= nil, "Needed for SysEx send + FB-01 tools.")
add("ReaImGui (ImGui_CreateContext)", r.ImGui_CreateContext ~= nil, "Needed for Workbench GUIs + some panels.")
add("JS_ReaScriptAPI (JS_Dialog...)", r.JS_Dialog_BrowseForOpenFiles ~= nil, "Optional: nicer file pickers.")

-- Core workbench file presence
add("IFLS RoutingEngine", file_exists(scripts_root.."/IFLS_Workbench/Engine/IFLS_Patchbay_RoutingEngine.lua"),
    "Required for Patchbay as routing engine.")
add("Workbench Tools", file_exists(scripts_root.."/IFLS_Workbench/Tools/IFLS_Workbench_Gear_And_Patchbay_View.lua"),
    "Main viewer tool.")

-- JSON data presence (best effort)
add("gear.json", file_exists(data_root.."/gear.json"),
    "Device list / profiles (if your repo places it elsewhere, adjust).")
add("patchbay.json", file_exists(data_root.."/patchbay.json"),
    "Patchbay matrix / routing model.")

msg("")
msg("=== IFLS Workbench Doctor (V52) ===")
msg("ResourcePath: "..resource)
for _,c in ipairs(checks) do
  msg(string.format("%-28s  %s  %s", c.name, ok(c.pass), c.detail))
end

local missing = {}
for _,c in ipairs(checks) do if not c.pass then missing[#missing+1]=c.name end end

local summary
if #missing == 0 then
  summary = "All critical checks passed."
else
  summary = "Missing:\n- "..table.concat(missing, "\n- ")
end

r.MB(summary.."\n\nSee REAPER Console for full details.", "IFLS Workbench Doctor", 0)
