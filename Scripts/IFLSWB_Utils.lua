-- IFLSWB_Utils.lua
local U = {}

function U.msg(title, text)
  reaper.ShowMessageBox(tostring(text), tostring(title), 0)
end

function U.norm(s)
  s = tostring(s or ""):lower()
  s = s:gsub("[^%w%s%+%-øöäüéáíóúâêîôûß]", " ")
  s = s:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

function U.find_profile(contextText, Profiles)
  local t = U.norm(contextText)
  if t == "" then return nil end

  -- direct alias hit
  for k,v in pairs(Profiles.aliases or {}) do
    local kk = U.norm(k)
    if kk ~= "" and t:find(kk, 1, true) then
      return v
    end
  end

  -- fallback: if any canonical name appears
  for name,_ in pairs(Profiles.profiles or {}) do
    local nn = U.norm(name)
    if nn ~= "" and t:find(nn, 1, true) then
      return name
    end
  end

  return nil
end

function U.get_track_name(track)
  local _, name = reaper.GetTrackName(track, "")
  return name or ""
end

function U.set_track_name(track, name)
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", tostring(name), true)
end

function U.track_by_name(name)
  local cnt = reaper.CountTracks(0)
  for i=0,cnt-1 do
    local tr = reaper.GetTrack(0,i)
    local tn = U.get_track_name(tr)
    if tn == name then return tr end
  end
  return nil
end

function U.ensure_track_at_end(name)
  local existing = U.track_by_name(name)
  if existing then return existing, false end
  local idx = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, true)
  local tr = reaper.GetTrack(0, idx)
  U.set_track_name(tr, name)
  return tr, true
end

function U.disable_master_send(track, disabled)
  reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", disabled and 0 or 1)
end

function U.ensure_send(src, dst)
  -- avoid duplicate sends
  local sendCnt = reaper.GetTrackNumSends(src, 0) -- 0 = sends
  for s=0,sendCnt-1 do
    local d = reaper.BR_GetMediaTrackSendInfo_Track(src, 0, s, 1) -- requires SWS, but if missing just create
    if d == dst then return s end
  end
  local sendIdx = reaper.CreateTrackSend(src, dst)
  return sendIdx
end

-- Basic bus graph:
-- Mic tracks -> FX Bus -> Coloring Bus -> Master Bus -> REAPER Master
function U.ensure_buses(busNames)
  local fxBus = U.ensure_track_at_end(busNames.fx)
  local colBus = U.ensure_track_at_end(busNames.coloring)
  local mastBus = U.ensure_track_at_end(busNames.master)

  -- disable main send for intermediate buses
  U.disable_master_send(fxBus, true)
  U.disable_master_send(colBus, true)
  -- master bus should go to master
  U.disable_master_send(mastBus, false)

  -- route FX -> Coloring -> Master
  U.ensure_send(fxBus, colBus)
  U.ensure_send(colBus, mastBus)

  return fxBus, colBus, mastBus
end

-- Insert track below base track (returns new track)
function U.insert_track_below(baseTrack, offset)
  local baseIdx1 = reaper.GetMediaTrackInfo_Value(baseTrack, "IP_TRACKNUMBER") -- 1-based
  local insertAt = (baseIdx1 - 1) + (offset or 1)
  reaper.InsertTrackAtIndex(insertAt, true)
  return reaper.GetTrack(0, insertAt)
end

function U.get_take_name(take)
  local _, name = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  return name or ""
end

function U.get_item_source_path(take)
  local src = reaper.GetMediaItemTake_Source(take)
  if not src then return "" end
  local buf = ""
  local ok, fn = reaper.GetMediaSourceFileName(src, buf)
  return ok and (fn or "") or ""
end

-- -------- ReaEQ helpers --------
local function ensure_reaeq(track)
  local fxCount = reaper.TrackFX_GetCount(track)
  for i=0,fxCount-1 do
    local _, fxName = reaper.TrackFX_GetFXName(track, i, "")
    if fxName and fxName:lower():find("reaeq", 1, true) then
      return i
    end
  end
  local idx = reaper.TrackFX_AddByName(track, "ReaEQ (Cockos)", false, -1)
  return idx
end

local function get_param_range(track, fx, param)
  local val, minv, maxv = reaper.TrackFX_GetParamEx(track, fx, param)
  return val, minv, maxv
