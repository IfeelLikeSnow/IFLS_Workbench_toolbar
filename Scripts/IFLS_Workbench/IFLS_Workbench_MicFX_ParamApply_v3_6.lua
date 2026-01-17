-- @description IFLS Workbench - MicFX ParamApply v3.6 (LiveAware â€“ JSFX Meter, Drive & Comp Bias)
-- @version 0.1.0

local r = reaper

local function find_fx(tr)
  local n = r.TrackFX_GetCount(tr)
  local fx = {eq=-1, comp=-1, flavor=-1, meter=-1}
  for i=0,n-1 do
    local _, nm = r.TrackFX_GetFXName(tr, i, "")
    local l = nm:lower()
    if l:find("df95 dynamic meter v1") then fx.meter=i end
    if l:find("reaeq") then fx.eq=i end
    if l:find("reacomp") then fx.comp=i end
    if l:find("purestdrive") or l:find("burier") or l:find("britpre") or l:find("totape") or l:find("channel8") then fx.flavor=i end
  end
  return fx
end

local function ensure_meter_top(tr)
  local idx = r.TrackFX_AddByName(tr, "JS: DF95 Dynamic Meter v1 (PeakNorm out)", false, 0)
  if idx > 0 then r.TrackFX_CopyToTrack(tr, idx, tr, 0, true) end
  return 0
end

local function set_named(tr, fx, parm, val) r.TrackFX_SetNamedConfigParm(tr, fx, parm, tostring(val)) end

local function apply_track(tr)
  local fx = find_fx(tr)
  if fx.meter < 0 then fx.meter = ensure_meter_top(tr) end

  -- Live-Peak (0..1 -> -60..0dBFS)
  local ok, peak_norm = r.TrackFX_GetParam(tr, fx.meter, 0)
  local peak = (ok and peak_norm) or 0.3
  local peak_db = peak*60 - 60

  -- Drive-Skalierung
  local drive_scale = (peak_db <= -30) and 2.0 or (peak_db <= -20) and 1.3 or (peak_db <= -12) and 1.0 or 0.75
  local maps = load_param_maps()
  if fx.flavor >= 0 then
    local pcnt = r.TrackFX_GetNumParams(tr, fx.flavor)
    local _, fxn = r.TrackFX_GetFXName(tr, fx.flavor, "")
    local mapped = apply_mapped_drive(tr, fx.flavor, peak_db, maps, fxn)
    -- fine mapping extras
    if mapped then
      local ln=(fxn or ""):lower()
      if ln:find("totape") and maps and maps.airwindows and maps.airwindows.totape then
        cap_params(tr, fx.flavor, (maps.airwindows.totape.soft_caps and maps.airwindows.totape.soft_caps.match), (maps.airwindows.totape.soft_caps and maps.airwindows.totape.soft_caps.max))
        cap_params(tr, fx.flavor, (maps.airwindows.totape.headbump_caps and maps.airwindows.totape.headbump_caps.match), (maps.airwindows.totape.headbump_caps and maps.airwindows.totape.headbump_caps.max))
      end
      if ln:find("pressure") and maps and maps.airwindows and maps.airwindows.pressure and maps.airwindows.pressure.weights then
        -- optional: adjust drive/compress balance (heuristic)
        -- intentionally conservative â€“ handled in apply_mapped_drive scaling
      end
      if (ln:find("britpre") or ln:find("burier")) and maps and maps.analogobsession then
        link_output_to_input(tr, fx.flavor)
      end
    end
    for p=0, pcnt-1 do
      local _, pn = r.TrackFX_GetParamName(tr, fx.flavor, p, "")
      pn = (pn or ""):lower()
      if pn:find("drive") or pn:find("amount") then
        local _, cur = r.TrackFX_GetParam(tr, fx.flavor, p)
        local newv = math.max(0.0, math.min(1.0, cur * drive_scale))
        r.TrackFX_SetParam(tr, fx.flavor, p, newv)
      end
    end
  end

  -- Comp Bias (Attack/Release)
  if fx.comp >= 0 then
    local att, rel = 10, 150
    if     peak_db <= -24 then att,rel = att*1.25, rel*1.15
    elseif peak_db <= -14 then att,rel = att*1.10, rel*1.05
    else                      att,rel = att*0.90, rel*0.95 end
    set_named(tr, fx.comp, "ATTACK",  att)
    set_named(tr, fx.comp, "RELEASE", rel)
  end
end

