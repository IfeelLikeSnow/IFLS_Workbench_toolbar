-- @description IFLS WB: PostFix HQ (Extend + TailDetect to Silence)
-- @version 1.0.0
-- @author IFLS Workbench
-- @about Extends selected slices to the next start, and for the last slice per track detects the tail end (to silence) using audio RMS analysis.
-- @provides [main] .

local r = reaper
local function db_to_amp(db) return 10^(db/20) end

local CFG = {
  samplerate = 12000,
  channels = 2,
  block = 512,
  hop = 256,
  silence_db = -60.0,
  hold_s = 0.12,
  pad_s = 0.01,
  max_tail_s = 12.0,
}

local function sort_items_by_pos(items)
  table.sort(items, function(a,b)
    return r.GetMediaItemInfo_Value(a,"D_POSITION") < r.GetMediaItemInfo_Value(b,"D_POSITION")
  end)
end

local function get_selected_items_by_track()
  local by_tr = {}
  local n = r.CountSelectedMediaItems(0)
  for i=0,n-1 do
    local it = r.GetSelectedMediaItem(0,i)
    local tr = r.GetMediaItem_Track(it)
    by_tr[tr] = by_tr[tr] or {}
    table.insert(by_tr[tr], it)
  end
  return by_tr
end

local function get_take(item)
  local take = r.GetActiveTake(item)
  if not take or r.TakeIsMIDI(take) then return nil end
  return take
end

local function get_max_item_end_from_source(item)
  local take = get_take(item)
  if not take then return nil end
  local src = r.GetMediaItemTake_Source(take)
  if not src then return nil end

  local src_len = select(1, r.GetMediaSourceLength(src))
  local startoffs = r.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local playrate = r.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  if playrate <= 0 then playrate = 1.0 end

  local item_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = r.GetMediaItemInfo_Value(item, "D_LENGTH")

  local end_src = startoffs + (item_len * playrate)
  local remaining_src = src_len - end_src
  if remaining_src < 0 then remaining_src = 0 end
  local remaining_proj = remaining_src / playrate
  return item_pos + item_len + remaining_proj
end

local function detect_tail_end_project_time(item)
  local take = get_take(item)
  if not take then return nil end

  local item_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  local scan_start = item_pos + item_len

  local max_end = get_max_item_end_from_source(item) or (scan_start + CFG.max_tail_s)
  max_end = math.min(max_end, scan_start + CFG.max_tail_s)
  if max_end <= scan_start + 1e-6 then return scan_start end

  local aa = r.CreateTakeAudioAccessor(take)
  if not aa then return nil end

  local sr, nch = CFG.samplerate, CFG.channels
  local block, hop = CFG.block, CFG.hop
  local silence_amp = db_to_amp(CFG.silence_db)

  local buf = r.new_array(block*nch)
  local silent_run = 0.0
  local t = scan_start
  local found = nil

  while t < max_end do
    buf.clear()
    local ok = r.GetAudioAccessorSamples(aa, sr, nch, t, math.floor(block), buf)
    if ok <= 0 then break end
    local arr = buf.table()
    local sumsq = 0.0
    local n = ok*nch
    for i=1,n do
      local v = arr[i]
      sumsq = sumsq + v*v
    end
    local rms = math.sqrt(sumsq / math.max(1,n))
    local dt = ok / sr

    if rms <= silence_amp then
      silent_run = silent_run + dt
      if silent_run >= CFG.hold_s then
        found = t - (silent_run - CFG.hold_s)
        break
      end
    else
      silent_run = 0.0
    end

    t = t + (hop/sr)
  end

  r.DestroyAudioAccessor(aa)
  if not found then found = max_end end
  return found + CFG.pad_s
end

local function main()
  local by_tr = get_selected_items_by_track()
  local any = false

  for _, items in pairs(by_tr) do
    if #items >= 1 then
      any = true
      sort_items_by_pos(items)
      for i=1,#items-1 do
        local a, b = items[i], items[i+1]
        local a_pos = r.GetMediaItemInfo_Value(a,"D_POSITION")
        local b_pos = r.GetMediaItemInfo_Value(b,"D_POSITION")
        r.SetMediaItemInfo_Value(a,"D_LENGTH", math.max(0.0, b_pos - a_pos))
      end
      local last = items[#items]
      local last_pos = r.GetMediaItemInfo_Value(last,"D_POSITION")
      local tail_end = detect_tail_end_project_time(last)
      if tail_end then
        r.SetMediaItemInfo_Value(last, "D_LENGTH", math.max(0.0, tail_end - last_pos))
      end
    end
  end

  if not any then
    r.MB("Select slices to post-fix (per track).", "IFLSWB PostFix HQ", 0)
    return
  end

  r.UpdateArrange()
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)
main()
r.PreventUIRefresh(-1)
r.Undo_EndBlock("IFLS WB: PostFix HQ Extend + TailDetect", -1)
