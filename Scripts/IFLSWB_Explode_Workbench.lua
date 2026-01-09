-- IFLSWB_Explode_Workbench.lua
-- One-button: Explode (non-destructive) + MicFX + AutoBus routing
--
-- Install: Actions -> ReaScript: Load -> this file, then assign to toolbar.

local U = dofile((({reaper.get_action_context()})[2]):match("^(.*)[/\\]") .. "/IFLSWB_Utils.lua")
local P = dofile((({reaper.get_action_context()})[2]):match("^(.*)[/\\]") .. "/IFLSWB_MicProfiles.lua")

local CFG = {
  bus_names = {
    fx = "IFLSWB FX Bus",
    coloring = "IFLSWB Coloring Bus",
    master = "IFLSWB Master Bus",
  },
  rename_tracks = true,
  disable_mic_tracks_master_send = true,
  apply_mic_eq = true,
}

local function gather_context(track, take)
  local tname = U.get_track_name(track)
  local tkname = U.get_take_name(take)
  local path = U.get_item_source_path(take)
  return table.concat({tname, tkname, path}, " | ")
end

local function apply_profile(track, take)
  local ctx = gather_context(track, take)
  local profName = U.find_profile(ctx, P) or "Generic Fieldrec"
  local prof = P.profiles[profName] or P.profiles["Generic Fieldrec"]

  if CFG.rename_tracks and prof and prof.name then
    U.set_track_name(track, prof.name)
  end

  if CFG.apply_mic_eq and prof then
    U.apply_mic_eq(track, prof)
  end

  return track
end

local function route_tracks_to_bus(tracks, fxBus)
  for tr,_ in pairs(tracks) do
    if CFG.disable_mic_tracks_master_send then
      U.disable_master_send(tr, true)
    end
    U.ensure_send(tr, fxBus)
  end
end

local function process_item(item, touchedTracks)
  local tr = reaper.GetMediaItemTrack(item)
  local take = reaper.GetActiveTake(item)
  if not tr or not take then return end

  local src = reaper.GetMediaItemTake_Source(take)
  local ch = (src and reaper.GetMediaSourceNumChannels(src)) or 1
  if ch < 1 then ch = 1 end

  if ch == 1 then
    apply_profile(tr, take)
    touchedTracks[tr] = true
    return
  end

  -- Multi-channel explode to tracks below (non-destructive):
  -- ch1 stays on original track; additional channels go to new tracks below.
  for c=1,ch do
    local targetTrack = tr
    local targetItem = item

    if c > 1 then
      targetTrack = U.insert_track_below(tr, c-1)
      targetItem = U.duplicate_item_to_track(item, targetTrack)
      if not targetItem then break end
    end

    local tk = reaper.GetActiveTake(targetItem)
    if tk then
      U.set_take_mono_channel(tk, c)
      apply_profile(targetTrack, tk)
      touchedTracks[targetTrack] = true
    end
  end
end

-- -------- Main --------
local sel = reaper.CountSelectedMediaItems(0)
if sel == 0 then
  U.msg("IFLSWB", "Kein Item selektiert.\n\nBitte ein WAV/Polywave Item auswählen und nochmal starten.")
  return
end

local swsOk = reaper.APIExists and reaper.APIExists("BR_GetMediaTrackSendInfo_Track")
if not swsOk then
  U.msg("IFLSWB (Hinweis)", "SWS Extension nicht gefunden.\n\nDas Script funktioniert trotzdem, aber Send-Dedupe ist einfacher mit SWS.\nInstalliere SWS für bestes Verhalten.")
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local touchedTracks = {}

for i=0,sel-1 do
  local item = reaper.GetSelectedMediaItem(0, i)
  if item then
    process_item(item, touchedTracks)
  end
end

-- Buses
local fxBus, colBus, mastBus = U.ensure_buses(CFG.bus_names)

-- route mic tracks -> fx bus
route_tracks_to_bus(touchedTracks, fxBus)

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("IFLSWB: Explode + MicFX + AutoBuses", -1)