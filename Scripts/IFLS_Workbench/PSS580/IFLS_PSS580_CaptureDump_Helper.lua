-- @description IFLS Workbench - PSS580/IFLS_PSS580_CaptureDump_Helper.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_PSS580_CaptureDump_Helper.lua
-- Helper for capturing PSS-580 bulk dumps in REAPER and saving as .syx.
--
-- Workflow:
-- 1) Ensure you have a track named "PSS580 SYSEx CAPTURE (REC)" with MIDI input from your interface.
-- 2) Run this script to arm/select it.
-- 3) Trigger "Memory Bulk Dump" on the PSS-580.
-- 4) Stop recording. Select the recorded MIDI item and run this script again to export its SysEx to .syx.

local r = reaper
local Lib = require("IFLS_Workbench/PSS580/IFLS_PSS580_Lib")

local function find_track(name)
  for i=0, r.CountTracks(0)-1 do
    local tr = r.GetTrack(0, i)
    local _, tn = r.GetTrackName(tr)
    if tn == name then return tr end
  end
  return nil
end

local function extract_sysex_from_item(item)
  local take = r.GetActiveTake(item)
  if not take or not r.TakeIsMIDI(take) then return nil, "Selected item is not MIDI" end

  local _, note_cnt, cc_cnt, txt_cnt = r.MIDI_CountEvts(take)

  local syx = {}
  for i=0, txt_cnt-1 do
    local ok, selected, muted, ppqpos, ttype, msg = r.MIDI_GetTextSysexEvt(take, i)
    if ok and ttype == -1 and msg and #msg > 0 then
      -- msg is raw bytes, may already include F0/F7 depending on source
      syx[#syx+1] = msg
    end
  end

  if #syx == 0 then return nil, "No SysEx events found in item." end
  return table.concat(syx), nil
end

local function prompt_save_path(default_name)
  local scripts_root = Lib.get_scripts_root()
  local default_dir = scripts_root.."/Workbench/PSS580/Patches/syx"
  local fname = (default_name or "PSS580_Dump")..".syx"

  -- JS dialog if available
  if r.JS_Dialog_BrowseForSaveFile then
    local ok, out = r.JS_Dialog_BrowseForSaveFile("Save PSS580 .syx", default_dir, fname, "SYX files\0*.syx\0")
    if ok and out and out ~= "" then return out end
  end

  -- fallback: save into default dir with timestamp
  local ts = os.date("%Y%m%d_%H%M%S")
  return default_dir.."/"..(default_name or "PSS580_Dump").."_"..ts..".syx"
end

local CAP_NAME = "PSS580 SYSEx CAPTURE (REC)"
local tr = find_track(CAP_NAME)
if not tr then
  r.MB("Missing track:\n"..CAP_NAME.."\n\nCreate it and set MIDI input from your interface.", "IFLS PSS580 Capture", 0)
  return
end

-- If a MIDI item is selected, export SysEx from it
local item = r.GetSelectedMediaItem(0, 0)
if item then
  local bytes, err = extract_sysex_from_item(item)
  if not bytes then
    r.MB("Export failed: "..tostring(err), "IFLS PSS580 Capture", 0)
    return
  end

  -- ensure file payload has F0/F7
  bytes = Lib.ensure_f0f7(bytes, true)

  local out = prompt_save_path("PSS580_BulkDump")
  local f = io.open(out, "wb")
  if not f then
    r.MB("Cannot write:\n"..out, "IFLS PSS580 Capture", 0)
    return
  end
  f:write(bytes)
  f:close()

  r.MB("Saved .syx:\n"..out, "IFLS PSS580 Capture", 0)
  return
end

-- Otherwise: arm/select capture track
Lib.safe_run("IFLS: PSS580 Arm Capture", function()
  r.SetOnlyTrackSelected(tr)
  r.SetMediaTrackInfo_Value(tr, "I_RECARM", 1)
  -- monitoring OFF (avoid loop)
  r.SetMediaTrackInfo_Value(tr, "I_RECMON", 0)
end)

r.MB("Capture track armed:\n"..CAP_NAME.."\n\nNow trigger 'Memory Bulk Dump' on PSS-580, record, then select the recorded MIDI item and run this script again to export .syx.", "IFLS PSS580 Capture", 0)
