-- @description IFLS Workbench - PSS580/IFLS_PSS580_Send_Project_Recall.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_PSS580_Send_Project_Recall.lua
-- Sends the currently assigned Project Recall patch to PSS-580 (per button).

local r = reaper
local Lib = require("IFLS_Workbench/PSS580/IFLS_PSS580_Lib")

local SECTION = "IFLS_WORKBENCH_SETTINGS"

local function get_midi_out_dev()
  local v = r.GetExtState(SECTION, "pss580_midi_out_dev")
  local n = tonumber(v or "")
  return n or 0
end

local function get_include_f0f7()
  return (r.GetExtState(SECTION, "pss580_include_f0f7") ~= "0")
end

local function get_default_delay()
  local v = tonumber(r.GetExtState(SECTION, "pss580_default_delay_ms") or "")
  return v or 350
end

local recall = Lib.get_project_recall()
if not recall or (recall.id == "" and not recall.syx) then
  r.MB("No PSS580 Project Recall set.\n\nOpen the Patch Browser and use 'Copy as Recall'.", "IFLS PSS580", 0)
  return
end

if not r.SNM_SendSysEx then
  r.MB("SWS missing: SNM_SendSysEx unavailable.\nInstall SWS to send SysEx.", "IFLS PSS580", 0)
  return
end

local payload = recall.syx
if not payload or #payload == 0 then
  r.MB("Project Recall has no SysEx payload.\nRe-copy the patch into the project.", "IFLS PSS580", 0)
  return
end

local dev = get_midi_out_dev()
local include_f0f7 = get_include_f0f7()
local delay = get_default_delay()

payload = Lib.ensure_f0f7(payload, include_f0f7)

local ok = r.SNM_SendSysEx(dev, payload)
if ok then
  if delay > 0 then r.Sleep(delay) end
  r.MB("Sent PSS580 Project Recall:\n"..(recall.id or "(unknown)"), "IFLS PSS580", 0)
else
  r.MB("Send failed (SNM_SendSysEx). Check MIDI device index + cabling.", "IFLS PSS580", 0)
end
