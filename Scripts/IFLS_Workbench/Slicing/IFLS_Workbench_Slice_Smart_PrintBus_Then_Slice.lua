-- @description IFLS Workbench - Smart Slice (Print bus -> Slice -> TailTrim -> Spread gaps)
-- @author IFLS / DF95
-- @version 0.7.7
-- @changelog
--   + Multi-stem aware: creates/uses per-stem "IFLS Slices" tracks (multi-track routing)
--   + Optional TailTrim (AudioAccessor) to remove trailing silence on slices
--   + Optional Spread: arrange slices sequentially with user-configurable gaps (for delay/reverb tails)
--   + Keeps FXChains dropdown workflow: slices remain on "IFLS Slices" tracks
--
-- @about
--   1) Select track(s) you want to print/render to stems.
--   2) Run this script.
--   It renders selected tracks to stem tracks (mono/stereo auto-detect), mutes originals,
--   moves the rendered items to "IFLS Slices" tracks, then slices, trims tails, and spreads
--   the slices with gaps so FX tails can ring out.

local r = reaper

-- ---------- helpers ----------
local function join(a,b)
  local sep = package.config:sub(1,1)
  if a:sub(-1) == sep then return a..b end
  return a..sep..b
end

local function parse_num(v, default)
  v = tostring(v or ""):gsub(",", ".")
  local n = tonumber(v)
  if not n then return default end
  return n
end

local function parse_bool(v, default)
  if v == nil or v == "" then return default end
  v = tostring(v):lower()
  if v == "1" or v == "true" or v == "yes" then return true end
  if v == "0" or v == "false" or v == "no" then return false end
  return default
end

local function get_ext(key, default)
  local _, v = r.GetProjExtState(0, "IFLS_SLICING", key)
  if v == nil or v == "" then return default end
  return v
end

local function set_ext(key, value)
  r.SetProjExtState(0, "IFLS_SLICING", key, tostring(value))
end

local function db_to_lin(db) return 10^(db/20) end
local function clamp(x,a,b) if x<a then return a elseif x>b then return b else return x end end

local function try_main_cmd(cmd)
  if cmd and cmd > 0 then r.Main_OnCommand(cmd, 0); return true end
  return false
end

local function try_named_cmd(named)
  local cmd = r.NamedCommandLookup(named)
  if cmd and cmd > 0 then r.Main_OnCommand(cmd, 0); return true end
  return false
end

local function unselect_all_tracks() r.Main_OnCommand(40297,0) end
local function unselect_all_items() r.Main_OnCommand(40289,0) end

