-- @description IFLS Workbench - PSS580/IFLS_PSS580_Create_Tracks_Template.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_PSS580_Create_Tracks_Template.lua
-- V60: Create the recommended PSS-580 track layout in the current REAPER project.

local r = reaper
local Lib = require("IFLS_Workbench/PSS580/IFLS_PSS580_Lib")

local SECTION = "IFLS_WORKBENCH_SETTINGS"
local function get_midi_out_dev()
  local v = r.GetExtState(SECTION, "pss580_midi_out_dev")
  local n = tonumber(v or "")
  return n or 0
end

local function set_track_name(tr, name)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
end

local function add_note(tr, text)
  -- Track notes via P_NOTES (works in modern REAPER)
  r.GetSetMediaTrackInfo_String(tr, "P_NOTES", text, true)
end

-- Best-effort hardware MIDI out mapping:
-- I_MIDIHWOUT packs device + channel bits. We'll set channel=0 (omni/track) and device index.
local function set_midi_hwout(tr, dev, ch)
  ch = ch or 0
  local val = (dev & 0x3FF) | ((ch & 0x1F) << 10)
  r.SetMediaTrackInfo_Value(tr, "I_MIDIHWOUT", val)
end

Lib.safe_run("IFLS: Create PSS580 Tracks", function()
  local dev = get_midi_out_dev()

  -- Create 3 tracks at end
  local idx = r.CountTracks(0)
  r.InsertTrackAtIndex(idx, true)
  local tr_seq = r.GetTrack(0, idx)

  r.InsertTrackAtIndex(idx+1, true)
  local tr_send = r.GetTrack(0, idx+1)

  r.InsertTrackAtIndex(idx+2, true)
  local tr_cap = r.GetTrack(0, idx+2)

  set_track_name(tr_seq, "PSS580 MIDI SEQ")
  set_track_name(tr_send, "PSS580 SYSEx RECALL (SEND)")
  set_track_name(tr_cap, "PSS580 SYSEx CAPTURE (REC)")

  set_midi_hwout(tr_seq, dev, 0)
  set_midi_hwout(tr_send, dev, 0)

  r.SetMediaTrackInfo_Value(tr_cap, "I_RECARM", 0)
  r.SetMediaTrackInfo_Value(tr_cap, "I_RECMON", 0)

  add_note(tr_seq, "Send notes/PC/CC to PSS-580. Set MIDI channel per item/track as needed.")
  add_note(tr_send, "Project Recall container. Use Patch Browser 'Copy as Recall' then run 'Send Project Recall' (button).")
  add_note(tr_cap, "Set MIDI input to your interface (1824c) and record bulk dumps from PSS-580. Monitoring is OFF to avoid SysEx loops.")

  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
end)

r.MB("Created PSS580 tracks.\n\nNext:\n- Load Patch Browser\n- Import a .syx and 'Copy as Recall'\n- Use 'Send Project Recall' button", "IFLS PSS580", 0)
