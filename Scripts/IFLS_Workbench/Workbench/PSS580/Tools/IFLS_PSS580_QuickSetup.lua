-- @description IFLS PSS-580 - Quick Setup (create track + notes)
-- @version 1.06.0
-- @author IFLS
local r=reaper

local function ensure_track()
  local tr=r.GetSelectedTrack(0,0)
  if tr then return tr end
  r.InsertTrackAtIndex(r.CountTracks(0), true)
  tr=r.GetTrack(0, r.CountTracks(0)-1)
  r.SetOnlyTrackSelected(tr)
  return tr
end

local tr = ensure_track()
r.GetSetMediaTrackInfo_String(tr, "P_NAME", "PSS-x80 (MIDI + SysEx)", true)
r.SetMediaTrackInfo_Value(tr, "I_RECARM", 1)
r.SetMediaTrackInfo_Value(tr, "I_RECMON", 1)

local note = [[IFLS Quick Setup – Variant 1 (REAPER clock master):
1) Track input: set to mioXM port that receives PSS MIDI (enable device in Preferences→MIDI Devices).
2) Track hardware MIDI output: set to mioXM port that sends to PSS (if you play it from REAPER).
3) SysEx: use Hub → PSS Safe Audition Wizard (auto-capture) or Voice Editor → Send.
4) Clock: in REAPER enable 'Send clock' ONLY on one mioXM output; mioXM distributes further (no loopback).]]
r.GetSetMediaTrackInfo_String(tr, "P_NOTES", note, true)

r.MB("Created/updated track 'PSS-x80 (MIDI + SysEx)'.\nOpen Track Routing to set MIDI input/output ports.", "PSS Quick Setup", 0)
