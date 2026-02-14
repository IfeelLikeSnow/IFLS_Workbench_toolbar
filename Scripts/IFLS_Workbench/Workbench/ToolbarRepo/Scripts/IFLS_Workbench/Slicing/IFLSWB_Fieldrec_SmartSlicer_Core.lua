-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Slicing/IFLSWB_Fieldrec_SmartSlicer_Core.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLSWB Fieldrec SmartSlicer Core (v3) - iterative threshold calibration + hysteresis/backtrack + HQ zero-cross snap
-- @version 3.0.0
-- @author IFLS Workbench (generated)
-- @about
--   Core library used by:
--     - IFLS_Workbench_Fieldrec_SmartSlice_Hits.lua
--     - IFLS_Workbench_Fieldrec_SmartSlice_Textures.lua
--     - IFLS_Workbench_Fieldrec_SmartSlice_ModeMenu.lua
--   Improvements in v3:
--     1) Iterative threshold calibration (auto) to hit a target onset-count range
--     2) Hysteresis + backtracking in onset detection (less retrigger, earlier onsets)
--     3) HQ Mode (toggle): snap split points to nearest zero crossing (audio-accessor)
--   Uses:
--     - GetMediaItemTake_Peaks (fast envelope) + CreateTakeAudioAccessor/GetAudioAccessorSamples (HQ snap)
--   Safety:
--     - Works on selected items (or all items on selected tracks if none selected).
--     - Non-destructive-ish: splits items but does not glue/render. Use Undo if needed.
--   Notes:
--     - HQ zero-cross snap is heavier. It only runs on split points and reads a tiny window around them.

--
--
--
--
--

local M = {}

-- ---------- small utils ----------
local function clamp(x, a, b) if x < a then return a elseif x > b then return b else return x end end
local function db_to_amp(db) return 10^(db/20) end
local function amp_to_db(a) if a <= 1e-20 then return -200 end return 20*math.log(a,10) end

local function msg(s) reaper.ShowConsoleMsg(tostring(s).."\n") end

local function get_project_samplerate_fallback(take)
  -- Prefer source sample-rate if available, else project rate, else 44100.
  local src = reaper.GetMediaItemTake_Source(take)
  if src and reaper.GetMediaSourceSampleRate then
    local sr = reaper.GetMediaSourceSampleRate(src)
    if sr and sr > 0 then return sr end
  end
  local proj_sr = 0
  if reaper.GetSetProjectInfo then
    proj_sr = reaper.GetSetProjectInfo(0, "PROJECT_SRATE", 0, false)
  end
  if proj_sr and proj_sr > 0 then return proj_sr end
  return 44100
end

local function ensure_gfx()
  if not gfx or not gfx.init then return false end
  if gfx.w == 0 then gfx.init("IFLSWB SmartSlicer", 0, 0, 0, 0, 0) end
  return true
end

local function ext_get(section, key, default)
  local v = reaper.GetExtState(section, key)
  if v == nil or v == "" then return default end
  return v
end

local function ext_set(section, key, value)
  reaper.SetExtState(section, key, tostring(value), true)
end

