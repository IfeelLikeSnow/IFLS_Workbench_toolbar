-- @description IFLS Workbench: Trim tails of selected items (AudioAccessor)
-- @author IFLS / DF95
-- @version 0.7.6
-- @about
--   Trims trailing silence on selected audio items using Take AudioAccessor sampling.
--   Designed to be used after Smart Slice (to shorten overly long tails).
--
--   Settings are stored per-project in ExtState:
--     Section: IFLS_SLICING
--     Keys: TAILTRIM_DB, TAILTRIM_PAD_MS, TAILTRIM_WIN_MS, TAILTRIM_MAXSCAN_S
--
-- @changelog
--   + Initial release (integrates with Smart Slice workflow)

local r = reaper

local function get_ext(key, default)
  local _, v = r.GetProjExtState(0, "IFLS_SLICING", key)
  if v == nil or v == "" then return default end
  return v
end

local function set_ext(key, value)
  r.SetProjExtState(0, "IFLS_SLICING", key, tostring(value))
end

local function db_to_lin(db) return 10^(db/20) end

local function clamp(x,a,b)
  if x < a then return a end
  if x > b then return b end
  return x
end

local function proj_srate_fallback()
  local sr = r.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  if not sr or sr < 1000 then sr = 48000 end
  return math.floor(sr + 0.5)
end

local function trim_item_tail(item, cfg)
  local take = r.GetActiveTake(item)
  if not take or r.TakeIsMIDI(take) then return false end

  local src = r.GetMediaItemTake_Source(take)
  local ch = r.GetMediaSourceNumChannels(src)
  if not ch or ch < 1 then ch = 2 end

  local accessor = r.CreateTakeAudioAccessor(take)
  if not accessor then return false end

  local a0 = r.GetAudioAccessorStartTime(accessor)
  local a1 = r.GetAudioAccessorEndTime(accessor)

  local item_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local item_len = r.GetMediaItemInfo_Value(item, "D_LENGTH")

  local sr = r.GetMediaSourceSampleRate(src)
  if not sr or sr < 1000 then sr = proj_srate_fallback() end
  sr = math.floor(sr + 0.5)

  local thr = db_to_lin(cfg.thresh_db)
  local pad = cfg.pad_ms / 1000.0
  local win = cfg.win_ms / 1000.0
  local maxscan = cfg.maxscan_s
  local min_len = cfg.min_len_ms / 1000.0

  local scan_end = a1
  local scan_start = math.max(a0, a1 - maxscan)

  if scan_end <= scan_start + win then
    r.DestroyAudioAccessor(accessor)
    return false
  end

  local ns = math.max(1, math.floor(win * sr))
  local buf = r.new_array(ns * ch)

  local function window_maxabs(t0)
    buf.clear()
    local rv = r.GetAudioAccessorSamples(accessor, sr, ch, t0, ns, buf)
    if rv <= 0 then return 0 end
    local m = 0
    for i = 1, ns*ch do
      local v = buf[i]
      if v < 0 then v = -v end
      if v > m then m = v end
    end
    return m
  end

  local last_audio_t = nil
  local t = scan_end - win
  while t >= scan_start do
    if window_maxabs(t) > thr then
      last_audio_t = t + win
      break
    end
    t = t - win
  end

  r.DestroyAudioAccessor(accessor)

  if not last_audio_t then return false end

  local new_len = (last_audio_t - item_pos) + pad
  new_len = clamp(new_len, min_len, item_len)

  if new_len < item_len - 0.0005 then
    r.SetMediaItemInfo_Value(item, "D_LENGTH", new_len)
    return true
  end
  return false
end

local function parse_num(v, default)
  v = tostring(v or ""):gsub(",", ".")
  local n = tonumber(v)
  if not n then return default end
  return n
end

local function get_cfg()
  local cfg = {}
  cfg.thresh_db = parse_num(get_ext("TAILTRIM_DB", "-50"), -50)
  cfg.pad_ms    = parse_num(get_ext("TAILTRIM_PAD_MS", "5"), 5)
  cfg.win_ms    = parse_num(get_ext("TAILTRIM_WIN_MS", "10"), 10)
  cfg.maxscan_s = parse_num(get_ext("TAILTRIM_MAXSCAN_S", "12"), 12)
  cfg.min_len_ms = 15
  return cfg
end

local function prompt_cfg(cfg)
  local ok, out = r.GetUserInputs(
    "IFLS Tail Trim (selected items)",
    4,
    "Threshold dB,Pad ms,Window ms,Max scan seconds",
    string.format("%.1f,%.1f,%.1f,%.1f", cfg.thresh_db, cfg.pad_ms, cfg.win_ms, cfg.maxscan_s)
  )
  if not ok then return nil end
  local a,b,c,d = out:match("^%s*([^,]+),%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$")
  if not a then return nil end
  cfg.thresh_db = parse_num(a, cfg.thresh_db)
  cfg.pad_ms    = parse_num(b, cfg.pad_ms)
  cfg.win_ms    = parse_num(c, cfg.win_ms)
  cfg.maxscan_s = parse_num(d, cfg.maxscan_s)

  set_ext("TAILTRIM_DB", cfg.thresh_db)
  set_ext("TAILTRIM_PAD_MS", cfg.pad_ms)
  set_ext("TAILTRIM_WIN_MS", cfg.win_ms)
  set_ext("TAILTRIM_MAXSCAN_S", cfg.maxscan_s)
  return cfg
end

local function main()
  local n = r.CountSelectedMediaItems(0)
  if n == 0 then
    r.MB("No selected items.\n\nSelect sliced items and run again.", "IFLS Tail Trim", 0)
    return
  end

  local cfg = get_cfg()  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local changed = 0
  for i = 0, n-1 do
    local it = r.GetSelectedMediaItem(0, i)
    if it and trim_item_tail(it, cfg) then changed = changed + 1 end
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS: Trim tails of selected items ("..changed.." changed)", -1)
end

main()
