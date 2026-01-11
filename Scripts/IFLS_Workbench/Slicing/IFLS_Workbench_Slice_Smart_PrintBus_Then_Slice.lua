-- @description IFLS Workbench: Slice Smart (print IFLS bus mono/stereo, then Slice Direct)
-- @version 0.2
-- @author I feel like snow
-- @about
--   Workflow helper for exploded PolyWAV / multi-mic field recordings:
--   1) Finds your IFLS master bus (default name: "IFLS WB - MASTER BUS").
--   2) Detects if ALL mic-source items are mono. If yes -> print MONO stem, else -> STEREO stem.
--   3) Runs "IFLS Workbench: Slice Direct" on the printed stem track.
--
--   Notes:
--   - Printing bakes your MicFX and bus FX into ONE track (avoids "zig samples" across tracks).
--   - Printing uses REAPER's built-in stem render actions (post-fader).
--
local r = reaper

local MASTER_NAME = "IFLS WB - MASTER BUS"
local FXBUS_NAME  = "IFLS WB - FX BUS"

local function msg(s) r.ShowConsoleMsg(tostring(s) .. "\n") end

local function find_track_by_exact_name(name)
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    local _, trname = r.GetTrackName(tr)
    if trname == name then return tr end
  end
end

local function set_only_selected_track(tr)
  r.Main_OnCommand(40297, 0) -- Unselect all tracks
  if tr then r.SetTrackSelected(tr, true) end
end

local function detect_any_stereo_in_tracks(tracks)
  for _, tr in ipairs(tracks) do
    local item_count = r.CountTrackMediaItems(tr)
    for i = 0, item_count - 1 do
      local item = r.GetTrackMediaItem(tr, i)
      local take = r.GetActiveTake(item)
      if take then
        local src = r.GetMediaItemTake_Source(take)
        if src then
          local ch = r.GetMediaSourceNumChannels(src)
          if ch and ch > 1 then return true end
        end
      end
    end
  end
  return false
end

local function collect_tracks_sending_to(dest_tr)
  local out = {}
  if not dest_tr then return out end
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    if tr ~= dest_tr then
      local ns = r.GetTrackNumSends(tr, 0)
      for s = 0, ns - 1 do
        local dt = r.GetTrackSendInfo_Value(tr, 0, s, "P_DESTTRACK")
        if dt == dest_tr then
          table.insert(out, tr)
          break
        end
      end
    end
  end
  return out
end

local function run_script_relative(rel)
  local path = r.GetResourcePath() .. "/" .. rel
  local f = io.open(path, "rb")
  if f then f:close(); dofile(path); return true end
  return false
end

-- 1) Find IFLS buses
local master = find_track_by_exact_name(MASTER_NAME)
local fxbus  = find_track_by_exact_name(FXBUS_NAME)

-- Fallback: if no master found, allow user selection
if not master then
  master = r.GetSelectedTrack(0, 0)
  if not master then
    r.ShowMessageBox(
      "Couldn't find IFLS bus tracks.\n\nSelect your IFLS master/bus track, then run this script again.",
      "IFLS Slice Smart", 0
    )
    return
  end
end

-- 2) Determine mono vs stereo by scanning tracks that send into FX bus (preferred), otherwise master
local source_bus = fxbus or master
local mic_tracks = collect_tracks_sending_to(source_bus)
local any_stereo = detect_any_stereo_in_tracks(mic_tracks)

-- 3) Print stem from bus track (post-fader), but keep original unmuted afterwards
local old_mute = r.GetMediaTrackInfo_Value(master, "B_MUTE")

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

set_only_selected_track(master)

local n_before = r.CountTracks(0)

local function try_render(cmd)
  r.Main_OnCommand(cmd, 0)
  return r.CountTracks(0) > n_before
end

local ok_render = false
if any_stereo then
  -- Some REAPER versions/lists report 40405, others 40406 for this action.
  ok_render = try_render(40405) or try_render(40406) or try_render(40788) -- non post-fader fallback
else
  ok_render = try_render(40537) -- mono post-fader stem tracks (and mute originals)
end

if not ok_render then
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock("IFLS Slice Smart: print bus -> slice (FAILED)", -1)
  r.ShowMessageBox("Couldn\\'t render stem track (render action not found?).\n\nTry running the render-to-stem action manually from the Action List, then run Slice Direct.", "IFLS Slice Smart", 0)
  return
end


-- After rendering, REAPER typically selects the newly created stem track(s).
-- Restore the master mute state (render action mutes originals).
r.SetMediaTrackInfo_Value(master, "B_MUTE", old_mute)

-- Identify the new stem track: first selected track that is NOT the master
local stem = nil
for i = 0, r.CountTracks(0) - 1 do
  local tr = r.GetTrack(0, i)
  if tr ~= master and r.IsTrackSelected(tr) then
    stem = tr
    break
  end
end

if stem then
  local suffix = any_stereo and "STEREO" or "MONO"
  r.GetSetMediaTrackInfo_String(stem, "P_NAME", "IFLS WB - SLICE SOURCE ("..suffix..")", true)
  set_only_selected_track(stem)
else
  msg("[IFLS Slice Smart] Couldn't detect the printed stem track. (Still continuing...)")
end

r.PreventUIRefresh(-1)

-- 4) Run Slice Direct (cursor or time selection)
local ok = run_script_relative("Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slice_Direct.lua")
if not ok then
  r.ShowMessageBox(
    "Printed stem created, but couldn't find Slice Direct script.\n\nExpected:\nScripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slice_Direct.lua",
    "IFLS Slice Smart", 0
  )
end

r.Undo_EndBlock("IFLS Slice Smart: print bus -> slice", -1)
