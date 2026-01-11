-- @description IFLS: Diagnostics (paths + asset checks)
-- @version 1.0
-- @author I feel like snow
-- @about
--   Prints quick diagnostics to REAPER's console:
--   - Resource path
--   - ReaImGui availability
--   - IFLS Workbench MicFX asset presence (fxlists/json/fxchains)
--
local r = reaper

local function p(msg) r.ShowConsoleMsg(tostring(msg) .. "\n") end

local res = r.GetResourcePath()
local sep = package.config:sub(1,1)

p("=== IFLS Diagnostics ===")
p("REAPER resource path: " .. res)

-- ReaImGui
if r.ImGui_GetBuiltinPath then
  p("ReaImGui: OK (builtin path: " .. tostring(r.ImGui_GetBuiltinPath()) .. ")")
else
  p("ReaImGui: NOT FOUND (install ReaImGui extension if you use the GUI tools)")
end

local function exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local checks = {
  {"MicFX JSON (profiles)", res..sep.."Data"..sep.."IFLS Workbench"..sep.."MicFX_Profiles_v3.json"},
  {"MicFX JSON (param maps)", res..sep.."Data"..sep.."IFLS Workbench"..sep.."DF95_ParamMaps_AO_AW.json"},
  {"MicFX fxlist example", res..sep.."Scripts"..sep.."IFLS_Workbench"..sep.."MicFX"..sep.."B1.fxlist"},
  {"Mic FXChain example", res..sep.."FXChains"..sep.."IFLS Workbench"..sep.."Mic"..sep.."Mic_B1_Mono.rfxchain"},
  {"JSFX meter", res..sep.."Effects"..sep.."IFLS Workbench"..sep.."DF95_Dynamic_Meter_v1.jsfx"},
}

p("")
p("Asset checks:")
for _, c in ipairs(checks) do
  p(string.format(" - %-24s : %s", c[1], exists(c[2]) and "OK" or ("MISSING ("..c[2]..")")))
end

p("========================")

r.MB("Diagnostics wurden in die Konsole geschrieben.\n\nView -> Show console.", "IFLS Diagnostics", 0)
