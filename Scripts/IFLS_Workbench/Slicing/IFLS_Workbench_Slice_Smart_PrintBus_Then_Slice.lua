-- @description IFLS Workbench - Slicing/IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench - Smart Slice (Pre-Analyze Onsets + Peak Tail Detection)
-- @version 3.0.0
-- @author IFLS
-- @about One-click smart slicing: pre-analyze onsets, detect tails by silence (peak-based), then split+trim.


local R = reaper

local CFG = {
  peakrate_onset = 400.0,
  onset_rel_db   = -26.0,
  onset_abs_db   = -80.0,
  onset_confirm_frames = 3,
  onset_min_gap_ms = 70,

  peakrate_tail  = 200.0,
  tail_peak_win_ms = 50,
  tail_rel_db    = -45.0,
  tail_abs_floor_db = -90.0,
  tail_abs_ceil_db  = -30.0,
  tail_hold_ms   = 140,
  tail_min_len_ms = 25,
  tail_max_search_ms_last = 12000,

  gap_ms         = 2,
  fadeout_ms     = 5,
  keep_selection = true,
  verbose_log    = false,
}

local function msg(s)
  if CFG.verbose_log then R.ShowConsoleMsg(tostring(s).."\n") end
end

local function amp_to_db(a)
  if not a or a <= 0 then return -150.0 end
  return 20.0 * (math.log(a, 10))
end

local function db_to_amp(db) return 10.0 ^ (db / 20.0) end

local function get_item_bounds(it)
  local pos = R.GetMediaItemInfo_Value(it, "D_POSITION")
  local len = R.GetMediaItemInfo_Value(it, "D_LENGTH")
  return pos, pos + len, len
end

local function samplecount_from_ret(ret)
  if _VERSION:match("5%.3") or _VERSION:match("5%.4") then
    return ret & 0xFFFFF
  elseif bit32 then
    return bit32.band(ret, 0xFFFFF)
  else
    return ret % 0x100000
  end
end

local function get_max_peak_in_range(take, t0, dur, peakrate, numch)
  if dur <= 0 then return 0.0 end
  local numsamp = math.max(1, math.floor(dur * peakrate))
  numch = math.max(1, math.min(numch or 2, 2))
  local buf = R.new_array(numsamp * numch * 2)
  local ret = R.GetMediaItemTake_Peaks(take, peakrate, t0, numch, numsamp, 0, buf)
  local sc = samplecount_from_ret(ret)
  if sc <= 0 then return 0.0 end
  local tbl = buf.table(1, sc * numch * 2)
  local maxamp = 0.0
  local max_block = sc * numch
  for i=1, max_block do
    local a = math.abs(tbl[i] or 0.0)
    if a > maxamp then maxamp = a end
  end
  for i=max_block+1, max_block*2 do
    local a = math.abs(tbl[i] or 0.0)
    if a > maxamp then maxamp = a end
  end
  return maxamp
end

