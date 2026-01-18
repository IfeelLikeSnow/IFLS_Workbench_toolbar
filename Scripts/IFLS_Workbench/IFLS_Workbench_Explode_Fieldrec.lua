-- @description IFLS Workbench: Explode Fieldrec + Mic FX + Buses
-- @version 0.1.3
-- @author I feel like snow
-- @about
--   Select imported polywav/multichannel (or single wav) items and run:
--   - Explode multichannel items to one-channel items (tries common command IDs)
--   - Create routing: Mic Tracks -> FX BUS -> COLOR BUS -> MASTER BUS
--   - Apply basic mic cleanup (ReaEQ HPF + optional presence band) based on track name matching.

local r = reaper

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local SHOW_STATUS_MB_ON_FALLBACK = true     -- show a message box when we have to fallback
local ALWAYS_LOG_TO_CONSOLE      = true     -- print status to ReaScript console
local RENAME_TAKES               = true     -- also rename take names (P_NAME)
local RENAME_TRACKS              = true     -- rename track names (P_NAME)

------------------------------------------------------------
-- STATUS / LOG
------------------------------------------------------------
local log_lines = {}

local function log(msg)
  msg = tostring(msg or "")
  log_lines[#log_lines+1] = msg
  if ALWAYS_LOG_TO_CONSOLE then
    r.ShowConsoleMsg("[IFLSWB] " .. msg .. "\n")
  end
end

local function show_fallback_mb()
  if SHOW_STATUS_MB_ON_FALLBACK and #log_lines > 0 then
    r.MB(table.concat(log_lines, "\n"), "IFLS Workbench â€“ Status", 0)
  end
end

------------------------------------------------------------
-- AUTO NAMING / CHANNEL MAPPING
------------------------------------------------------------

local function basename_noext(path)
  path = tostring(path or "")
  path = path:gsub("\\", "/")
  local name = path:match("([^/]+)$") or path
  name = name:gsub("%.%w+$", "")
  return name
end

local function get_first_selected_source_path()
  local it = r.GetSelectedMediaItem(0, 0)
  if not it then return "" end
  local tk = r.GetActiveTake(it)
  if not tk then return "" end
  local src = r.GetMediaItemTake_Source(tk)
  if not src then return "" end
  local buf = ""
  local rv, fn = r.GetMediaSourceFileName(src, buf)
  return fn or ""
end

local function detect_session_tag(src_path)
  local base = basename_noext(src_path):upper()
  -- e.g. S25_..., S25-..., ..._S25...
  local s = base:match("(S%d%d)")
  if s then return s end
  -- common Zoom naming (ZOOM0001, F6, F8 etc.)
  if base:find("ZOOM", 1, true) or base:find("F6", 1, true) or base:find("F8", 1, true) then
    return "ZOOM"
  end
  return "FIELDREC"
end

local function norm_label(s)
  s = tostring(s or "")
  s = s:gsub("[%c]", "")
  s = s:gsub("[_%-]+", " ")
  s = s:gsub("%s+", " ")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

local function extract_channel_index_from_name(take_name)
  local tn = (take_name or ""):lower()
  local n = tn:match("ch%s*(%d+)")
  if not n then n = tn:match("chan%s*(%d+)") end
  if not n then n = tn:match("trk%s*(%d+)") end
  if not n then n = tn:match("track%s*(%d+)") end
  if not n then n = tn:match("t%s*(%d+)") end
  n = tonumber(n)
  if n and n > 0 and n < 100 then return n end
  return nil
end

local function clean_take_label(take_name, src_base)
  local s = norm_label(take_name)
  local sb = norm_label(src_base)
  if sb ~= "" then
    -- remove source basename if REAPER included it
    s = s:gsub(sb, "", 1)
    s = norm_label(s)
  end

  -- remove generic prefixes
  s = s:gsub("^take%s*%d*", "")
  s = s:gsub("^channel%s*%d*", "")
  s = s:gsub("^chan%s*%d*", "")
  s = s:gsub("^ch%s*%d*", "")
  s = s:gsub("^track%s*%d*", "")
  s = s:gsub("^trk%s*%d*", "")
  s = norm_label(s)
  return s
end

local function canonicalize_label(label)
  local l = " " .. (label or ""):lower() .. " "
  -- quick canonicalization for common field-rec terms
  l = l:gsub("lavalier", "lav")
  l = l:gsub("wireless", "lav")
  l = l:gsub("boom mic", "boom")
  l = l:gsub("ambient", "amb")
  l = l:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")

  -- uppercase short tokens, keep words
  local out = {}
  for w in l:gmatch("%S+") do
    if w == "lav" or w == "boom" or w == "amb" or w == "ms" then
      out[#out+1] = w:upper()
    elseif w == "l" or w == "left" then
      out[#out+1] = "L"
    elseif w == "r" or w == "right" then
      out[#out+1] = "R"
    else
      -- Title-case-ish
      out[#out+1] = (w:sub(1,1):upper() .. w:sub(2))
    end
  end
  return table.concat(out, " ")
end

local function set_track_name_safe(tr, name)
  if not (RENAME_TRACKS and tr) then return end
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", tostring(name or ""), true)
end

local function set_take_name_safe(tk, name)
  if not (RENAME_TAKES and tk) then return end
  r.GetSetMediaItemTakeInfo_String(tk, "P_NAME", tostring(name or ""), true)
end

local function first_take_on_track(tr)
  local it = r.GetTrackMediaItem(tr, 0)
  if not it then return nil, nil end
  local tk = r.GetActiveTake(it)
  return it, tk
end

local function auto_name_and_map_tracks(mic_tracks, session_tag, src_base)
  if not mic_tracks or #mic_tracks == 0 then return end
  log(("Auto-Naming: Session tag = %s, Source = %s"):format(session_tag, src_base))

  for i, tr in ipairs(mic_tracks) do
    local _, tk = first_take_on_track(tr)
    local take_name = tk and r.GetTakeName(tk) or ""
    local ch = extract_channel_index_from_name(take_name) or i
    local label = clean_take_label(take_name, src_base)
    if label == "" then
      label = ("CH%02d"):format(ch)
    else
      label = canonicalize_label(label)
    end

    local final_name = ("%s - %s"):format(session_tag, label)
    set_track_name_safe(tr, final_name)
    set_take_name_safe(tk, label)
  end
end


-- Native command IDs differ between REAPER builds/localizations sometimes.
-- We'll try the common ones and verify by checking if track/item counts changed.
local EXPLODE_CMD_CANDIDATES = {40224, 40894}

local function run_explode_multichannel()
  local before_tracks = r.CountTracks(0)
  local before_items = r.CountMediaItems(0)
  for _, cmd in ipairs(EXPLODE_CMD_CANDIDATES) do
    r.Main_OnCommand(cmd, 0)
    -- if something changed, assume it worked
    if r.CountTracks(0) ~= before_tracks or r.CountMediaItems(0) ~= before_items then
      return cmd
    end
  end
  return nil
end


local function clamp(x, a, b) if x < a then return a elseif x > b then return b else return x end end

-- Frequency mapping 20..20000 Hz -> 0..1 (log)
local function norm_freq(freq_hz)
  local fmin, fmax = 20.0, 20000.0
  local f = clamp(freq_hz or 100.0, fmin, fmax)
  return (math.log(f / fmin) / math.log(fmax / fmin))
end

-- Gain mapping -24..+24 dB -> 0..1
local function norm_gain(gain_db)
  local gmin, gmax = -24.0, 24.0
  local g = clamp(gain_db or 0.0, gmin, gmax)
  return (g - gmin) / (gmax - gmin)
end

-- "Q-ish" mapping 0.1..10 -> 0..1 (log)
local function norm_q(q)
  local qmin, qmax = 0.1, 10.0
  local v = clamp(q or 1.0, qmin, qmax)
  return (math.log(v / qmin) / math.log(qmax / qmin))
end

local function get_script_dir()
  local src = debug.getinfo(1, "S").source
  return src:match("@(.*[\\/])") or ""
end

local function load_profiles()
  local dir = get_script_dir()
  local ok, profiles = pcall(dofile, dir .. "lib/ifls_workbench_mic_profiles.lua")
  if ok and type(profiles) == "table" then return profiles end
  return {}
end

local function norm_name(s)
  s = tostring(s or ""):lower()
  s = s:gsub("[%c%p]", " ")
  s = s:gsub("%s+", " ")
  return s
end

local function find_profile(track_name, profiles)
  local tn = norm_name(track_name)
  for _, p in ipairs(profiles) do
    if p.aliases then
      for _, a in ipairs(p.aliases) do
        local an = norm_name(a)
        if an ~= "" and tn:find(an, 1, true) then
          return p
        end
      end
    end
  end
  return nil
end

local function get_track_name(tr)
  local _, name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  return name or ""
end

local function set_track_name(tr, name)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", tostring(name or ""), true)
end

local function insert_track_at(idx0, name)
  r.InsertTrackAtIndex(idx0, true)
  local tr = r.GetTrack(0, idx0)
  if tr and name then set_track_name(tr, name) end
  return tr
end

local function disable_master_send(tr)
  r.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
end

local function make_send(src, dst)
  return r.CreateTrackSend(src, dst)
end

-- ReaEQ param layout assumption: 5 params per band
local function reaeq_param(band, which)
  return (band - 1) * 5 + which
end

-- Approx type encoding (normalized) for ReaEQ band type parameter
local REAEQ_TYPE_BAND     = 0
local REAEQ_TYPE_HIGHPASS = 4

local function ensure_reaeq(tr)
  local cnt = r.TrackFX_GetCount(tr)
  for i=0,cnt-1 do
    local _, fxname = r.TrackFX_GetFXName(tr, i, "")
    if fxname and fxname:lower():find("reaeq", 1, true) then
      return i
    end
  end
  return r.TrackFX_AddByName(tr, "ReaEQ", false, -1)
end

local function set_param_norm(tr, fx, param, val)
  if r.TrackFX_SetParamNormalized then
    r.TrackFX_SetParamNormalized(tr, fx, param, clamp(val, 0.0, 1.0))
  else
    r.TrackFX_SetParam(tr, fx, param, clamp(val, 0.0, 1.0))
  end
end

local function apply_profile_eq(tr, profile)
  local fx = ensure_reaeq(tr)
  if fx < 0 then return end

  -- Band 1: High-pass
  set_param_norm(tr, fx, reaeq_param(1,0), 1.0) -- enabled
  set_param_norm(tr, fx, reaeq_param(1,1), REAEQ_TYPE_HIGHPASS / 7.0) -- type (approx)
  set_param_norm(tr, fx, reaeq_param(1,2), norm_freq(profile.hpf_hz or 80))
  set_param_norm(tr, fx, reaeq_param(1,3), norm_gain(0.0))
  set_param_norm(tr, fx, reaeq_param(1,4), norm_q(0.7))

  -- Band 2: Presence (optional)
  if profile.presence then
    set_param_norm(tr, fx, reaeq_param(2,0), 1.0)
    set_param_norm(tr, fx, reaeq_param(2,1), REAEQ_TYPE_BAND / 7.0)
    set_param_norm(tr, fx, reaeq_param(2,2), norm_freq(profile.presence.freq_hz or 3500))
    set_param_norm(tr, fx, reaeq_param(2,3), norm_gain(profile.presence.gain_db or 0.0))
    set_param_norm(tr, fx, reaeq_param(2,4), norm_q(profile.presence.q or 1.0))
  end
end

local function ensure_project_96k()
  r.GetSetProjectInfo(0, "PROJECT_SRATE_USE", 1, true)
  r.GetSetProjectInfo(0, "PROJECT_SRATE", 96000, true)
end

local function explode_selected_items()
  -- Explode multichannel items (if selected items are multichannel).
  -- Returns command id used, or nil if nothing changed.
  return run_explode_multichannel()
end

local function track_guid(tr)
  local _, guid = r.GetSetMediaTrackInfo_String(tr, "GUID", "", false)
  return guid
end

local function snapshot_track_guids()
  local set = {}
  local n = r.CountTracks(0)
  for i = 0, n-1 do
    local tr = r.GetTrack(0, i)
    local g = track_guid(tr)
    if g and g ~= "" then set[g] = true end
  end
  return set
end

local function collect_source_tracks_from_selected_items()
  local map, list = {}, {}
  local n = r.CountSelectedMediaItems(0)
  for i=0,n-1 do
    local it = r.GetSelectedMediaItem(0, i)
    local tr = r.GetMediaItem_Track(it)
    if tr and not map[tr] then
      map[tr] = true
      list[#list+1] = tr
    end
  end
  table.sort(list, function(a,b)
    return r.GetMediaTrackInfo_Value(a, "IP_TRACKNUMBER") < r.GetMediaTrackInfo_Value(b, "IP_TRACKNUMBER")
  end)
  return list
end

local function collect_new_tracks_since(before_guids)
  local list = {}
  local n = r.CountTracks(0)
  for i = 0, n-1 do
    local tr = r.GetTrack(0, i)
    local g = track_guid(tr)
    if g and g ~= "" and not before_guids[g] then
      list[#list+1] = tr
    end
  end
  table.sort(list, function(a,b)
    return r.GetMediaTrackInfo_Value(a, "IP_TRACKNUMBER") < r.GetMediaTrackInfo_Value(b, "IP_TRACKNUMBER")
  end)
  return list
end


local function create_bus_chain(after_track)
  local last_num = r.GetMediaTrackInfo_Value(after_track, "IP_TRACKNUMBER") -- 1-based
  local insert_idx = math.floor(last_num) -- 0-based "after last"
  local fxbus    = insert_track_at(insert_idx,     "IFLS WB - FX BUS")
  local colorbus = insert_track_at(insert_idx + 1, "IFLS WB - COLOR BUS")
  local master   = insert_track_at(insert_idx + 2, "IFLS WB - MASTER BUS")

  disable_master_send(fxbus)
  disable_master_send(colorbus)
  make_send(fxbus, colorbus)
  make_send(colorbus, master)

  return fxbus
end

local function run()
  if r.CountSelectedMediaItems(0) == 0 then
    r.MB("Bitte zuerst mindestens ein Item auswÃ¤hlen (PolyWAV oder WAV).", "IFLS Workbench", 0)
    return
  end

  local profiles = load_profiles()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  -- Status init
  if r.ClearConsole then r.ClearConsole() end
  log_lines = {}
  local src_path = get_first_selected_source_path()
  local src_base = basename_noext(src_path)
  local session_tag = detect_session_tag(src_path)
  local fallback_used = false


  ensure_project_96k()

  -- Snapshot tracks BEFORE explode because REAPER's explode action may not keep items selected.
  local before = snapshot_track_guids()
  local src_tracks = collect_source_tracks_from_selected_items()

  local used_cmd = explode_selected_items()

  local new_tracks = collect_new_tracks_since(before)

  if #new_tracks == 0 then
    fallback_used = true
    log("Explode hat keine neuen Tracks erzeugt â†’ nutze Source-Tracks (z.B. Mono WAV oder Selection verloren).")
  else
    log(("Explode: %d neue Tracks erzeugt (CMD=%s)"):format(#new_tracks, tostring(used_cmd or "unknown")))
  end


  -- Prefer tracks created by explode; fallback to the original source tracks (mono WAV etc.).
  local mic_tracks = (#new_tracks > 0) and new_tracks or src_tracks

  -- Apply naming / channel mapping based on take/channel names.
  auto_name_and_map_tracks(mic_tracks, session_tag, src_base)


  if #mic_tracks == 0 then
    r.PreventUIRefresh(-1)
    r.Undo_EndBlock("IFLS Workbench: Explode + Bus Chain + Mic FX", -1)
    return
  end

  local fxbus = create_bus_chain(mic_tracks[#mic_tracks])

  for _, tr in ipairs(mic_tracks) do
    disable_master_send(tr)
    make_send(tr, fxbus)

    local tn = get_track_name(tr)
    local p = find_profile(tn, profiles)
    if p then
      apply_profile_eq(tr, p)
    else
      apply_profile_eq(tr, {hpf_hz=80})
    end
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()

  if fallback_used then
    show_fallback_mb()
  end

  r.Undo_EndBlock("IFLS Workbench: Explode + Bus Chain + Mic FX", -1)
end

run()
