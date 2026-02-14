-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_Clickify_SelectedItems.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Clickify selected slices (turn each into a click/pop)
-- @version 0.7.6
-- @author IFLS
-- @about
--   Post-process after Smart Slice:
--   For each selected item, find the maximum peak position (AudioAccessor scan),
--   then trim the item to a micro-window around that peak (e.g. 2ms pre, 12ms post).
--   This turns normal slices into "clicks & pops" style micro-samples.
--   Uses CreateTakeAudioAccessor / GetAudioAccessorSamples (REAPER ReaScript API).
--   See official ReaScript API docs for AudioAccessor functions.

--

local r = reaper

local EXT_NS  = "IFLS_WORKBENCH_SLICING"
local EXT_KEY = "CLICKIFY_SETTINGS" -- pre_ms,post_ms,thr_db,max_scan_s

local function db_to_lin(db) return 10^(db/20) end

local function parse_nums(csv)
  local t = {}
  for tok in (csv or ""):gmatch("([^,]+)") do
    t[#t+1] = tonumber(tok)
  end
  return t
end

local function load_settings()
  local st = {pre_ms=2.0, post_ms=12.0, thr_db=-40.0, max_scan_s=10.0}
  local s = r.GetExtState(EXT_NS, EXT_KEY)
  if s and s ~= "" then
    local v = parse_nums(s)
    if #v >= 4 then
      st.pre_ms     = v[1] or st.pre_ms
      st.post_ms    = v[2] or st.post_ms
      st.thr_db     = v[3] or st.thr_db
      st.max_scan_s = v[4] or st.max_scan_s
    end
  end
  return st
end

local function save_settings(st)
  r.SetExtState(EXT_NS, EXT_KEY, string.format("%.6f,%.6f,%.6f,%.6f", st.pre_ms, st.post_ms, st.thr_db, st.max_scan_s), true)
end

local function prompt_settings(st)
  local ok, csv = r.GetUserInputs(
    "IFLS Clickify (Clicks & Pops)",
    4,
    "Pre ms,Post ms,Peak threshold dB,Max scan (s)",
    string.format("%.1f,%.1f,%.1f,%.1f", st.pre_ms, st.post_ms, st.thr_db, st.max_scan_s)
  )
  if not ok then return nil end
  local v = parse_nums(csv)
  if #v < 4 then return nil end
  st.pre_ms     = v[1] or st.pre_ms
  st.post_ms    = v[2] or st.post_ms
  st.thr_db     = v[3] or st.thr_db
  st.max_scan_s = v[4] or st.max_scan_s
  save_settings(st)
  return st
end

local function get_proj_srate_fallback()
  local sr = r.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  if not sr or sr < 1000 then sr = 48000 end
  return math.floor(sr + 0.5)
end

local function find_peak_time_in_item(item, st)
  local take = r.GetActiveTake(item)
  if not take or r.TakeIsMIDI(take) then return nil end

  local src = r.GetMediaItemTake_Source(take)
  local ch  = r.GetMediaSourceNumChannels(src)
  if not ch or ch < 1 then ch = 2 end

  local accessor = r.CreateTakeAudioAccessor(take)
  if not accessor then return nil end

  local a0 = r.GetAudioAccessorStartTime(accessor)
  local a1 = r.GetAudioAccessorEndTime(accessor)

  local item_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local is_project_time = (math.abs(a0 - item_pos) < 0.05)

  local sr = r.GetMediaSourceSampleRate(src)
  if not sr or sr < 1000 then sr = get_proj_srate_fallback() end
  sr = math.floor(sr + 0.5)

  local max_scan = math.min(st.max_scan_s, (a1 - a0))
  local scan_start = a0
  local scan_end   = a0 + max_scan

  local win_s = 0.02 -- 20ms windows
  local ns = math.max(1, math.floor(win_s * sr))
  local buf = r.new_array(ns * ch)

  local best_t = nil
  local best_v = 0
  local thr = db_to_lin(st.thr_db)

  local t = scan_start
  while t < scan_end do
    buf.clear()
    local rv = r.GetAudioAccessorSamples(accessor, sr, ch, t, ns, buf)
    if rv > 0 then
      for i=1, ns*ch do
        local v = buf[i]
        if v < 0 then v = -v end
        if v > best_v then
          best_v = v
          local sample_index = math.floor((i-1) / ch)
          best_t = t + (sample_index / sr)
        end
      end
    end
    t = t + win_s
  end

  r.DestroyAudioAccessor(accessor)

  if not best_t or best_v < thr then
    return nil
  end

  if is_project_time then
    return best_t
  else
    return item_pos + (best_t - a0)
  end
end

local function clickify_item(item, st)
  local peak_t = find_peak_time_in_item(item, st)
  if not peak_t then return false end

  local item_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  local item_end = item_pos + item_len

  local pre  = st.pre_ms / 1000.0
  local post = st.post_ms / 1000.0

  local new_pos = math.max(item_pos, peak_t - pre)
  local new_end = math.min(item_end, peak_t + post)
  local new_len = math.max(0.001, new_end - new_pos)

  r.SetMediaItemInfo_Value(item, "D_POSITION", new_pos)
  r.SetMediaItemInfo_Value(item, "D_LENGTH", new_len)

  r.SetMediaItemInfo_Value(item, "D_FADEINLEN", math.min(0.003, new_len*0.4))
  r.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", math.min(0.003, new_len*0.4))
  return true
end

local function main()
  local st = load_settings()
  st = prompt_settings(st)
  if not st then return end

  local n = r.CountSelectedMediaItems(0)
  if n == 0 then
    r.MB("No selected items.\n\nTip: run 'Select items on IFLS Slices tracks' first.", "IFLS Clickify", 0)
    return
  end

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local changed = 0
  for i=0,n-1 do
    local it = r.GetSelectedMediaItem(0,i)
    if it and clickify_item(it, st) then
      changed = changed + 1
    end
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS: Clickify slices ("..changed.." changed)", -1)
end

main()