-- ---------- selection helpers ----------
local function get_target_items()
  local items = {}
  local sel = reaper.CountSelectedMediaItems(0)
  if sel > 0 then
    for i=0, sel-1 do items[#items+1] = reaper.GetSelectedMediaItem(0, i) end
    return items
  end
  local trSel = reaper.CountSelectedTracks(0)
  if trSel == 0 then return items end
  for t=0, trSel-1 do
    local tr = reaper.GetSelectedTrack(0, t)
    local n = reaper.CountTrackMediaItems(tr)
    for i=0, n-1 do items[#items+1] = reaper.GetTrackMediaItem(tr, i) end
  end
  return items
end

-- ---------- envelope via peaks ----------
local function get_take_envelope(take, peakrate, start_sec, dur_sec, numch)
  local ns = math.max(1, math.floor(dur_sec * peakrate + 0.5))
  local buf = reaper.new_array(ns * numch * 2) -- max+min blocks
  buf.clear()
  local rv = reaper.GetMediaItemTake_Peaks(take, peakrate, start_sec, numch, ns, 0, buf)
  local returned = rv & 0xFFFFF
  if returned <= 0 then return nil end

  local maxBlock = {}
  local minBlock = {}
  -- layout: max interleaved [ch][sample], then min interleaved
  for s=0, returned-1 do
    local peak = 0
    for ch=0, numch-1 do
      local mx = buf[(ch + s*numch)]
      local mn = buf[(ch + s*numch) + (returned*numch)]
      local a = math.max(math.abs(mx), math.abs(mn))
      if a > peak then peak = a end
    end
    maxBlock[s+1] = peak
  end
  return {peakrate = peakrate, start = start_sec, dur = dur_sec, a = maxBlock}
end

local function compute_noise_floor_db(env, pct)
  pct = pct or 0.25
  local a = env.a
  local n = #a
  if n == 0 then return -120 end
  local tmp = {}
  for i=1,n do tmp[i] = a[i] end
  table.sort(tmp)
  local k = clamp(math.floor(n*pct), 1, n)
  local mean = 0
  for i=1,k do mean = mean + tmp[i] end
  mean = mean / k
  return amp_to_db(mean)
end

local function smooth_env(env, win)
  win = win or 5
  local a = env.a
  local n = #a
  if n <= 2 then return env end
  local out = {}
  local half = math.floor(win/2)
  for i=1,n do
    local s = 0
    local c = 0
    for j=i-half, i+half do
      if j>=1 and j<=n then s=s+a[j]; c=c+1 end
    end
    out[i] = s / math.max(1,c)
  end
  return {peakrate=env.peakrate, start=env.start, dur=env.dur, a=out}
end

-- ---------- onset detection (hysteresis + backtrack) ----------
local function detect_onsets(env, cfg)
  local a = env.a
  local pr = env.peakrate
  local n = #a
  if n == 0 then return {} end

  local noise_db = compute_noise_floor_db(env, cfg.noise_pct)
  local thr_abs = db_to_amp(cfg.onset_abs_db or (noise_db + 18))
  local thr_rel = db_to_amp(cfg.onset_rel_db or 0) -- optional
  local thr_up = math.max(thr_abs, db_to_amp(noise_db) * thr_rel)

  local hyst_db = cfg.onset_hyst_db or 6.0
  local thr_down = thr_up * db_to_amp(-math.abs(hyst_db))

  local confirm_frames = math.max(1, math.floor((cfg.onset_confirm_ms or 6) * 0.001 * pr + 0.5))
  local release_frames = math.max(1, math.floor((cfg.onset_release_ms or 8) * 0.001 * pr + 0.5))
  local min_gap = math.max(0, math.floor((cfg.min_slice_gap_ms or 18) * 0.001 * pr + 0.5))
  local back_frames = math.max(0, math.floor((cfg.onset_backtrack_ms or 10) * 0.001 * pr + 0.5))
  local back_db = math.abs(cfg.onset_backtrack_db or (hyst_db + 3))
  local thr_bt = thr_up * db_to_amp(-back_db)

  local onsets = {}
  local state = 0 -- 0=waiting, 1=in-event
  local last_onset = -999999

  local i = 1
  while i <= n do
    if state == 0 then
      if a[i] >= thr_up and (i - last_onset) >= min_gap then
        -- confirm
        local ok = true
        for k=1, confirm_frames-1 do
          local ii = i + k
          if ii > n or a[ii] < thr_up then ok = false break end
        end
        if ok then
          -- backtrack to earlier low-energy frame for tighter transient start
          local j = i
          for b=1, back_frames do
            local jj = i - b
            if jj < 1 then break end
            if a[jj] < thr_bt then j = jj + 1; break end
          end
          onsets[#onsets+1] = j
          last_onset = j
          state = 1
          i = i + release_frames
        else
          i = i + 1
        end
      else
        i = i + 1
      end
    else
      -- in-event, wait until we fall below thr_down for a bit (prevents retrigger)
      if a[i] < thr_down then
        local ok = true
        for k=1, release_frames-1 do
          local ii = i + k
          if ii > n then break end
          if a[ii] >= thr_down then ok = false break end
        end
        if ok then
          state = 0
          i = i + release_frames
        else
          i = i + 1
        end
      else
        i = i + 1
      end
    end
  end

  return onsets, noise_db, thr_up, thr_down
end

-- ---------- HQ zero-cross snap (audio accessor) ----------
local function nearest_zero_cross_time(take, t_sec, window_ms)
  if not reaper.CreateTakeAudioAccessor or not reaper.GetAudioAccessorSamples then
    return t_sec, false
  end

  window_ms = window_ms or 6
  local win = math.max(0.001, window_ms * 0.001)
  local sr = get_project_samplerate_fallback(take)
  local ch = 1 -- we scan channel 1 for speed
  local ns = math.max(8, math.floor(2 * win * sr + 0.5))
  local start = t_sec - win
  local acc = reaper.CreateTakeAudioAccessor(take)
  if not acc then return t_sec, false end

  local buf = reaper.new_array(ns * ch)
  buf.clear()
  local got = reaper.GetAudioAccessorSamples(acc, sr, ch, start, ns, buf)
  reaper.DestroyAudioAccessor(acc)
  if not got or got <= 2 then return t_sec, false end

  local center = math.floor(ns/2)
  -- find sign changes (zero-cross) closest to center
  local best_i = nil
  local best_dist = 1e9
  local prev = buf[0]
  for i=1, ns-1 do
    local cur = buf[i]
    if (prev == 0) or (cur == 0) or (prev < 0 and cur > 0) or (prev > 0 and cur < 0) then
      local dist = math.abs(i - center)
      if dist < best_dist then
        best_dist = dist
        best_i = i
        if best_dist == 0 then break end
      end
    end
    prev = cur
  end
  if not best_i then return t_sec, false end

  -- linear interpolation between samples to get closer to true zero (optional)
  local i0 = best_i - 1
  if i0 < 0 then i0 = 0 end
  local s0 = buf[i0]
  local s1 = buf[best_i]
  local frac = 0.0
  if (s1 - s0) ~= 0 then
    frac = clamp((0 - s0) / (s1 - s0), 0, 1)
  end
  local sample_pos = (i0 + frac)
  local snapped = start + (sample_pos / sr)

  return snapped, true
end

local function maybe_snap_zero_cross(take, t, item_start, item_end, cfg, is_end)
  if not cfg.hq_zero_cross then return t end
  local win = is_end and (cfg.hq_end_window_ms or 10) or (cfg.hq_start_window_ms or 6)
  local snapped, ok = nearest_zero_cross_time(take, t, win)
  if not ok then return t end
  -- keep inside boundaries
  snapped = clamp(snapped, item_start, item_end)
  return snapped
end

-- ---------- iterative threshold calibration ----------
local function calibrate_onsets(env, cfg, target_min, target_max, cal)
  if not cal or not cal.enabled then
    local onsets = detect_onsets(env, cfg)
    return cfg.onset_abs_db, onsets
  end

  local abs_db = cfg.onset_abs_db
  local step = cal.step_db or 2.5
  local iters = cal.max_iters or 8
  local last_onsets = {}
  for iter=1, iters do
    cfg.onset_abs_db = abs_db
    local onsets = detect_onsets(env, cfg)
    last_onsets = onsets
    if #onsets > target_max then
      abs_db = abs_db + step
    elseif #onsets < target_min then
      abs_db = abs_db - step
    else
      break
    end
  end
  cfg.onset_abs_db = abs_db
  return abs_db, last_onsets
end

-- ---------- tail detection (peak-based â€œuntil silenceâ€) ----------
local function detect_tail_end_time(env, start_idx, cfg)
  local a = env.a
  local pr = env.peakrate
  local n = #a
  if start_idx > n then return n end

  local silence_db = cfg.tail_silence_db or -55
  local silence_amp = db_to_amp(silence_db)
  local need_ms = cfg.tail_silence_hold_ms or 80
  local need = math.max(1, math.floor(need_ms * 0.001 * pr + 0.5))

  local max_len_s = cfg.max_tail_s or 12.0
  local max_len = math.max(1, math.floor(max_len_s * pr + 0.5))
  local stop = math.min(n, start_idx + max_len)

  local run = 0
  for i=start_idx, stop do
    if a[i] <= silence_amp then
      run = run + 1
      if run >= need then
        return i - need + 1
      end
    else
      run = 0
    end
  end
  return stop
end

-- ---------- segment classification (hit vs texture) ----------
local function classify_segment(env, i1, i2, cfg_auto)
  local a = env.a
  local pr = env.peakrate
  local n = #a
  i1 = clamp(i1, 1, n)
  i2 = clamp(i2, 1, n)
  if i2 <= i1 then return "hits" end

  local peak = 0
  local mean = 0
  local m = 0
  for i=i1, i2 do
    local v = a[i]
    if v > peak then peak = v end
    mean = mean + v
    m = m + 1
  end
  mean = mean / math.max(1,m)

  -- "sustain-ness": % of frames above sustain_ratio * peak
  local ratio = cfg_auto.texture_sustain_ratio or 0.18
  local thr = peak * ratio
  local sustain = 0
  for i=i1, i2 do
    if a[i] >= thr then sustain = sustain + 1 end
  end
  local sustain_pct = sustain / math.max(1,m)

  -- onset density: rough measure
  local dur_s = (i2 - i1) / pr
  local density = (sustain_pct / math.max(0.05, dur_s))

  if sustain_pct >= (cfg_auto.texture_sustain_pct or 0.32) and dur_s >= (cfg_auto.texture_min_len_s or 2.0) then
    return "textures"
  end

  -- if lots of sustain for its length, also texture
  if density >= (cfg_auto.texture_density or 0.22) and dur_s >= 1.0 then
    return "textures"
  end

  return "hits"
end

-- ---------- splitting helpers ----------
local function split_item_at_time(item, t)
  return reaper.SplitMediaItem(item, t)
end

local function safe_get_item_bounds(item)
  local pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
  return pos, pos + len
end

local function set_item_edges(item, new_start, new_end)
  local old_start, old_end = safe_get_item_bounds(item)
  new_start = clamp(new_start, old_start, old_end)
  new_end = clamp(new_end, old_start, old_end)
  if new_end <= new_start + 1e-6 then return end

  if math.abs(new_start - old_start) > 1e-6 then
    local right = reaper.SplitMediaItem(item, new_start)
    if right then
      reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(item), item)
      item = right
    end
  end

  local start2, end2 = safe_get_item_bounds(item)
  if math.abs(new_end - end2) > 1e-6 then
    local right = reaper.SplitMediaItem(item, new_end)
    if right then
      reaper.DeleteTrackMediaItem(reaper.GetMediaItem_Track(right), right)
    end
  end
end

-- ---------- main per-item slicer ----------
local function slice_item(item, mode, cfg_hits, cfg_tex, cfg_auto)
  local take = reaper.GetActiveTake(item)
  if not take or reaper.TakeIsMIDI(take) then return 0 end

  local item_start, item_end = safe_get_item_bounds(item)
  local dur = item_end - item_start
  if dur <= 0.02 then return 0 end

  local numch = 2
  if reaper.GetMediaSourceNumChannels then
    local src = reaper.GetMediaItemTake_Source(take)
    if src then
      local ch = reaper.GetMediaSourceNumChannels(src)
      if ch and ch > 0 then numch = math.min(2, ch) end
    end
  end

  local pr = cfg_auto.peakrate or 400
  local env = get_take_envelope(take, pr, item_start, dur, numch)
  if not env then return 0 end
  env = smooth_env(env, cfg_auto.smooth_win or 7)

  -- Auto segmentation: in v3 we keep it simple: whole item as one segment.
  -- If you want multi-segment (mixed content), you can extend here.
  local segs = {{1, #env.a}}

  local made = 0
  for _, seg in ipairs(segs) do
    local i1, i2 = seg[1], seg[2]
    local segMode = mode
    if mode == "auto" then
      segMode = classify_segment(env, i1, i2, cfg_auto)
    end

    local cfg = (segMode == "textures") and cfg_tex or cfg_hits

    -- bind HQ toggle from cfg_auto
    cfg.hq_zero_cross = cfg_auto.hq_zero_cross and true or false

    -- iterative calibration (auto)
    if cfg_auto.calibrate and cfg_auto.calibrate.enabled then
      local tgt_min = (segMode=="textures") and (cfg_auto.target_textures_min or 2) or (cfg_auto.target_hits_min or 12)
      local tgt_max = (segMode=="textures") and (cfg_auto.target_textures_max or 60) or (cfg_auto.target_hits_max or 220)
      calibrate_onsets(env, cfg, tgt_min, tgt_max, cfg_auto.calibrate)
    end

    local onsets = detect_onsets(env, cfg)

    if #onsets == 0 then
      -- fallback: one slice for textures, maybe tail-trim for hits
      if segMode == "textures" then
        made = made + 1
      else
        -- tail based on peaks
        local end_idx = detect_tail_end_time(env, 1, cfg)
        local new_end = item_start + (end_idx-1)/env.peakrate
        set_item_edges(item, item_start, new_end)
        made = made + 1
      end
      goto continue
    end

    -- Convert onset indices -> project time
    local times = {}
    for _, idx in ipairs(onsets) do
      local t = item_start + ((idx-1) / env.peakrate)
      times[#times+1] = t
    end

    -- Ensure first slice starts at item_start if onset is late
    local pre_roll = (cfg.pre_roll_ms or 0) * 0.001
    for i=1,#times do times[i] = times[i] - pre_roll end
    table.sort(times)

    local min_len = (cfg.min_slice_len_ms or 45) * 0.001
    local max_len = (cfg.max_slice_len_ms or 550) * 0.001
    local gap = (cfg.min_slice_gap_ms or 18) * 0.001

    -- We'll split sequentially on the original item:
    local cur_item = item
    local cur_start = item_start
    local created_items = {}

    local function do_split_at(t)
      t = clamp(t, cur_start + 1e-6, item_end - 1e-6)
      if cfg_auto.hq_zero_cross then
        t = maybe_snap_zero_cross(take, t, item_start, item_end, cfg_auto, false)
      end
      local right = split_item_at_time(cur_item, t)
      if right then
        created_items[#created_items+1] = cur_item
        cur_item = right
        cur_start = t
        return true
      end
      return false
    end

    -- Split at all onset times (filtered)
    local last_t = nil
    for _, t in ipairs(times) do
      if not last_t or (t - last_t) >= gap then
        if t > (cur_start + min_len) and t < (item_end - min_len) then
          do_split_at(t)
          last_t = t
        end
      end
    end
    created_items[#created_items+1] = cur_item

    -- Now trim each slice:
    for idx_it, it in ipairs(created_items) do
      local s, e = safe_get_item_bounds(it)
      local slice_len = e - s

      -- basic length clamp for hits
      if segMode == "hits" then
        local desired_end = s + clamp(slice_len, min_len, max_len)
        -- tail detection upgrade: for last slice, extend until silence (HQ!)
        if idx_it == #created_items then
          local start_idx = math.max(1, math.floor((s - item_start) * env.peakrate) + 1)
          local end_idx = detect_tail_end_time(env, start_idx, cfg)
          desired_end = item_start + (end_idx-1)/env.peakrate
        end
        if cfg_auto.hq_zero_cross then
          desired_end = maybe_snap_zero_cross(take, desired_end, item_start, item_end, cfg_auto, true)
        end
        set_item_edges(it, s, clamp(desired_end, s+0.001, item_end))
      else
        -- textures: keep, but optionally tail-trim end to silence for last
        if idx_it == #created_items and (cfg.trim_textures_to_silence) then
          local start_idx = math.max(1, math.floor((s - item_start) * env.peakrate) + 1)
          local end_idx = detect_tail_end_time(env, start_idx, cfg)
          local desired_end = item_start + (end_idx-1)/env.peakrate
          if cfg_auto.hq_zero_cross then
            desired_end = maybe_snap_zero_cross(take, desired_end, item_start, item_end, cfg_auto, true)
          end
          set_item_edges(it, s, clamp(desired_end, s+0.05, item_end))
        end
      end
      made = made + 1
    end

    ::continue::
  end

  return made
end

-- ---------- public entry ----------
function M.run(mode, opts)
  opts = opts or {}
  local items = get_target_items()
  if #items == 0 then
    reaper.ShowMessageBox("No target items.\nSelect items, or select tracks containing items.", "IFLSWB SmartSlicer", 0)
    return
  end

  -- persistent HQ toggle
  local hq = ext_get("IFLSWB_SmartSlicer", "HQ", "1") -- default HQ ON in v3
  local hq_on = (hq == "1")

  local cfg_auto = {
    peakrate = opts.peakrate or 400,
    smooth_win = opts.smooth_win or 7,

    -- mode-level HQ toggle (applies to snap)
    hq_zero_cross = opts.hq_zero_cross ~= nil and opts.hq_zero_cross or hq_on,
    hq_start_window_ms = opts.hq_start_window_ms or 6,
    hq_end_window_ms   = opts.hq_end_window_ms or 10,

    -- calibration targets
    calibrate = {
      enabled = (opts.calibrate ~= nil) and opts.calibrate or true,
      step_db = opts.cal_step_db or 2.5,
      max_iters = opts.cal_max_iters or 8,
    },
    target_hits_min = opts.target_hits_min or 12,
    target_hits_max = opts.target_hits_max or 220,
    target_textures_min = opts.target_textures_min or 2,
    target_textures_max = opts.target_textures_max or 60,

    -- classification heuristics
    texture_sustain_ratio = 0.18,
    texture_sustain_pct = 0.32,
    texture_min_len_s = 2.0,
    texture_density = 0.22,

    -- optional texture trimming
    trim_textures_to_silence = opts.trim_textures_to_silence or false,
  }

  local cfg_hits = {
    noise_pct = 0.25,
    onset_abs_db = opts.hits_onset_abs_db or -22, -- will be re-centered by calibration relative to actual audio
    onset_rel_db = 0,
    onset_confirm_ms = 6,
    onset_release_ms = 8,
    onset_hyst_db = 6,
    onset_backtrack_ms = 10,
    onset_backtrack_db = 9,

    pre_roll_ms = 0,

    min_slice_len_ms = opts.hits_min_len_ms or 40,
    max_slice_len_ms = opts.hits_max_len_ms or 550,
    min_slice_gap_ms = opts.hits_min_gap_ms or 18,

    -- tail detection
    tail_silence_db = opts.hits_tail_silence_db or -55,
    tail_silence_hold_ms = opts.hits_tail_hold_ms or 80,
    max_tail_s = opts.hits_max_tail_s or 12,
  }

  local cfg_tex = {
    noise_pct = 0.25,
    onset_abs_db = opts.tex_onset_abs_db or -30,
    onset_rel_db = 0,
    onset_confirm_ms = 10,
    onset_release_ms = 12,
    onset_hyst_db = 7,
    onset_backtrack_ms = 12,
    onset_backtrack_db = 10,

    pre_roll_ms = 0,
    min_slice_len_ms = opts.tex_min_len_ms or 250,
    max_slice_len_ms = opts.tex_max_len_ms or 2400,
    min_slice_gap_ms = opts.tex_min_gap_ms or 120,

    tail_silence_db = opts.tex_tail_silence_db or -60,
    tail_silence_hold_ms = opts.tex_tail_hold_ms or 200,
    max_tail_s = opts.tex_max_tail_s or 30,
  }

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local total = 0
  for _, item in ipairs(items) do
    total = total + slice_item(item, mode, cfg_hits, cfg_tex, cfg_auto)
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("IFLSWB Fieldrec SmartSlicer ("..mode..") - v3", -1)

  -- store HQ toggle state (if caller did not override explicitly)
  if opts.hq_zero_cross == nil then
    ext_set("IFLSWB_SmartSlicer", "HQ", cfg_auto.hq_zero_cross and "1" or "0")
  end

  return total
end

function M.toggle_hq()
  local cur = ext_get("IFLSWB_SmartSlicer", "HQ", "1")
  local newv = (cur == "1") and "0" or "1"
  ext_set("IFLSWB_SmartSlicer", "HQ", newv)
  reaper.ShowMessageBox("HQ Mode (zero-cross snap) is now: "..((newv=="1") and "ON" or "OFF"), "IFLSWB SmartSlicer", 0)
  return newv=="1"
end

return M