end

local function set_param_value(track, fx, param, desired, hint)
  local _, minv, maxv = get_param_range(track, fx, param)
  if minv == nil or maxv == nil then return end
  if desired == nil then return end

  local norm
  hint = hint or "linear"

  if hint == "log" and minv > 0 and desired > 0 and maxv > minv then
    norm = (math.log(desired/minv) / math.log(maxv/minv))
  else
    norm = (desired - minv) / (maxv - minv)
  end

  if norm ~= norm then return end -- NaN guard
  if norm < 0 then norm = 0 end
  if norm > 1 then norm = 1 end

  if reaper.TrackFX_SetParamNormalized then
    reaper.TrackFX_SetParamNormalized(track, fx, param, norm)
  else
    reaper.TrackFX_SetParam(track, fx, param, norm)
  end
end

local function build_reaeq_param_map(track, fx)
  local map = {}
  local num = reaper.TrackFX_GetNumParams(track, fx)
  for p=0,num-1 do
    local _, n = reaper.TrackFX_GetParamName(track, fx, p, "")
    n = n or ""
    local ln = n:lower()
    local band = ln:match("band%s*(%d+)")
    if band then
      band = tonumber(band)
      map[band] = map[band] or {}
      if ln:find("freq") then map[band].freq = p end
      if ln:find("gain") then map[band].gain = p end
      if ln:find("q") or ln:find("width") or ln:find("bandw") then map[band].q = p end
      if ln:find("type") then map[band].type = p end
      if ln:find("enable") or ln:find("enabled") then map[band].en = p end
    end
  end
  return map
end

local function discover_type_index(track, fx, typeParam, wantedType)
  -- brute discover: step through discrete values and compare formatted label
  local _, minv, maxv = get_param_range(track, fx, typeParam)
  if minv == nil or maxv == nil then return nil end

  local steps = math.floor(maxv - minv + 0.5)
  if steps < 1 then steps = 8 end

  local want = U.norm(wantedType)

  local bestIdx = nil
  for i=0,steps do
    local norm = steps == 0 and 0 or (i/steps)
    if reaper.TrackFX_SetParamNormalized then
      reaper.TrackFX_SetParamNormalized(track, fx, typeParam, norm)
    else
      reaper.TrackFX_SetParam(track, fx, typeParam, norm)
    end
    local _, fmt = reaper.TrackFX_GetFormattedParamValue(track, fx, typeParam, "")
    fmt = U.norm(fmt or "")
    if fmt ~= "" then
      -- token contains match
      if want ~= "" and fmt:find(want, 1, true) then
        bestIdx = i
        break
      end
      -- allow english/german approximations
      if want == "high pass" or want == "hochpass" then
        if fmt:find("high",1,true) and fmt:find("pass",1,true) then bestIdx=i; break end
        if fmt:find("hoch",1,true) and fmt:find("pass",1,true) then bestIdx=i; break end
        if fmt:find("hochpass",1,true) then bestIdx=i; break end
      end
      if want == "low pass" or want == "tiefpass" then
        if fmt:find("low",1,true) and fmt:find("pass",1,true) then bestIdx=i; break end
        if fmt:find("tief",1,true) and fmt:find("pass",1,true) then bestIdx=i; break end
        if fmt:find("tiefpass",1,true) then bestIdx=i; break end
      end
      if want == "peak" then
        if fmt:find("peak",1,true) or fmt:find("bell",1,true) or fmt:find("glock",1,true) then bestIdx=i; break end
      end
      if want == "notch" then
        if fmt:find("notch",1,true) or fmt:find("kerb",1,true) or fmt:find("kerbe",1,true) then bestIdx=i; break end
      end
      if want == "high shelf" then
        if fmt:find("high",1,true) and fmt:find("shelf",1,true) then bestIdx=i; break end
        if fmt:find("hoch",1,true) and fmt:find("shelf",1,true) then bestIdx=i; break end
      end
      if want == "low shelf" then
        if fmt:find("low",1,true) and fmt:find("shelf",1,true) then bestIdx=i; break end
        if fmt:find("tief",1,true) and fmt:find("shelf",1,true) then bestIdx=i; break end
      end
    end
  end

  if bestIdx == nil then return nil end
  return bestIdx, steps
