-- @description IFLS Workbench - MicroFreak Send Project Recall (SysEx + optional CC snapshot)
-- @version 0.68.0
-- @author IfeelLikeSnow

local r = reaper
local Lib = require("IFLS_Workbench/Workbench/MicroFreak/IFLS_MicroFreak_Lib")

local recall = Lib.get_proj_recall(0)
if not recall.syx and not recall.cc then
  r.MB("No MicroFreak Project Recall stored in this project.", "MicroFreak Recall", 0)
  return
end

local out_dev = recall.out_dev
if out_dev == nil then
  local n = r.GetNumMIDIOutputs()
  if n == 0 then
    r.MB("No MIDI outputs configured.", "MicroFreak Recall", 0)
    return
  end
  local ok, val = r.GetUserInputs("MicroFreak Recall", 1, "MIDI output index (1-"..tostring(n)..")", "1")
  if not ok then return end
  out_dev = (tonumber(val) or 1) - 1
end

local channel = recall.channel or 1

local msgs = {}
if recall.syx then
  local ok, info = Lib.send_syx_file(out_dev, recall.syx)
  msgs[#msgs+1] = ok and ("SysEx: OK ("..info..")") or ("SysEx: FAIL ("..info..")")
end
if recall.cc then
  local ok, info = Lib.send_cc_snapshot(out_dev, channel, recall.cc)
  msgs[#msgs+1] = ok and "CC snapshot: OK" or ("CC snapshot: FAIL ("..tostring(info)..")")
end

r.MB(table.concat(msgs, "\n"), "MicroFreak Recall", 0)