r.Undo_BeginBlock()
local sel = r.CountSelectedTracks(0)
for i=0, sel-1 do apply_track(r.GetSelectedTrack(0,i)) end
r.Undo_EndBlock("DF95 IFLS Workbench - MicFX ParamApply v3.6 (LiveAware)", -1)
r.UpdateArrange()

-- DF95 ParamMap loader
local function load_param_maps()
  local p = reaper.GetResourcePath() .. "/Data/IFLS_Workbench/IFLS_Workbench_ParamMaps_AO_AW.json"
  local f = io.open(p,"rb"); if not f then return nil end
  local d = f:read("*all"); f:close()
  if reaper.JSON_Decode then return reaper.JSON_Decode(d) end
  return nil
end

local function match_any(name, patterns)
  name = (name or ""):lower()
  for _,p in ipairs(patterns or {}) do
    if name:find(p) then return true end
  end
  return false
end

local function apply_mapped_drive(tr, fxidx, peak_db, maps, fxname)
  if not maps then return false end
  local ln = (fxname or ""):lower()
  local group, key = nil, nil
  if ln:find("airwindows") or ln:find("console") or ln:find("channel") then group = "airwindows"
  elseif ln:find("analog obsession") or ln:find("analogobsession") or ln:find("ao") then group = "analogobsession" end

  if not group then return false end

  local function pick_key(mapgroup)
    for k,_ in pairs(mapgroup) do if ln:find(k) then return k end end
    return nil
  end

  key = pick_key(maps[group] or {}) ; if not key then return false end
  local m = maps[group][key]
  -- Drive scaling from peak
  local scale = (peak_db <= -30) and 2.0 or (peak_db <= -20) and 1.3 or (peak_db <= -12) and 1.0 or 0.75

  local pcnt = reaper.TrackFX_GetNumParams(tr, fxidx)
  for p=0, pcnt-1 do
    local _, pn = reaper.TrackFX_GetParamName(tr, fxidx, p, "")
    local pl = (pn or ""):lower()
    if match_any(pl, m.drive and m.drive.match or {}) then
      local _, cur = reaper.TrackFX_GetParam(tr, fxidx, p)
      local newv = math.max(0.0, math.min(1.0, cur * (m.drive.scale or 1.0) * scale))
      reaper.TrackFX_SetParam(tr, fxidx, p, newv)
    elseif match_any(pl, m.output and m.output.match or {}) then
      -- Output bleibt stabil; kleiner Auto-Trim bei starken Drives
      local _, cur = reaper.TrackFX_GetParam(tr, fxidx, p)
      local trim = (scale > 1.2) and -0.05 or (scale < 0.8) and +0.02 or 0.0
      local newv = math.max(0.0, math.min(1.0, cur + trim))
      reaper.TrackFX_SetParam(tr, fxidx, p, newv)
    end
  end

  return true
end

-- Fine-mapping helpers
local function cap_params(tr, fxidx, match_list, cap)
  if not match_list or not cap then return end
  local pc = reaper.TrackFX_GetNumParams(tr, fxidx)
  for p=0,pc-1 do
    local _, pn = reaper.TrackFX_GetParamName(tr, fxidx, p, "")
    local pl = (pn or ""):lower()
    for _,m in ipairs(match_list) do
      if pl:find(m) then
        local _,cur = reaper.TrackFX_GetParam(tr, fxidx, p)
        if cur > cap then reaper.TrackFX_SetParam(tr, fxidx, p, cap) end
      end
    end
  end
end

local function link_output_to_input(tr, fxidx)
  local pc = reaper.TrackFX_GetNumParams(tr, fxidx)
  local pin, pout = -1, -1
  for p=0,pc-1 do
    local _, pn = reaper.TrackFX_GetParamName(tr, fxidx, p, ""); pn=(pn or ""):lower()
    if pn:find("input") then pin = pin==-1 and p or pin end
    if pn:find("output") or pn:find("out") or pn:find("fader") then pout = pout==-1 and p or pout end
  end
  if pin>=0 and pout>=0 then
    local _, iv = reaper.TrackFX_GetParam(tr, fxidx, pin)
    -- maintain rough unity: if input raised a lot, counter trim output ~ half
    local trim = (iv-0.5)*0.5
    local _, ov = reaper.TrackFX_GetParam(tr, fxidx, pout)
    local nv = math.max(0, math.min(1, ov - trim))
    reaper.TrackFX_SetParam(tr, fxidx, pout, nv)
  end
end