local function detect_onsets_for_item(it, take)
  local pos, fin = get_item_bounds(it)
  if fin <= pos then return {pos} end

  local pr = CFG.peakrate_onset
  local dur = fin - pos

  local peak_item = get_max_peak_in_range(take, pos, dur, pr, 2)
  local peak_db = amp_to_db(peak_item)

  local thr_db = peak_db + CFG.onset_rel_db
  if thr_db < CFG.onset_abs_db then thr_db = CFG.onset_abs_db end
  local thr = db_to_amp(thr_db)
  msg(("Onset thr %.1fdB"):format(thr_db))

  local confirm = math.max(1, CFG.onset_confirm_frames)
  local min_gap_frames = math.max(1, math.floor((CFG.onset_min_gap_ms/1000.0) * pr))

  local numch, chunk = 2, 2000
  local total = math.max(1, math.floor(dur * pr))
  local buf = R.new_array(chunk * numch * 2)

  local onsets = {pos}
  local last_onset = -1e9
  local above_run = 0
  local idx = 0

  while idx < total do
    local want = math.min(chunk, total - idx)
    buf.resize(want * numch * 2)
    local t0 = pos + (idx / pr)
    local ret = R.GetMediaItemTake_Peaks(take, pr, t0, numch, want, 0, buf)
    local got = samplecount_from_ret(ret)
    if got <= 0 then break end

    local arr = buf.table(1, got * numch * 2)
    local max_block = got * numch

    for f=0, got-1 do
      local m = 0.0
      for ch=1, numch do
        local vmax = math.abs(arr[f*numch + ch] or 0.0)
        local vmin = math.abs(arr[max_block + f*numch + ch] or 0.0)
        local v = (vmax > vmin) and vmax or vmin
        if v > m then m = v end
      end

      if m >= thr then
        above_run = above_run + 1
        if above_run == confirm then
          local abs_frame = idx + f - (confirm - 1)
          if abs_frame - last_onset >= min_gap_frames then
            onsets[#onsets+1] = pos + (abs_frame / pr)
            last_onset = abs_frame
          end
        end
      else
        above_run = 0
      end
    end

    idx = idx + got
    if got < want then break end
  end

  table.sort(onsets)

  local dedup, eps = {}, 0.002
  for i=1,#onsets do
    local t = onsets[i]
    if t >= pos and t < fin then
      if #dedup==0 or (t - dedup[#dedup]) > eps then
        dedup[#dedup+1] = t
      end
    end
  end

  return dedup
end

local function find_tail_end(take, onset_t, search_end_t)
  local pr = CFG.peakrate_tail
  local min_len = CFG.tail_min_len_ms/1000.0
  if search_end_t <= onset_t + min_len then
    return math.max(onset_t + min_len, search_end_t)
  end

  local peak_win = math.min(CFG.tail_peak_win_ms/1000.0, search_end_t - onset_t)
  local local_peak = get_max_peak_in_range(take, onset_t, peak_win, pr, 2)
  local local_db = amp_to_db(local_peak)

  local thr_db = local_db + CFG.tail_rel_db
  if thr_db < CFG.tail_abs_floor_db then thr_db = CFG.tail_abs_floor_db end
  if thr_db > CFG.tail_abs_ceil_db  then thr_db = CFG.tail_abs_ceil_db  end
  local thr = db_to_amp(thr_db)

  local hold = math.max(1, math.floor((CFG.tail_hold_ms/1000.0) * pr))
  local numch, chunk = 2, 2000
  local total = math.max(1, math.floor((search_end_t - onset_t) * pr))
  local buf = R.new_array(chunk * numch * 2)

  local below = 0
  local idx = math.floor(min_len * pr)

  while idx < total do
    local want = math.min(chunk, total - idx)
    buf.resize(want * numch * 2)
    local t0 = onset_t + (idx / pr)

    local ret = R.GetMediaItemTake_Peaks(take, pr, t0, numch, want, 0, buf)
    local got = samplecount_from_ret(ret)
    if got <= 0 then break end

    local arr = buf.table(1, got * numch * 2)
    local max_block = got * numch

    for f=0, got-1 do
      local m = 0.0
      for ch=1, numch do
        local vmax = math.abs(arr[f*numch + ch] or 0.0)
        local vmin = math.abs(arr[max_block + f*numch + ch] or 0.0)
        local v = (vmax > vmin) and vmax or vmin
        if v > m then m = v end
      end

      if m < thr then
        below = below + 1
        if below >= hold then
          local end_frame = (idx + f) - (hold - 1)
          return math.min(onset_t + (end_frame / pr), search_end_t)
        end
      else
        below = 0
      end
    end

    idx = idx + got
    if got < want then break end
  end

  return search_end_t
end

local function build_slice_plan(it, take)
  local pos, fin = get_item_bounds(it)
  local onsets = detect_onsets_for_item(it, take)
  local gap = CFG.gap_ms/1000.0
  local ends = {}

  for i=1,#onsets do
    local start_t = onsets[i]
    local next_t = onsets[i+1]
    local search_end = next_t and math.max(start_t, next_t - gap) or (fin + (CFG.tail_max_search_ms_last/1000.0))

    local tail_end = find_tail_end(take, start_t, search_end)
    local end_t = next_t and math.min(tail_end, next_t - gap) or tail_end

    local min_len = CFG.tail_min_len_ms/1000.0
    if end_t < start_t + min_len then end_t = start_t + min_len end
    if end_t > fin then end_t = fin end
    ends[i] = end_t
  end

  return onsets, ends
end

local function slice_item_by_plan(it, onsets, ends)
  if #onsets < 1 then return {} end
  local slices = {}
  local cur = it

  for i=2,#onsets do
    local right = R.SplitMediaItem(cur, onsets[i])
    if not right then break end
    slices[#slices+1] = cur
    cur = right
  end
  slices[#slices+1] = cur

  local fade_s = CFG.fadeout_ms/1000.0
  local min_len = CFG.tail_min_len_ms/1000.0

  for i=1,#slices do
    local s_it = slices[i]
    local s_pos = R.GetMediaItemInfo_Value(s_it, "D_POSITION")
    local e_t = ends[i] or (s_pos + min_len)
    local new_len = math.max(min_len, e_t - s_pos)
    R.SetMediaItemInfo_Value(s_it, "D_LENGTH", new_len)
    if fade_s > 0 then R.SetMediaItemInfo_Value(s_it, "D_FADEOUTLEN", fade_s) end
  end

  return slices
end

local function main()
  local n = R.CountSelectedMediaItems(0)
  if n == 0 then
    R.MB("Bitte mindestens 1 Audio-Item selektieren.", "IFLSWB Smart Slice", 0)
    return
  end

  R.Undo_BeginBlock()
  R.PreventUIRefresh(1)

  local items = {}
  for i=0,n-1 do items[#items+1] = R.GetSelectedMediaItem(0,i) end
  if CFG.keep_selection then
    for i=1,#items do R.SetMediaItemSelected(items[i], false) end
  end

  local out = {}
  for _,it in ipairs(items) do
    local take = R.GetActiveTake(it)
    if take and not R.TakeIsMIDI(take) then
      local onsets, ends = build_slice_plan(it, take)
      local slices = slice_item_by_plan(it, onsets, ends)
      for i=1,#slices do out[#out+1] = slices[i] end
    end
  end

  if CFG.keep_selection then
    for i=1,#out do R.SetMediaItemSelected(out[i], true) end
  end

  R.UpdateArrange()
  R.PreventUIRefresh(-1)
  R.Undo_EndBlock("IFLSWB Smart Slice (pre-analyze + tail)", -1)
end

main()