local function get_selected_tracks()
  local t = {}
  local n = r.CountSelectedTracks(0)
  for i=0,n-1 do t[#t+1] = r.GetSelectedTrack(0,i) end
  return t
end

local function get_track_name(tr)
  local _, name = r.GetTrackName(tr)
  return name or ""
end

local function set_track_name(tr, name)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
end

local function get_track_guid_set()
  local set = {}
  local n = r.CountTracks(0)
  for i=0,n-1 do
    local tr = r.GetTrack(0,i)
    set[r.GetTrackGUID(tr)] = true
  end
  return set
end

local function get_new_tracks_since(before_set)
  local out = {}
  local n = r.CountTracks(0)
  for i=0,n-1 do
    local tr = r.GetTrack(0,i)
    local g = r.GetTrackGUID(tr)
    if not before_set[g] then
      out[#out+1] = tr
    end
  end
  -- sort by track index
  table.sort(out, function(a,b)
    local ia = r.GetMediaTrackInfo_Value(a, "IP_TRACKNUMBER")
    local ib = r.GetMediaTrackInfo_Value(b, "IP_TRACKNUMBER")
    return ia < ib
  end)
  return out
end

local function is_all_sources_mono(tracks)
  for _,tr in ipairs(tracks) do
    local item_cnt = r.CountTrackMediaItems(tr)
    for i=0,item_cnt-1 do
      local item = r.GetTrackMediaItem(tr,i)
      local take = r.GetActiveTake(item)
      if take then
        local src = r.GetMediaItemTake_Source(take)
        if src then
          local ch = r.GetMediaSourceNumChannels(src)
          if ch and ch > 1 then return false end
        end
      end
    end
  end
  return true
end

local function select_only_track(tr)
  unselect_all_tracks()
  r.SetTrackSelected(tr, true)
end

local function select_only_items_on_track(tr)
  unselect_all_items()
  local cnt = r.CountTrackMediaItems(tr)
  for i=0,cnt-1 do
    r.SetMediaItemSelected(r.GetTrackMediaItem(tr,i), true)
  end
end

local function move_items(from_tr, to_tr)
  local cnt = r.CountTrackMediaItems(from_tr)
  for i=cnt-1,0,-1 do
    local it = r.GetTrackMediaItem(from_tr, i)
    r.MoveMediaItemToTrack(it, to_tr)
  end
end

local function compute_peaks_metrics(item)
  local take = r.GetActiveTake(item)
  if not take or not r.new_array or not r.APIExists("GetMediaItemTake_Peaks") then return nil end

  local len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  local start = 0.0
  local win = math.min(len, 0.6) -- first 600ms
  local peakrate = 2000 -- 2kHz peak sampling
  local ch = 1
  local samples = math.max(64, math.floor(win * peakrate))
  local want_extra = 0
  local buf = r.new_array(samples * ch)

  local retval = r.GetMediaItemTake_Peaks(take, peakrate, start, ch, samples, want_extra, buf)
  if not retval or retval <= 0 then return nil end

  local maxv, sumsq, trans = 0, 0, 0
  local prev = 0
  for i=1,samples do
    local v = buf[i]
    if v < 0 then v = -v end
    if v > maxv then maxv = v end
    sumsq = sumsq + (v*v)
    if i > 1 then
      local dv = v - prev
      if dv > 0.15 then trans = trans + 1 end
    end
    prev = v
  end
  local rms = math.sqrt(sumsq / samples)
  local crest = (rms > 1e-9) and (maxv / rms) or 0
  return {crest=crest, trans=trans, max=maxv, rms=rms}
end

local function is_percussive_track(tr)
  local cnt = r.CountTrackMediaItems(tr)
  if cnt == 0 then return false end
  local it = r.GetTrackMediaItem(tr, 0)
  local m = compute_peaks_metrics(it)
  if not m then return false end
  -- heuristic: crest + transient-ish count
  if m.crest >= 3.0 and m.trans >= 8 then return true end
  if m.max >= 0.6 and m.trans >= 6 then return true end
  return false
end

-- ---------- Tail trim (AudioAccessor) ----------
local function proj_srate_fallback()
  local sr = r.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  if not sr or sr < 1000 then sr = 48000 end
  return math.floor(sr + 0.5)
end

local function tailtrim_cfg()
  return {
    enable = parse_bool(get_ext("TAILTRIM_ENABLE", "1"), true),
    thresh_db = parse_num(get_ext("TAILTRIM_DB", "-50"), -50),
    pad_ms = parse_num(get_ext("TAILTRIM_PAD_MS", "5"), 5),
    win_ms = parse_num(get_ext("TAILTRIM_WIN_MS", "10"), 10),
    maxscan_s = parse_num(get_ext("TAILTRIM_MAXSCAN_S", "12"), 12),
    min_len_ms = 15,
  }
end

local function tailtrim_prompt(cfg)
  local ok, out = r.GetUserInputs(
    "IFLS TailTrim",
    4,
    "Threshold dB,Pad ms,Window ms,Max scan seconds",
    string.format("%.1f,%.1f,%.1f,%.1f", cfg.thresh_db, cfg.pad_ms, cfg.win_ms, cfg.maxscan_s)
  )
  if not ok then return cfg end
  local a,b,c,d = out:match("^%s*([^,]+),%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$")
  if a then
    cfg.thresh_db = parse_num(a, cfg.thresh_db)
    cfg.pad_ms = parse_num(b, cfg.pad_ms)
    cfg.win_ms = parse_num(c, cfg.win_ms)
    cfg.maxscan_s = parse_num(d, cfg.maxscan_s)
    set_ext("TAILTRIM_DB", cfg.thresh_db)
    set_ext("TAILTRIM_PAD_MS", cfg.pad_ms)
    set_ext("TAILTRIM_WIN_MS", cfg.win_ms)
    set_ext("TAILTRIM_MAXSCAN_S", cfg.maxscan_s)
  end
  return cfg
end

local function tailtrim_selected_items(cfg)
  if not cfg.enable then return 0 end
  local n = r.CountSelectedMediaItems(0)
  if n == 0 then return 0 end

  local thr = db_to_lin(cfg.thresh_db)
  local pad = cfg.pad_ms / 1000.0
  local win = cfg.win_ms / 1000.0
  local maxscan = cfg.maxscan_s
  local min_len = cfg.min_len_ms / 1000.0

  local changed = 0

  for i=0,n-1 do
    local item = r.GetSelectedMediaItem(0,i)
    local take = item and r.GetActiveTake(item) or nil
    if take and not r.TakeIsMIDI(take) then
      local src = r.GetMediaItemTake_Source(take)
      local ch = r.GetMediaSourceNumChannels(src)
      if not ch or ch < 1 then ch = 2 end

      local accessor = r.CreateTakeAudioAccessor(take)
      if accessor then
        local a0 = r.GetAudioAccessorStartTime(accessor)
        local a1 = r.GetAudioAccessorEndTime(accessor)

        local item_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
        local item_len = r.GetMediaItemInfo_Value(item, "D_LENGTH")

        local sr = r.GetMediaSourceSampleRate(src)
        if not sr or sr < 1000 then sr = proj_srate_fallback() end
        sr = math.floor(sr + 0.5)

        local scan_end = a1
        local scan_start = math.max(a0, a1 - maxscan)

        if scan_end > scan_start + win and r.new_array then
          local ns = math.max(1, math.floor(win * sr))
          local buf = r.new_array(ns * ch)

          local function window_maxabs(t0)
            buf.clear()
            local rv = r.GetAudioAccessorSamples(accessor, sr, ch, t0, ns, buf)
            if rv <= 0 then return 0 end
            local m = 0
            for j=1,ns*ch do
              local v = buf[j]
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

          if last_audio_t then
            local new_len = (last_audio_t - item_pos) + pad
            new_len = clamp(new_len, min_len, item_len)
            if new_len < item_len - 0.0005 then
              r.SetMediaItemInfo_Value(item, "D_LENGTH", new_len)
              changed = changed + 1
            end
          end
        end

        r.DestroyAudioAccessor(accessor)
      end
    end
  end

  return changed
end

-- ---------- Spread ----------
local function spread_cfg()
  return {
    enable = parse_bool(get_ext("SPREAD_ENABLE", "1"), true),
    min_s = parse_num(get_ext("SPREAD_MIN_S", "1.0"), 1.0),
    max_s = parse_num(get_ext("SPREAD_MAX_S", "5.0"), 5.0),
    random = parse_bool(get_ext("SPREAD_RANDOM", "1"), true),
    prompt = parse_bool(get_ext("SPREAD_PROMPT", "1"), true),
  }
end

local function spread_prompt(cfg)
  local ok, out = r.GetUserInputs(
    "IFLS Spread (gaps for FX tails)",
    3,
    "Gap min (s),Gap max (s),Random 1/0",
    string.format("%.3f,%.3f,%d", cfg.min_s, cfg.max_s, cfg.random and 1 or 0)
  )
  if not ok then return cfg end
  local a,b,c = out:match("^%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$")
  if a then
    cfg.min_s = math.max(0, parse_num(a, cfg.min_s))
    cfg.max_s = math.max(cfg.min_s, parse_num(b, cfg.max_s))
    cfg.random = (parse_num(c, cfg.random and 1 or 0) ~= 0)
    set_ext("SPREAD_MIN_S", cfg.min_s)
    set_ext("SPREAD_MAX_S", cfg.max_s)
    set_ext("SPREAD_RANDOM", cfg.random and 1 or 0)
  end
  return cfg
end

local function spread_selected_items(cfg)
  if not cfg.enable then return end
  local n = r.CountSelectedMediaItems(0)
  if n < 2 then return end

  local items = {}
  for i=0,n-1 do
    local it = r.GetSelectedMediaItem(0,i)
    local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
    local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
    items[#items+1] = {it=it, pos=pos, len=len}
  end
  table.sort(items, function(a,b) return a.pos < b.pos end)

  math.randomseed(tonumber((tostring(r.time_precise()):gsub("%D","")) or os.time()))

  local t = r.GetCursorPosition()
  for _,x in ipairs(items) do
    r.SetMediaItemInfo_Value(x.it, "D_POSITION", t)
    local gap = cfg.min_s
    if cfg.random and cfg.max_s > cfg.min_s then
      gap = cfg.min_s + (cfg.max_s - cfg.min_s) * math.random()
    end
    t = t + x.len + gap
  end
end

-- ---------- ZeroCross post-fix ----------
local function maybe_zerocross_postfix()
  local _, v = r.GetProjExtState(0, "IFLS_SLICING", "ZC_RESPECT")
  if v ~= "1" then return end

  local rp = r.GetResourcePath()
  local p = join(join(join(rp,"Scripts"),"IFLS_Workbench"), join("Slicing","IFLS_Workbench_Slicing_ZeroCross_PostFix.lua"))
  local f = io.open(p, "r")
  if f then f:close(); dofile(p) end
end

-- ---------- main workflow ----------
local function render_to_stems(all_mono)
  -- 40788: Render selected tracks to mono stem tracks (and mute originals)
  -- 40789: Render selected tracks to stereo stem tracks (and mute originals)
  if all_mono then
    try_main_cmd(40788)
  else
    try_main_cmd(40789)
  end
end

local function insert_slices_track_before(stem_tr, name)
  local idx = math.floor(r.GetMediaTrackInfo_Value(stem_tr, "IP_TRACKNUMBER")) - 1 -- to 0-based
  if idx < 0 then idx = 0 end
  r.InsertTrackAtIndex(idx, true)
  local new_tr = r.GetTrack(0, idx)
  set_track_name(new_tr, name)
  return new_tr
end

local function process_stem(stem_tr, slices_tr, spread, tailtrim)
  -- move items
  move_items(stem_tr, slices_tr)

  -- slice
  select_only_items_on_track(slices_tr)

  if is_percussive_track(slices_tr) then
    try_named_cmd("_XENAKIOS_SPLIT_ITEMSATRANSIENTS") -- SWS
  end
  -- Always run remove-silence (uses last-used settings)
  try_main_cmd(40315) -- Item: Auto trim/split items (remove silence)...

  -- Post
  maybe_zerocross_postfix()

  -- Tail trim then spread (keeps items selected)
  local changed = tailtrim_selected_items(tailtrim)
  spread_selected_items(spread)

  -- keep stem muted (stem track now empty, but mute anyway)
  r.SetMediaTrackInfo_Value(stem_tr, "B_MUTE", 1)
end

local function main()
  local sel = get_selected_tracks()
  if #sel == 0 then
    r.MB("Select one or more tracks to print/slice.", "IFLS Smart Slice", 0)
    return
  end

  local all_mono = is_all_sources_mono(sel)
  local before = get_track_guid_set()

  local spread = spread_cfg()
  local tailtrim = tailtrim_cfg()

  -- Optional: prompt each run for spread (and tailtrim via a separate settings script)
  if spread.enable and spread.prompt then
    spread = spread_prompt(spread)
  end

  -- render
  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  render_to_stems(all_mono)

  local stems = get_new_tracks_since(before)
  if #stems == 0 then
    r.PreventUIRefresh(-1)
    r.Undo_EndBlock("IFLS Smart Slice (no stems created)", -1)
    r.MB("No stem tracks were created.\n\nCheck your time selection / render settings, and try again.", "IFLS Smart Slice", 0)
    return
  end

  -- Insert slices tracks in reverse order so indices don't shift
  local pairs = {}
  for i=#stems,1,-1 do
    local stem_tr = stems[i]
    local stem_name = get_track_name(stem_tr)
    local slices_name = "IFLS Slices"
    if #stems > 1 then
      slices_name = "IFLS Slices - " .. (stem_name ~= "" and stem_name or tostring(i))
    end
    local slices_tr = insert_slices_track_before(stem_tr, slices_name)
    pairs[#pairs+1] = {stem=stem_tr, slices=slices_tr}
  end
  -- process in forward order for predictable selection, etc.
  for i=#pairs,1,-1 do
    local p = pairs[i]
    process_stem(p.stem, p.slices, spread, tailtrim)
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS Smart Slice (slice + tailtrim + spread)", -1)
end

main()
