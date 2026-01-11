-- @description IFLS Workbench: Smart Slice (AUTO mode: markers/regions/onsets/grid)
-- @version 0.8.0
-- @author IFLS
-- @about
--   For IDM / glitch / electronic slicing:
--   1) duplicates the selected source items to a dedicated slice track (placed before FX BUS if present),
--   2) analyzes the audio and automatically chooses the most effective slicing mode:
--        - REGIONS   (if any regions overlap the item)
--        - MARKERS   (if enough markers exist inside the item)
--        - ONSETS    (automatic onset detection using Take Audio Accessor)
--        - GRID      (fallback if no onsets found)
--   3) applies small fades to all resulting slices
--   4) optionally runs ZeroCross PostFix (if script exists)
--   5) mutes the source track(s) (so you only hear the slices)
--
--   Usage:
--     - Select the item(s) you want to slice, then run this script.
--     - If no items are selected, it will use items on the selected track (or the track named "IFLS WB - MASTER BUS - stem" if found).
--
--   Notes:
--     - No SWS required (uses Audio Accessor). If SWS is present you can still use your other slicing tools.
--     - Works best when your source item contains clear transients (glitch/percussive material).
--
-- @changelog
--   + initial release

local r = reaper

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------

local CFG = {
  slice_track_name = "IFLS WB - SLICE",
  fxbus_track_name = "IFLS WB - FX BUS",

  -- Decision thresholds:
  markers_min_count = 3,   -- if >= this many markers inside an item => MARKERS mode
  regions_use = true,      -- if any region overlaps item => REGIONS mode (highest priority)

  -- Onset detection (fast + robust for glitch/percussive audio):
  analysis_sr = 11025,     -- analysis samplerate (lower = faster)
  win = 1024,              -- window size (samples)
  hop = 512,               -- hop size (samples)
  onset_k = 1.75,          -- threshold = mean(diff) + k*std(diff)
  min_sep_sec = 0.030,     -- minimum time between slices (seconds)
  max_slices_per_item = 600,

  -- Fades:
  apply_fades = true,
  fade_len_sec = 0.003,    -- 3ms
  fade_shape = 0,          -- 0=linear, 1=fast start, 2=fast end, 3=slow start/end, etc (REAPER shapes)
  preserve_existing_fades = false,

  -- Optional post steps:
  run_zerocross_postfix = true,
  zerocross_postfix_rel = "Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_ZeroCross_PostFix.lua",
  mute_source_tracks = true,
}

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------

local function msg(s) r.ShowConsoleMsg(tostring(s) .. "\n") end

local function path_join(a, b)
  if not a or a == "" then return b end
  local sep = package.config:sub(1,1)
  if a:sub(-1) ~= sep then a = a .. sep end
  return a .. b
end

local function normalize_path(p)
  return (p or ""):gsub("\\", "/")
end

local function get_track_name(tr)
  local _, name = r.GetTrackName(tr, "")
  return name or ""
end

local function find_track_by_name_substr(substr)
  substr = (substr or ""):lower()
  local cnt = r.CountTracks(0)
  for i=0,cnt-1 do
    local tr = r.GetTrack(0,i)
    local name = get_track_name(tr):lower()
    if name:find(substr, 1, true) then return tr, i end
  end
  return nil, nil
end

local function ensure_slice_track()
  local tr, idx = find_track_by_name_substr(CFG.slice_track_name:lower())
  if tr then return tr, idx, false end

  -- create new track (prefer before FX BUS if present)
  local fxtr, fxidx = find_track_by_name_substr(CFG.fxbus_track_name:lower())
  local insert_idx = fxidx or r.CountTracks(0)
  r.InsertTrackAtIndex(insert_idx, true)
  tr = r.GetTrack(0, insert_idx)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", CFG.slice_track_name, true)
  return tr, insert_idx, true
end

