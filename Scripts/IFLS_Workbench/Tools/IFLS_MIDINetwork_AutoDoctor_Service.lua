-- @description IFLS Workbench - MIDI Network AutoDoctor Service (startup/defer)
-- @version 0.71.0
-- @author IfeelLikeSnow
--
-- Background service (defer loop) that runs MIDI Network Doctor when project state changes.
-- Enable/Disable via ExtState: IFLS_WORKBENCH / MIDINET_AUTODOCTOR_ENABLED
--
-- Recommended: Add this script to an SWS Startup Action, or run once per REAPER session.

local r = reaper
local STATUS_SEC='IFLS_MIDINET_STATUS'
local STATUS=nil
pcall(function() STATUS=dofile(r.GetResourcePath().."/Scripts/IFLS_Workbench/Workbench/MIDINetwork/Lib/IFLS_Status.lua") end)



local SECTION = "IFLS_WORKBENCH"
local KEY = "MIDINET_AUTODOCTOR_ENABLED"

r.SetExtState(STATUS_SEC,'autodoctor_running','1',false)
if STATUS and STATUS.set then STATUS.set('autodoctor_running','1',false) end
r.SetExtState(STATUS_SEC,'autodoctor_heartbeat_utc',tostring(os.time()),false)

local function get_enabled()
  return r.GetExtState(SECTION, KEY) == "1"
end

local function set_enabled(on)
  r.SetExtState(SECTION, KEY, on and "1" or "0", true)
end

local function ensure_enabled_interactive()
  if get_enabled() then return true end
  local ret = r.MB(
    "Enable MIDI Network AutoDoctor and remember this setting?

"..
    "- Runs checks whenever you load/switch projects
"..
    "- Writes report to: Scripts/IFLS_Workbench/Docs/MIDINetwork_Doctor_Report.md

"..
    "You can disable it any time via 'IFLS_MIDINetwork_AutoDoctor_Toggle'.",
    "IFLS AutoDoctor", 4
  )
  if ret == 6 then
    set_enabled(true)
    return true
  end
  return false
end

local function run_doctor()
  local script_path = r.GetResourcePath().."/Scripts/IFLS_Workbench/Tools/IFLS_MIDINetwork_Doctor.lua"
  local ok, err = pcall(dofile, script_path)
  if not ok then
    r.ShowConsoleMsg("[IFLS AutoDoctor] Failed to run Doctor: "..tostring(err).."
")
  end
end

local last_change = -1
local last_run_time = 0

local function loop()
  if not get_enabled() then
    if not ensure_enabled_interactive() then return end
  end

  local proj = 0
  local change = r.GetProjectStateChangeCount(proj)
  local now = r.time_precise()

  -- debounce: project load triggers many state changes
  if change ~= last_change and (now - last_run_time) > 1.5 then
    last_change = change
    last_run_time = now
    run_doctor()
    r.ShowConsoleMsg("[IFLS AutoDoctor] Doctor ran. See Docs/MIDINetwork_Doctor_Report.md
")
  end

  r.SetExtState(STATUS_SEC,'autodoctor_heartbeat_utc',tostring(os.time()),false)
  r.defer(loop)
end

loop()


-- V85_AUTODOCTOR_LAST_RESULT
-- Best-effort: when this service runs Doctor, record last result.
pcall(function()
  local STATUS=nil
  pcall(function() STATUS=dofile(reaper.GetResourcePath().."/Scripts/IFLS_Workbench/Workbench/MIDINetwork/Lib/IFLS_Status.lua") end)
  if not STATUS or not STATUS.set then return end
  local doctor_path = reaper.GetResourcePath().."/Scripts/IFLS_Workbench/Tools/IFLS_MIDINetwork_Doctor.lua"
  local f=io.open(doctor_path,"rb"); if not f then return end; f:close()
  local ok,err = pcall(dofile, doctor_path)
  STATUS.set("autodoctor_last_run_utc", os.time(), false)
  if ok then
    STATUS.set("autodoctor_last_ok", "1", false)
    STATUS.set("autodoctor_last_err", "", false)
  else
    STATUS.set("autodoctor_last_ok", "0", false)
    STATUS.set("autodoctor_last_err", tostring(err), false)
  end
end)
