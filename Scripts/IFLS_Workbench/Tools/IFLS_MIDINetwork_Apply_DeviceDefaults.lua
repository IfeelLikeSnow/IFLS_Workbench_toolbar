-- @description IFLS Workbench - Apply MIDINetwork Device Defaults (channels/policy) to ExtState
-- @version 0.73.0
-- @author IfeelLikeSnow

local r = reaper
local lib_path = r.GetResourcePath().."/Scripts/IFLS_Workbench/Workbench/MIDINetwork/Lib/IFLS_MIDINetwork_Lib.lua"
local ok, M = pcall(dofile, lib_path)
if not ok or not M then
  r.MB("Failed to load MIDINetwork lib:\n"..tostring(M), "Apply Device Defaults", 0)
  return
end

local profile, err = M.load_profile()
if not profile then
  r.MB("Failed to load profile:\n"..tostring(err), "Apply Device Defaults", 0)
  return
end

M.apply_defaults_to_extstate(profile)

r.MB("Applied device default channels + policy hints to ExtState.\n\nSECTION: IFLS_WORKBENCH_DEVICES\nKeys: fb01_channels_json, pss580_ch, microfreak_ch, ...\n\nNext: Set your actual MIDI OUT device in each device tool, or extend profile with port mapping.", "Apply Device Defaults", 0)
