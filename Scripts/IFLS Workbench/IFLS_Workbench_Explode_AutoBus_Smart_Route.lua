-- @description IFLS Workbench: Explode AutoBus + Route (FX/Coloring/Master)
-- @version 1.0.0
-- @author IFLS (adapted for IFLS Workbench by I feel like snow)
-- @link GitHub https://github.com/IfeelLikeSnow/IFLS_Workbench_toolbar
-- @donation PayPal https://www.paypal.com/donate/?hosted_button_id=PK9T9DX6UFRZ8
-- @about
--   Ensures Workbench FX/Coloring/Master busses exist, optionally explodes multichannel items,
--   and routes source tracks -> FX bus -> Coloring bus -> Master bus.
--   Source tracks have their Master/Parent send disabled to avoid double routing.

local r = reaper

------------------------------------------------------------
-- USER CONFIG
------------------------------------------------------------

local FX_BUS_NAME       = "IFLS FX Bus"
local COLORING_BUS_NAME = "IFLS Coloring Bus"
local MASTER_BUS_NAME   = "IFLS Master Bus"

-- Wenn du nach dem Anlegen der Busse automatisch deine IFLS-Selector-Scripts
-- starten willst, kannst du hier die Action-Kommandos eintragen.
-- Beispiel: local CMD_IFLS_MASTER_SELECTOR = r.NamedCommandLookup("_IFLS_MASTERBUS_SELECTOR")
local CMD_IFLS_MASTER_SELECTOR   = 0 -- 0 = aus
local CMD_IFLS_FXBUS_SELECTOR    = 0 -- 0 = aus
local CMD_IFLS_COLORING_SELECTOR = 0 -- 0 = aus

-- Command-ID für "Item: Explode multichannel audio or MIDI items to new one-channel items"
-- Bitte in deiner Action-Liste verifizieren (Standard: 40224)
local CMD_EXPLODE_MULTI = 40224

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------

local function dbg(msg)
  -- r.ShowConsoleMsg(tostring(msg) .. "\n")
end

local function find_track_by_name_exact(name)
  local num = r.CountTracks(0)
  for i = 0, num-1 do
    local tr = r.GetTrack(0, i)
    local ok, tr_name = r.GetTrackName(tr, "")
    if ok and tr_name == name then
      return tr, i
    end
  end
  return nil, -1
end

local function create_track_at_end(name)
  local num = r.CountTracks(0)
  r.InsertTrackAtIndex(num, true)
  local tr = r.GetTrack(0, num)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  return tr, num
end

local function ensure_bus_track(name)
  local tr, idx = find_track_by_name_exact(name)
  if tr then return tr, idx, false end
  local new_tr, new_idx = create_track_at_end(name)
  return new_tr, new_idx, true
end

local function ensure_all_busses()
  local fx_tr, fx_idx, fx_new       = ensure_bus_track(FX_BUS_NAME)
  local col_tr, col_idx, col_new    = ensure_bus_track(COLORING_BUS_NAME)
  local master_tr, master_idx, mnew = ensure_bus_track(MASTER_BUS_NAME)

  dbg(string.format("[IFLS] FXBus=%d (new=%s) | Coloring=%d (new=%s) | MasterBus=%d (new=%s)",
    fx_idx, tostring(fx_new), col_idx, tostring(col_new), master_idx, tostring(mnew)))

  if CMD_IFLS_MASTER_SELECTOR ~= 0 then
    r.Main_OnCommand(CMD_IFLS_MASTER_SELECTOR, 0)
  end
  if CMD_IFLS_FXBUS_SELECTOR ~= 0 then
    r.Main_OnCommand(CMD_IFLS_FXBUS_SELECTOR, 0)
  end
  if CMD_IFLS_COLORING_SELECTOR ~= 0 then
    r.Main_OnCommand(CMD_IFLS_COLORING_SELECTOR, 0)
  end

  return fx_tr, col_tr, master_tr
end

local function track_has_multichannel_item(tr)
  local item_count = r.CountTrackMediaItems(tr)
  for i = 0, item_count-1 do
    local item = r.GetTrackMediaItem(tr, i)
    local take = r.GetActiveTake(item)
    if take and not r.TakeIsMIDI(take) then
      local src = r.GetMediaItemTake_Source(take)
      if src then
        local ch = r.GetMediaSourceNumChannels(src)
        if ch and ch > 2 then
          return true, ch
        end
      end
    end
  end
  return false, 0
end

local function any_selected_track_has_multichannel()
  local num_sel_tr = r.CountSelectedTracks(0)
  for i = 0, num_sel_tr-1 do
    local tr = r.GetSelectedTrack(0, i)
    local has, ch = track_has_multichannel_item(tr)
    if has then
      return true, ch
    end
  end
  return false, 0
end

local function route_sources_to_busses(fx_tr, col_tr, master_tr)
  if not fx_tr or not col_tr or not master_tr then return end

  local proj = 0
  local num_tracks = r.CountTracks(proj)

  -- 1) Quelltracks -> FX Bus
  for i = 0, num_tracks-1 do
    local tr = r.GetTrack(proj, i)
    if tr ~= fx_tr and tr ~= col_tr and tr ~= master_tr then
      -- Master/Parent-Send deaktivieren, damit nur der Buspfad genutzt wird
      r.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
      -- FX-Send anlegen
      local send_idx = r.CreateTrackSend(tr, fx_tr)
      r.SetTrackSendInfo_Value(tr, 0, send_idx, "D_VOL", 1.0)      -- 0 dB
      r.SetTrackSendInfo_Value(tr, 0, send_idx, "I_SENDMODE", 0)   -- 0=post-fader
    end
  end

  -- 2) FX Bus -> Coloring Bus
  local send_fx_col = r.CreateTrackSend(fx_tr, col_tr)
  r.SetTrackSendInfo_Value(fx_tr, 0, send_fx_col, "D_VOL", 1.0)
  r.SetTrackSendInfo_Value(fx_tr, 0, send_fx_col, "I_SENDMODE", 0)

  -- 3) Coloring Bus -> Master Bus
  local send_col_master = r.CreateTrackSend(col_tr, master_tr)
  r.SetTrackSendInfo_Value(col_tr, 0, send_col_master, "D_VOL", 1.0)
  r.SetTrackSendInfo_Value(col_tr, 0, send_col_master, "I_SENDMODE", 0)

  -- Master Bus darf zum REAPER-Master senden
  r.SetMediaTrackInfo_Value(master_tr, "B_MAINSEND", 1)
end

------------------------------------------------------------
-- MAIN
------------------------------------------------------------

local function main()
  r.Undo_BeginBlock()

  local fx_tr, col_tr, master_tr = ensure_all_busses()

  local num_sel_tr = r.CountSelectedTracks(0)
  if num_sel_tr > 0 then
    local has_multi, ch = any_selected_track_has_multichannel()
    if has_multi and CMD_EXPLODE_MULTI ~= 0 then
      r.Main_OnCommand(CMD_EXPLODE_MULTI, 0)
    end
  end

  route_sources_to_busses(fx_tr, col_tr, master_tr)

  r.Undo_EndBlock("IFLS Explode AutoBus Smart + Route", -1)
end

main()