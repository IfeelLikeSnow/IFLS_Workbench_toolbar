-- @description IFLS Workbench - Toggle MIDI Network AutoDoctor (Enable/Disable)
-- @version 0.71.0
-- @author IfeelLikeSnow

local r = reaper
local SECTION = "IFLS_WORKBENCH"
local KEY = "MIDINET_AUTODOCTOR_ENABLED"

local enabled = (r.GetExtState(SECTION, KEY) == "1")
enabled = not enabled
r.SetExtState(SECTION, KEY, enabled and "1" or "0", true)

r.MB(
  "MIDI Network AutoDoctor is now: "..(enabled and "ENABLED" or "DISABLED")..
  "

To start the background service, run:
IFLS_MIDINetwork_AutoDoctor_Service",
  "IFLS AutoDoctor", 0
)
