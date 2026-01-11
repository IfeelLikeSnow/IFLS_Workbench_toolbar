-- @description IFLS Workbench: Slice Smart (print IFLS bus mono/stereo, then Slice Direct, then mute slice source)
-- @version 0.4
-- @author I feel like snow (patched)
-- @about
--   Workflow helper for exploded PolyWAV / multi-mic field recordings:
--   1) Finds your IFLS master bus (default name: "IFLS WB - MASTER BUS").
--   2) Detects if ANY mic-source items are stereo. If yes -> print STEREO stem, else -> MONO stem.
--   3) Selects the printed stem item(s) and runs "IFLS Workbench: Slice Direct".
--   4) Mutes the slice-source track afterwards (requested behavior).

local r = reaper
local sep = package.config:sub(1,1)

local MASTER_NAME = "IFLS WB - MASTER BUS"
local FXBUS_NAME  = "IFLS WB - FX BUS"

local function msg(s) r.ShowConsoleMsg(tostring(s).."\n") end

local function join(a,b)
  if not a or a == "" then return b end
  local last = a:sub(-1)
  if last == "/" or last == "\\" or last == sep then return a..b end
  return a .. sep .. b
end

local function norm_res_path(p)
  -- ensure OS-native separators for io.open/dofile
  if sep == "\\" then
    return (p:gsub("/", "\\"))
  else
    return (p:gsub("\\", "/"))
  end
end

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

local function unselect_all_items()
  r.Main_OnCommand(40289, 0) -- Unselect all items
end

local function select_all_items_on_track(tr)
  if not tr then return 0 end
  unselect_all_items()
  local cnt = r.CountTrackMediaItems(tr)
  for i = 0, cnt-1 do
    local it = r.GetTrackMediaItem(tr, i)
    r.SetMediaItemSelected(it, true)
  end
  return cnt
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

local function run_script_relative(rel)
  local path = norm_res_path(join(r.GetResourcePath(), rel))
  local f = io.open(path, "rb")
  if f then
    f:close()
    dofile(path)
    return true
  end
  return false
end

local function snapshot_track_guids()
  local t = {}
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    local guid = r.GetTrackGUID(tr)
    t[guid] = true
  end
  return t
end

local function find_new_track(before_set)
  for i = 0, r.CountTracks(0) - 1 do
    local tr = r.GetTrack(0, i)
    local guid = r.GetTrackGUID(tr)
    if not before_set[guid] then
      return tr
    end
  end
end

local function cursor_inside_any_selected_item()
  local cur = r.GetCursorPosition()
  local cnt = r.CountSelectedMediaItems(0)
  for i = 0, cnt-1 do
    local it = r.GetSelectedMediaItem(0, i)
    local p = r.GetMediaItemInfo_Value(it, "D_POSITION")
    local l = r.GetMediaItemInfo_Value(it, "D_LENGTH")
    if cur > p and cur < (p+l) then return true end
  end
  return false
end

-- ========= main =========
local master = find_track_by_exact_name(MASTER_NAME)
local fxbus  = find_track_by_exact_name(FXBUS_NAME)

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

local source_bus = fxbus or master
local mic_tracks = collect_tracks_sending_to(source_bus)
local any_stereo = detect_any_stereo_in_tracks(mic_tracks)

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

-- Keep user's mute state. Render action may mute originals.
local old_mute = r.GetMediaTrackInfo_Value(master, "B_MUTE")

set_only_selected_track(master)

local before = snapshot_track_guids()
local n_before = r.CountTracks(0)

local function try_render(cmd)
  r.Main_OnCommand(cmd, 0)
  return r.CountTracks(0) > n_before
end

local ok_render
if any_stereo then
  -- Try common IDs (may vary by action list/export). If none work, still continue with warning.
  ok_render = try_render(40405) or try_render(40406) or try_render(40788)
else
  ok_render = try_render(40537) or try_render(40538) or try_render(40787)
end

if not ok_render then
  r.PreventUIRefresh(-1)
  r.SetMediaTrackInfo_Value(master, "B_MUTE", old_mute)
  r.Undo_EndBlock("IFLS Slice Smart: print bus -> slice (FAILED)", -1)
  r.ShowMessageBox(
    "Couldn't render stem track (render action not found?).\n\nTry running the render-to-stem action manually from the Action List, then run Slice Direct.",
    "IFLS Slice Smart", 0
  )
  return
end

-- Restore master mute (render action often mutes originals)
r.SetMediaTrackInfo_Value(master, "B_MUTE", old_mute)

-- Find new stem track robustly
local stem = find_new_track(before)

if stem then
  local suffix = any_stereo and "STEREO" or "MONO"
  r.GetSetMediaTrackInfo_String(stem, "P_NAME", "IFLS WB - SLICE SOURCE ("..suffix..")", true)
  set_only_selected_track(stem)
  local n_items = select_all_items_on_track(stem)
  if n_items == 0 then
    msg("[IFLS Slice Smart] Printed stem track found but has no items selected.")
  end
else
  msg("[IFLS Slice Smart] Couldn't detect the printed stem track. Aborting Slice Direct.")
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock("IFLS Slice Smart: print bus -> slice (FAILED: no stem)", -1)
  return
end

-- Ensure Slice Direct will actually split: cursor must be inside selected item(s) if no time selection exists.
local ts_s, ts_e = r.GetSet_LoopTimeRange(false, false, 0, 0, false)
if not (ts_e > ts_s) then
  if not cursor_inside_any_selected_item() then
    local it = r.GetSelectedMediaItem(0, 0)
    if it then
      local p = r.GetMediaItemInfo_Value(it, "D_POSITION")
      r.SetEditCurPos(p + 0.001, false, false)
    end
  end
end

r.PreventUIRefresh(-1)
r.UpdateArrange()

-- Run Slice Direct
local ok = run_script_relative("Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slice_Direct.lua")
if not ok then
  r.ShowMessageBox(
    "Printed stem created, but couldn't find Slice Direct script:\n\nScripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slice_Direct.lua",
    "IFLS Slice Smart", 0
  )
else
  -- Requested: mute the track that was sliced
  r.SetMediaTrackInfo_Value(stem, "B_MUTE", 1)
end

r.Undo_EndBlock("IFLS Slice Smart: print bus -> slice", -1)
r.UpdateArrange()