end

function U.apply_mic_eq(track, profile)
  if not profile or not profile.eq then return end
  local fx = ensure_reaeq(track)
  if fx < 0 then return end

  local pmap = build_reaeq_param_map(track, fx)

  for _,b in ipairs(profile.eq) do
    local band = tonumber(b.band or 1)
    local bm = pmap[band]
    if bm then
      if bm.en then
        set_param_value(track, fx, bm.en, 1.0, "linear")
      end
      if bm.type and b.type then
        local wanted = tostring(b.type)
        local old = reaper.TrackFX_GetParam(track, fx, bm.type)
        local idx, steps = discover_type_index(track, fx, bm.type, wanted)
        if idx and steps then
          local norm = steps == 0 and 0 or (idx/steps)
          if reaper.TrackFX_SetParamNormalized then
            reaper.TrackFX_SetParamNormalized(track, fx, bm.type, norm)
          else
            reaper.TrackFX_SetParam(track, fx, bm.type, norm)
          end
        else
          -- restore old if we changed it
          if old then
            if reaper.TrackFX_SetParamNormalized then
              reaper.TrackFX_SetParamNormalized(track, fx, bm.type, old)
            else
              reaper.TrackFX_SetParam(track, fx, bm.type, old)
            end
          end
        end
      end
      if bm.freq and b.freq then
        set_param_value(track, fx, bm.freq, tonumber(b.freq), "log")
      end
      if bm.gain and b.gain then
        set_param_value(track, fx, bm.gain, tonumber(b.gain), "linear")
      end
      if bm.q and b.q then
        set_param_value(track, fx, bm.q, tonumber(b.q), "log")
      end
    end
  end
end

-- -------- Explode helpers --------

function U.set_take_mono_channel(take, chan)
  -- In den meisten REAPER Builds gilt:
  -- I_CHANMODE: 2 = mono ch1, 3 = mono ch2, 4 = mono ch3, ...
  -- Falls bei dir falsche Channels kommen, ändere hier das Mapping.
  local v = 1 + tonumber(chan or 1) -- chan1 => 2
  reaper.SetMediaItemTakeInfo_Value(take, "I_CHANMODE", v)
end

function U.duplicate_item_to_track(srcItem, destTrack)
  local srcTake = reaper.GetActiveTake(srcItem)
  if not srcTake then return nil end

  local newItem = reaper.AddMediaItemToTrack(destTrack)

  -- copy item basics
  local pos = reaper.GetMediaItemInfo_Value(srcItem, "D_POSITION")
  local len = reaper.GetMediaItemInfo_Value(srcItem, "D_LENGTH")
  reaper.SetMediaItemInfo_Value(newItem, "D_POSITION", pos)
  reaper.SetMediaItemInfo_Value(newItem, "D_LENGTH", len)

  -- fades (best-effort)
  for _,k in ipairs({"D_FADEINLEN","D_FADEOUTLEN","D_FADEINDIR","D_FADEOUTDIR","D_FADEINLEN_AUTO","D_FADEOUTLEN_AUTO"}) do
    local val = reaper.GetMediaItemInfo_Value(srcItem, k)
    if val then reaper.SetMediaItemInfo_Value(newItem, k, val) end
  end

  local newTake = reaper.AddTakeToMediaItem(newItem)
  local src = reaper.GetMediaItemTake_Source(srcTake)
  if src then reaper.SetMediaItemTake_Source(newTake, src) end

  -- take properties
  local offs = reaper.GetMediaItemTakeInfo_Value(srcTake, "D_STARTOFFS")
  local rate = reaper.GetMediaItemTakeInfo_Value(srcTake, "D_PLAYRATE")
  local pitch = reaper.GetMediaItemTakeInfo_Value(srcTake, "D_PITCH")
  reaper.SetMediaItemTakeInfo_Value(newTake, "D_STARTOFFS", offs)
  reaper.SetMediaItemTakeInfo_Value(newTake, "D_PLAYRATE", rate)
  reaper.SetMediaItemTakeInfo_Value(newTake, "D_PITCH", pitch)

  local tn = U.get_take_name(srcTake)
  reaper.GetSetMediaItemTakeInfo_String(newTake, "P_NAME", tn, true)

  reaper.SetActiveTake(newTake)
  return newItem
end

return U