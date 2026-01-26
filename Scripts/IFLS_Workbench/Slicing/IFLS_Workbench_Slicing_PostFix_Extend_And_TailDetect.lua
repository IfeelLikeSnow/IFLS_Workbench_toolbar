-- @description IFLS Workbench: IFLS_Workbench_Slicing_PostFix_Extend_And_TailDetect
﻿-- @description IFLS Workbench - Slicing PostFix: Extend slices + Tail detect last
-- @version 1.0.0
-- @author IFLS
-- @about
--   Fix micro-slices by extending each selected item to next selected item's start (minus gap).
--   Then extends the LAST selected item until "silence" using peak scanning (GetMediaItemTake_Peaks).
-- @provides [main] .

-- =========================
-- User settings
-- =========================
local GAP_MS              = 5       -- gap between slices (avoid overlaps)
local MIN_LEN_MS          = 40      -- never shorter than this
local EXTEND_LAST         = true
local DISABLE_LOOP_SOURCE_LAST = true

-- Tail detection settings
local SILENCE_DB          = -45.0   -- threshold
local HOLD_MS             = 140     -- must stay silent this long to count as end
local PEAKRATE            = 200.0   -- peaks/sec (higher = more accurate)
local LAST_MAX_SEARCH_MS  = 8000    -- cap search window (ms)

-- =========================
-- Helpers
-- =========================
local function db_to_lin(db) return 10^(db/20) end

local function band20(x)
  -- GetMediaItemTake_Peaks packs sample count in low 20 bits
  if _VERSION:match("5%.3") or _VERSION:match("5%.4") then
    return x & 0xFFFFF
  elseif bit32 then
    return bit32.band(x, 0xFFFFF)
  else
    return x
  end
end

local function get_sel_items_sorted()
  local t = {}
  local n = reaper.CountSelectedMediaItems(0)
  for i=0,n-1 do
    local it = reaper.GetSelectedMediaItem(0,i)
    local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
    t[#t+1] = {item=it, pos=pos}
  end
  table.sort(t, function(a,b) return a.pos < b.pos end)
  return t
end

local function set_item_len(it, len_s)
  local min_s = MIN_LEN_MS/1000.0
  if len_s < min_s then len_s = min_s end
  reaper.SetMediaItemInfo_Value(it, "D_LENGTH", len_s)
end

local function find_tail_end_by_peaks(take, start_time, max_search_s, thresh_lin, hold_s)
  if not take or reaper.TakeIsMIDI(take) then return nil end

  local numch = 2 -- robust for stereo
  local hold_frames = math.max(1, math.ceil(hold_s * PEAKRATE))
  local max_frames  = math.max(1, math.ceil(max_search_s * PEAKRATE))
  local chunk_frames = 2000

  local heard_signal = false
  local silent_run = 0
  local first_silent_frame = nil
  local fetched = 0

  while fetched < max_frames do
    local want = math.min(chunk_frames, max_frames - fetched)
    local block_sz = want * numch
    local buf = reaper.new_array(block_sz * 2)
    local t0 = start_time + (fetched / PEAKRATE)

    local ret = reaper.GetMediaItemTake_Peaks(take, PEAKRATE, t0, numch, want, 0, buf)
    local got = band20(ret)
    if not got or got <= 0 then break end

    for frame=0,got-1 do
      local max_abs = 0.0
      for ch=0,numch-1 do
        local i_max = frame*numch + ch + 1
        local i_min = block_sz + frame*numch + ch + 1
        local v1 = math.abs(buf[i_max] or 0.0)
        local v2 = math.abs(buf[i_min] or 0.0)
        local v = (v1 > v2) and v1 or v2
        if v > max_abs then max_abs = v end
      end

      if max_abs >= thresh_lin then
        heard_signal = true
        silent_run = 0
        first_silent_frame = nil
      else
        if heard_signal then
          silent_run = silent_run + 1
          if silent_run == 1 then
            first_silent_frame = fetched + frame
          end
          if silent_run >= hold_frames then
            local end_frame = first_silent_frame -- start of silence run
            return start_time + (end_frame / PEAKRATE)
          end
        end
      end
    end

    fetched = fetched + got
    if got < want then break end
  end

  return nil
end

-- =========================
-- Main
-- =========================
local function main()
  local items = get_sel_items_sorted()
  if #items < 1 then return end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local gap_s = GAP_MS/1000.0

  -- 1) Extend all but last to next start
  for i=1,#items-1 do
    local it  = items[i].item
    local pos = items[i].pos
    local next_pos = items[i+1].pos
    set_item_len(it, (next_pos - gap_s) - pos)
  end

  -- 2) Tail-detect last
  if EXTEND_LAST and #items >= 1 then
    local last = items[#items].item
    local pos  = items[#items].pos

    if DISABLE_LOOP_SOURCE_LAST then
      reaper.SetMediaItemInfo_Value(last, "B_LOOPSRC", 0)
    end

    local take = reaper.GetActiveTake(last)
    local thresh_lin = db_to_lin(SILENCE_DB)
    local hold_s = HOLD_MS/1000.0
    local max_search_s = LAST_MAX_SEARCH_MS/1000.0

    local end_t = find_tail_end_by_peaks(take, pos, max_search_s, thresh_lin, hold_s)
    if end_t and end_t > pos then
      set_item_len(last, end_t - pos)
    end
  end

  reaper.UpdateArrange()
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("IFLSWB PostFix: Extend + TailDetect last", -1)
end

main()
