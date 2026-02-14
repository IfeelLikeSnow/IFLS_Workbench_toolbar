-- @description IFLS Workbench - Tools/IFLS_Export_FX_ParamCatalog_NoMidiCC_Toggles_VST3Preferred.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS: Export FX Param Catalog (No MIDI CC + Toggle Info + Prefer VST3)
-- @version 1.0
-- @author IFLS
-- @about
--   Scans installed FX via EnumInstalledFX(), prefers VST3 when duplicates exist,
--   instantiates each FX on a temp track, then exports parameter metadata:
--     - skips noisy "MIDI CC" params by name
--     - adds toggle info via TrackFX_GetParameterStepSizes()
--   Output: NDJSON + stats in:
--     <REAPER resource path>/Scripts/IFLS_Workbench/_ParamDumps/


local r = reaper

local SafeApply = require("IFLS_Workbench/Engine/IFLS_SafeApply")
local function esc(s)
  s = tostring(s or "")
  s = s:gsub("\\","\\\\"):gsub("\"","\\\""):gsub("\r","\\r"):gsub("\n","\\n")
  return s
end

local function json_any(v)
  local tv = type(v)
  if tv == "nil" then return "null"
  elseif tv == "boolean" then return v and "true" or "false"
  elseif tv == "number" then return tostring(v)
  elseif tv == "string" then return "\"" .. esc(v) .. "\""
  elseif tv == "table" then
    local is_arr = true
    local max_i = 0
    for k,_ in pairs(v) do
      if type(k) ~= "number" then is_arr = false break end
      if k > max_i then max_i = k end
    end
    if is_arr then
      local a = {}
      for i=1,max_i do a[#a+1] = json_any(v[i]) end
      return "[" .. table.concat(a, ",") .. "]"
    else
      local o = {}
      for k,val in pairs(v) do
        o[#o+1] = "\"" .. esc(k) .. "\":" .. json_any(val)
      end
      table.sort(o)
      return "{" .. table.concat(o, ",") .. "}"
    end
  end
  return "\"" .. esc(tostring(v)) .. "\""
end

local function append_line(path, s)
  local f = io.open(path, "a")
  if not f then return false end
  f:write(s); f:write("\n"); f:close()
end)
end

local function write_text(path, s)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(s); f:close()
  return true
end

local function mk_dir(path)
  r.RecursiveCreateDirectory(path, 0)
end

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function is_noise_param(name)
  if not name or name == "" then return true end
  local n = name:lower()
  if n:match("^midi%s+cc") then return true end
  if n:find("midi cc", 1, true) then return true end
  if n:match("^midi%s+pc") then return true end
  if n:match("^midi%s+pitch") then return true end
  return false
end

local function split_prefix(name)
  local p, rest = name:match("^([%w%+%-]+):%s*(.*)$")
  if p then return p, rest end
  return "", name
end

local function base_key(name)
  local _, rest = split_prefix(name)
  rest = rest:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$","")
  return rest:lower()
end

local function rank(prefix)
  prefix = (prefix or ""):upper()
  if prefix == "VST3I" then return 4 end
  if prefix == "VST3" then return 3 end
  if prefix == "VSTI" then return 2 end
  if prefix == "VST" then return 1 end
  return 0
end

local function prefer_vst3(entries)
  local groups = {}
  local others = {}
  for _,e in ipairs(entries) do
    local tp = split_prefix(e.name)
    local prefix = tp
    prefix = (prefix or "")
    if prefix == "VST" or prefix == "VST3" or prefix == "VSTi" or prefix == "VST3i" then
      local key = base_key(e.name)
      groups[key] = groups[key] or {}
      table.insert(groups[key], e)
    else
      table.insert(others, e)
    end
  end

  local out = {}
  for _,list in pairs(groups) do
    local best, best_r = nil, -1
    for _,e in ipairs(list) do
      local p = (split_prefix(e.name) or ""):upper()
      local rnk = rank(p)
      if rnk > best_r then best_r = rnk; best = e end
    end
    if best then table.insert(out, best) end
  end
  for _,e in ipairs(others) do table.insert(out, e) end
  table.sort(out, function(a,b) return (a.name or ""):lower() < (b.name or ""):lower() end)
  return out
end

local function load_lines_set(path)
  local set = {}
  local f = io.open(path, "r")
  if not f then return set end
  for line in f:lines() do
    if line and line ~= "" then set[line] = true end
  end
  f:close()
  return set
end

local function load_blacklist(path)
  local bl = {}
  local f = io.open(path, "r")
  if not f then return bl end
  for line in f:lines() do
    line = (line or ""):gsub("^%s+",""):gsub("%s+$","")
    if line ~= "" and not line:match("^#") then
      bl[#bl+1] = line:lower()
    end
  end
  f:close()
  return bl
end

local function is_blacklisted(name, bl)
  local n = (name or ""):lower()
  for _,sub in ipairs(bl) do
    if sub ~= "" and n:find(sub, 1, true) then return true end
  end
  return false
end

local function main()
  if not r.EnumInstalledFX then
    r.MB("EnumInstalledFX not available. Use REAPER 7.x.", "IFLS Param Catalog", 0)
    return
  end

  local rp = r.GetResourcePath()
  local dump_dir = rp .. "/Scripts/IFLS_Workbench/_ParamDumps"
  mk_dir(dump_dir)

  local out_ndjson = dump_dir .. "/ifls_fx_param_catalog.ndjson"
  local out_done   = dump_dir .. "/ifls_fx_param_catalog_done.txt"
  local out_fail   = dump_dir .. "/ifls_fx_param_catalog_fail.ndjson"
  local out_stats  = dump_dir .. "/ifls_fx_param_catalog_stats.json"
  local blacklist_path = dump_dir .. "/crash_blacklist.txt"

  local done = load_lines_set(out_done)
  local blacklist = load_blacklist(blacklist_path)

  -- build list
  local fx = {}
  local i = 0
  while true do
    local ok, name, ident = r.EnumInstalledFX(i)
    if not ok then break end
    fx[#fx+1] = {name=name or "", ident=ident or ""}
    i = i + 1
  end
  fx = prefer_vst3(fx)

  -- create temp track
  return SafeApply.run("IFLS: IFLS Export FX ParamCatalog NoMidiCC Toggles VST3Preferred", function()
local tr_idx = r.CountTracks(0)
  r.InsertTrackAtIndex(tr_idx, true)
  local tr = r.GetTrack(0, tr_idx)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", "IFLS FX PARAM SCAN (TEMP)", true)
  r.SetMediaTrackInfo_Value(tr, "B_SHOWINTCP", 0)
  r.SetMediaTrackInfo_Value(tr, "B_SHOWINMIXER", 0)
  r.SetMediaTrackInfo_Value(tr, "B_MUTE", 1)

  local scanned, skipped, failed = 0, 0, 0
  local started = now_iso()

  local function clear_fx()
    local n = r.TrackFX_GetCount(tr)
    for k=n-1,0,-1 do r.TrackFX_Delete(tr, k) end
  end

  local function key_for(e)
    return (e.ident and e.ident ~= "" and e.ident) or e.name
  end

  for _,e in ipairs(fx) do
    local k = key_for(e)
    if done[k] or is_blacklisted(e.name, blacklist) then
      skipped = skipped + 1
    else
      clear_fx()
      local fxidx = r.TrackFX_AddByName(tr, e.name, false, -1)
      if fxidx < 0 then
        failed = failed + 1
        append_line(out_fail, json_any({when=now_iso(), fx_name=e.name, fx_key=k, error="AddByName failed"}))
        append_line(out_done, k); done[k]=true
      else
        local okn, real = r.TrackFX_GetFXName(tr, fxidx, "")
        local num = r.TrackFX_GetNumParams(tr, fxidx)
        local params = {}
        for p=0,num-1 do
          local _, pname = r.TrackFX_GetParamName(tr, fxidx, p, "")
          if not is_noise_param(pname) then
            local norm = r.TrackFX_GetParamNormalized(tr, fxidx, p)
            local rv, minv, maxv, midv = r.TrackFX_GetParamEx(tr, fxidx, p, 0, 0, 0)
            local okStep, step, small, large, istoggle = r.TrackFX_GetParameterStepSizes(tr, fxidx, p, 0,0,0,false)
            params[#params+1] = {
              idx=p, name=pname, norm=norm,
              raw=rv, min=minv, max=maxv, mid=midv,
              is_toggle=(okStep and istoggle) and true or false,
              step=okStep and step or nil, smallstep=okStep and small or nil, largestep=okStep and large or nil
            }
          end
        end
        append_line(out_ndjson, json_any({
          when=now_iso(),
          fx_browser_name=e.name,
          fx_resolved_name=(okn and real) or e.name,
          fx_key=k,
          ident=e.ident,
          param_count_total=num,
          param_count_exported=#params,
          params=params
        }))
        append_line(out_done, k); done[k]=true
        scanned = scanned + 1
      end
    end
    -- keep UI responsive on huge lists
    if (scanned + skipped + failed) % 25 == 0 then r.defer(function() end) end
  end

  -- cleanup temp track
  r.DeleteTrack(tr)

  r.UpdateArrange()
  write_text(out_stats, json_any({
    started=started, finished=now_iso(),
    total_after_prefer_vst3=#fx,
    scanned=scanned, skipped=skipped, failed=failed,
    out_ndjson=out_ndjson, out_fail=out_fail, out_done=out_done,
    blacklist=blacklist_path
  }))

  r.MB(
    "Done.\n\nScanned: " .. scanned .. "\nSkipped: " .. skipped .. "\nFailed: " .. failed ..
    "\n\nOutput:\n" .. out_ndjson .. "\n" .. out_stats,
    "IFLS Param Catalog", 0
  )
end

main()
