-- IFLS Device Port Defaults
-- Version: 0.81.0
--
-- Reads ExtState written by:
--   Tools/IFLS_MIDINetwork_Apply_ReaperPortNames_And_Indexes.lua
--
-- ExtState section: IFLS_WORKBENCH_DEVICES
-- Keys:
--   <device_id>_midi_in_idx
--   <device_id>_midi_out_idx
--
-- Returns validated REAPER MIDI port indices (0-based).

local r = reaper
local M = {}

M.SECTION = "IFLS_WORKBENCH_DEVICES"

local function clamp_idx(idx, maxn)
  if idx == nil then return nil end
  if idx < 0 or idx >= maxn then return nil end
  return idx
end

function M.get_in_idx(device_id)
  if not device_id or device_id=="" then return nil end
  local s = r.GetExtState(M.SECTION, device_id.."_midi_in_idx")
  local n = tonumber(s or "")
  if not n then return nil end
  return clamp_idx(n, r.GetNumMIDIInputs())
end

function M.get_out_idx(device_id)
  if not device_id or device_id=="" then return nil end
  local s = r.GetExtState(M.SECTION, device_id.."_midi_out_idx")
  local n = tonumber(s or "")
  if not n then return nil end
  return clamp_idx(n, r.GetNumMIDIOutputs())
end

function M.get_out_or_err(device_id)
  local idx = M.get_out_idx(device_id)
  if idx == nil then
    return nil, "No default REAPER MIDI OUT index for '"..tostring(device_id).."'. Run: Apply REAPER Port Names + Indexes."
  end
  return idx, nil
end

return M