local function get_selected_items_or_track_items()
  local items = {}
  local sel = r.CountSelectedMediaItems(0)
  if sel > 0 then
    for i=0,sel-1 do
      items[#items+1] = r.GetSelectedMediaItem(0,i)
    end
    return items
  end

  -- no selected items: use selected track items
  local tr = r.GetSelectedTrack(0,0)
  if not tr then
    -- try common stem track name
    tr = select(1, find_track_by_name_substr("master bus - stem"))
  end
  if not tr then
    return items
  end
  local itcnt = r.CountTrackMediaItems(tr)
  for i=0,itcnt-1 do
    items[#items+1] = r.GetTrackMediaItem(tr,i)
  end
  return items
end

local function unique_tracks_of_items(items)
  local set, out = {}, {}
  for _,it in ipairs(items) do
    local tr = r.GetMediaItemTrack(it)
    if tr and not set[tr] then
      set[tr] = true
      out[#out+1] = tr
    end
  end
  return out
end

local function get_time_sel()
  local st, en = r.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if en > st then return st, en end
  return nil, nil
end

----------------------------------------------------------------------
-- Duplicate items to slice track (keeps source items intact)
----------------------------------------------------------------------

local function duplicate_item_to_track(src_item, dst_track)
  local src_take = r.GetActiveTake(src_item)
  if not src_take then return nil end

  local src_pos = r.GetMediaItemInfo_Value(src_item, "D_POSITION")
  local src_len = r.GetMediaItemInfo_Value(src_item, "D_LENGTH")
  local src_mute = r.GetMediaItemInfo_Value(src_item, "B_MUTE")
  local src_loopsrc = r.GetMediaItemInfo_Value(src_item, "B_LOOPSRC")

  local src_take_src = r.GetMediaItemTake_Source(src_take)
  local startoffs = r.GetMediaItemTakeInfo_Value(src_take, "D_STARTOFFS")
  local playrate = r.GetMediaItemTakeInfo_Value(src_take, "D_PLAYRATE")
  local take_vol = r.GetMediaItemTakeInfo_Value(src_take, "D_VOL")
  local take_pan = r.GetMediaItemTakeInfo_Value(src_take, "D_PAN")
  local chanmode = r.GetMediaItemTakeInfo_Value(src_take, "I_CHANMODE")

  local dst_item = r.AddMediaItemToTrack(dst_track)
  if not dst_item then return nil end
  r.SetMediaItemInfo_Value(dst_item, "D_POSITION", src_pos)
  r.SetMediaItemInfo_Value(dst_item, "D_LENGTH", src_len)
  r.SetMediaItemInfo_Value(dst_item, "B_MUTE", src_mute)
  r.SetMediaItemInfo_Value(dst_item, "B_LOOPSRC", src_loopsrc)

  local dst_take = r.AddTakeToMediaItem(dst_item)
  if not dst_take then return dst_item end

  -- Assign same media source
  if r.SetMediaItemTake_Source and src_take_src then
    r.SetMediaItemTake_Source(dst_take, src_take_src)
  end

  r.SetMediaItemTakeInfo_Value(dst_take, "D_STARTOFFS", startoffs)
  r.SetMediaItemTakeInfo_Value(dst_take, "D_PLAYRATE", playrate)
  r.SetMediaItemTakeInfo_Value(dst_take, "D_VOL", take_vol)
  r.SetMediaItemTakeInfo_Value(dst_take, "D_PAN", take_pan)
  r.SetMediaItemTakeInfo_Value(dst_take, "I_CHANMODE", chanmode)

  r.SetActiveTake(dst_take)
  return dst_item
end

----------------------------------------------------------------------
-- Marker/Region helpers
----------------------------------------------------------------------

local function enum_project_markers()
  local markers = {}
  local regions = {}

  local retval, num_markers, num_regions = r.CountProjectMarkers(0)
  local total = num_markers + num_regions
  for i=0,total-1 do
    local ok, isrgn, pos, rgnend, name
    if r.EnumProjectMarkers3 then
      ok, isrgn, pos, rgnend, name = r.EnumProjectMarkers3(0, i)
    else
      ok, isrgn, pos, rgnend, name = r.EnumProjectMarkers(i)
    end
    if ok then
      if isrgn then
        regions[#regions+1] = {pos=pos, rgnend=rgnend, name=name or ""}
      else
        markers[#markers+1] = {pos=pos, name=name or ""}
      end
    end
  end
  table.sort(markers, function(a,b) return a.pos < b.pos end)
  table.sort(regions, function(a,b) return a.pos < b.pos end)
  return markers, regions
end

local function markers_regions_in_range(range_start, range_end)
  local allm, allr = enum_project_markers()
  local m, rgn = {}, {}
  for _,mk in ipairs(allm) do
    if mk.pos > range_start and mk.pos < range_end then
      m[#m+1] = mk.pos
    end
  end
  for _,rg in ipairs(allr) do
    if rg.rgnend > range_start and rg.pos < range_end then
      rgn[#rgn+1] = {pos=rg.pos, rgnend=rg.rgnend}
    end
  end
  return m, rgn
end

----------------------------------------------------------------------
-- ONSET detection (Audio Accessor)
----------------------------------------------------------------------

local function mean_std(t)
  if #t == 0 then return 0, 0 end
  local sum = 0
  for i=1,#t do sum = sum + t[i] end
  local mean = sum / #t
  local var = 0
  for i=1,#t do
    local d = t[i] - mean
    var = var + d*d
  end
  var = var / #t
  return mean, math.sqrt(var)
end

local function detect_onsets_for_take(take, start_t, end_t)
  if not take then return {} end

  local src = r.GetMediaItemTake_Source(take)
  local chans = 2
  if src and r.GetMediaSourceNumChannels then
    local c = r.GetMediaSourceNumChannels(src)
    if c and c > 0 then chans = math.min(2, c) end
  end

  local sr = CFG.analysis_sr
  local win = CFG.win
  local hop = CFG.hop
  local step = hop / sr

  local acc = r.CreateTakeAudioAccessor(take)
  if not acc then return {} end

  local buf = r.new_array(win * chans)
  local energies = {}

  local t = start_t
  while t < end_t do
    buf.clear()
    r.GetAudioAccessorSamples(acc, sr, chans, t, win, buf)
    local arr = buf.table()
    local n = win * chans
    local sum = 0
    for i=1,n do
      local v = arr[i]
      sum = sum + v*v
    end
    energies[#energies+1] = math.sqrt(sum / n)
    t = t + step
  end

  r.DestroyAudioAccessor(acc)

  if #energies < 3 then return {} end

  local diffs = {}
  for i=2,#energies do
    local d = energies[i] - energies[i-1]
    if d < 0 then d = 0 end
    diffs[#diffs+1] = d
  end

  local mu, sd = mean_std(diffs)
  local thr = mu + CFG.onset_k * sd

  local onsets = {}
  local last = -1e9
  for i=1,#diffs do
    local d = diffs[i]
    if d > thr then
      local tt = start_t + (i * step)
      if (tt - last) >= CFG.min_sep_sec then
        onsets[#onsets+1] = tt
        last = tt
      end
    end
  end

  -- if too many, increase min spacing adaptively
  if #onsets > CFG.max_slices_per_item then
    local keep = {}
    local minsep = CFG.min_sep_sec * 2
    last = -1e9
    for _,tt in ipairs(onsets) do
      if (tt - last) >= minsep then
        keep[#keep+1] = tt
        last = tt
      end
      if #keep >= CFG.max_slices_per_item then break end
    end
    onsets = keep
  end

  return onsets
end

----------------------------------------------------------------------
-- Splitting
----------------------------------------------------------------------

local function split_item_at_times(item, times)
  if not item or #times == 0 then return end
  local it_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local it_end = it_pos + r.GetMediaItemInfo_Value(item, "D_LENGTH")

  local cur = item
  for _,t in ipairs(times) do
    if t > it_pos and t < it_end then
      local right = r.SplitMediaItem(cur, t)
      if right then cur = right end
    end
  end
end

local function split_item_by_regions(item, regions)
  if #regions == 0 then return false end
  local it_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local it_end = it_pos + r.GetMediaItemInfo_Value(item, "D_LENGTH")
  local times = {}
  for _,rg in ipairs(regions) do
    local a = math.max(it_pos, rg.pos)
    local b = math.min(it_end, rg.rgnend)
    if a > it_pos and a < it_end then times[#times+1] = a end
    if b > it_pos and b < it_end then times[#times+1] = b end
  end
  table.sort(times)
  split_item_at_times(item, times)
  return #times > 0
end

local function split_item_by_markers(item, markers)
  if #markers == 0 then return false end
  split_item_at_times(item, markers)
  return true
end

local function split_item_by_onsets(item)
  local take = r.GetActiveTake(item)
  if not take then return false end
  local it_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local it_end = it_pos + r.GetMediaItemInfo_Value(item, "D_LENGTH")

  -- respect time selection if it intersects item
  local ts_s, ts_e = get_time_sel()
  local s, e = it_pos, it_end
  if ts_s and ts_e then
    local ss = math.max(it_pos, ts_s)
    local ee = math.min(it_end, ts_e)
    if ee > ss then s, e = ss, ee end
  end

  local onsets = detect_onsets_for_take(take, s, e)
  if #onsets == 0 then return false end
  split_item_at_times(item, onsets)
  return true
end

local function split_item_by_grid(item)
  local it_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local it_end = it_pos + r.GetMediaItemInfo_Value(item, "D_LENGTH")
  local dur = it_end - it_pos
  if dur <= 0 then return false end

  local bpm = r.GetSetProjectInfo(0, "PROJECT_BPM", 120, false)
  if not bpm or bpm <= 0 then bpm = 120 end
  local spb = 60.0 / bpm

  -- choose 1/16 as default, but clamp by duration
  local step = spb / 4.0
  local max_slices = 64
  if dur / step > max_slices then
    step = dur / max_slices
  end
  step = math.max(0.02, math.min(0.5, step))

  local times = {}
  local t = it_pos + step
  while t < it_end do
    times[#times+1] = t
    t = t + step
    if #times > CFG.max_slices_per_item then break end
  end
  if #times == 0 then return false end
  split_item_at_times(item, times)
  return true
end

local function choose_mode_and_split(item)
  local it_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local it_end = it_pos + r.GetMediaItemInfo_Value(item, "D_LENGTH")

  local markers, regions = markers_regions_in_range(it_pos, it_end)

  if CFG.regions_use and #regions > 0 then
    if split_item_by_regions(item, regions) then return "REGIONS" end
  end

  if #markers >= CFG.markers_min_count then
    if split_item_by_markers(item, markers) then return "MARKERS" end
  end

  if split_item_by_onsets(item) then return "ONSETS" end
  if split_item_by_grid(item) then return "GRID" end
  return "NONE"
end

----------------------------------------------------------------------
-- Fade apply on a track
----------------------------------------------------------------------

local function apply_fades_to_track(track)
  if not track or not CFG.apply_fades then return end
  local itcnt = r.CountTrackMediaItems(track)
  for i=0,itcnt-1 do
    local it = r.GetTrackMediaItem(track,i)
    if not CFG.preserve_existing_fades then
      r.SetMediaItemInfo_Value(it, "D_FADEINLEN", 0)
      r.SetMediaItemInfo_Value(it, "D_FADEOUTLEN", 0)
    end
    r.SetMediaItemInfo_Value(it, "D_FADEINLEN", CFG.fade_len_sec)
    r.SetMediaItemInfo_Value(it, "D_FADEOUTLEN", CFG.fade_len_sec)
    r.SetMediaItemInfo_Value(it, "C_FADEINSHAPE", CFG.fade_shape)
    r.SetMediaItemInfo_Value(it, "C_FADEOUTSHAPE", CFG.fade_shape)
  end
end

----------------------------------------------------------------------
-- Optional ZeroCross PostFix
----------------------------------------------------------------------

local function run_zerocross_postfix()
  if not CFG.run_zerocross_postfix then return end
  local res = r.GetResourcePath()
  local script_path = normalize_path(path_join(res, CFG.zerocross_postfix_rel))
  local f = io.open(script_path, "r")
  if f then f:close() else return end
  dofile(script_path)
end

----------------------------------------------------------------------
-- Main
----------------------------------------------------------------------

local function main()
  local src_items = get_selected_items_or_track_items()
  if #src_items == 0 then
    r.ShowMessageBox("No items found.\n\nSelect the item(s) you want to slice, then run again.", "IFLS Smart Slice (AUTO)", 0)
    return
  end

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local slice_tr = select(1, ensure_slice_track())

  -- duplicate items to slice track
  local new_items = {}
  for _,it in ipairs(src_items) do
    local dup = duplicate_item_to_track(it, slice_tr)
    if dup then new_items[#new_items+1] = dup end
  end

  -- mute source tracks
  if CFG.mute_source_tracks then
    local tracks = unique_tracks_of_items(src_items)
    for _,tr in ipairs(tracks) do
      r.SetMediaTrackInfo_Value(tr, "B_MUTE", 1)
    end
  end

  -- slice the duplicates
  local mode_counts = {}
  for _,it in ipairs(new_items) do
    local mode = choose_mode_and_split(it)
    mode_counts[mode] = (mode_counts[mode] or 0) + 1
  end

  -- apply fades to all slices on slice track
  apply_fades_to_track(slice_tr)

  -- optional: ZeroCross PostFix (operates on selection in its own script)
  -- We select all items on slice track first (best effort).
  r.Main_OnCommand(40289, 0) -- Unselect all items
  local itcnt = r.CountTrackMediaItems(slice_tr)
  for i=0,itcnt-1 do
    local it = r.GetTrackMediaItem(slice_tr, i)
    r.SetMediaItemSelected(it, true)
  end
  run_zerocross_postfix()

  r.PreventUIRefresh(-1)
  r.UpdateArrange()

  local summary = {}
  for k,v in pairs(mode_counts) do summary[#summary+1] = string.format("%s=%d", k, v) end
  table.sort(summary)
  r.Undo_EndBlock("IFLS Smart Slice (AUTO): " .. table.concat(summary, ", "), -1)
end

main()
