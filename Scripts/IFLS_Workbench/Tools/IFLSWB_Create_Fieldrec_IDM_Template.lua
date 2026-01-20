-- @description IFLS Workbench - Create Fieldrec → Slice → RS5K Rack + Resample Bus (IDM-friendly)
-- @author IFLS / DF95
-- @version 0.4.0
-- @about
--   Builds a small track layout for field recordings and IDM slicing workflows.
local r = reaper
local proj = 0

local function add_track(name)
  local idx = r.CountTracks(proj)
  r.InsertTrackAtIndex(idx, true)
  local tr = r.GetTrack(proj, idx)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  return tr
end

local function disable_master_send(tr)
  r.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
end

local function make_send(src, dst, vol)
  local send = r.CreateTrackSend(src, dst)
  if send >= 0 and vol then
    r.SetTrackSendInfo_Value(src, 0, send, "D_VOL", vol)
  end
  return send
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

local tr_in    = add_track("FIELDREC_IN")
local tr_print = add_track("PRINTBUS")
local tr_slices= add_track("SLICES")
local tr_rs5k  = add_track("RS5K Rack")
local tr_res   = add_track("RESAMPLE BUS")

disable_master_send(tr_in)
make_send(tr_in, tr_print, 1.0)

r.SetMediaTrackInfo_Value(tr_print, "I_RECARM", 1)
r.SetMediaTrackInfo_Value(tr_print, "I_RECMON", 1)

disable_master_send(tr_rs5k)
make_send(tr_rs5k, tr_res, 1.0)
r.SetMediaTrackInfo_Value(tr_res, "I_RECMON", 1)

r.TrackList_AdjustWindows(false)
r.UpdateArrange()
r.PreventUIRefresh(-1)
r.Undo_EndBlock("Create Fieldrec IDM Template", -1)

r.MB("Template created.\n\nWorkflow:\n1) Drop audio onto FIELDREC_IN.\n2) (Optional) FX on PRINTBUS, record output.\n3) Run SmartSlice on printed items.\n4) Move slices to SLICES track.\n5) Build RS5K Rack from selected slices.\n6) Resample via RESAMPLE BUS.", "IFLSWB Template", 0)
