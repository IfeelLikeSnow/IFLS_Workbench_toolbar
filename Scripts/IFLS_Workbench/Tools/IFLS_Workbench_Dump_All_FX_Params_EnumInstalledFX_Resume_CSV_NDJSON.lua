-- @description IFLS Workbench: Dump All FX Params (EnumInstalledFX, Resume, CSV+NDJSON)
-- @version 0.2.4
-- @author IFLS (ported from IFLSWB)
-- @about
--   Scans installed FX via EnumInstalledFX() and instantiates them on a temporary track to read parameters.
--   Outputs:
--     1) CSV (summary)  2) NDJSON (one FX per line, easy for big datasets)
--   Resume: keeps a progress file so you can continue after cancel/crash.
--   Notes:
--     - Some plugins may open UI, require license dialogs, or fail to instantiate.
--     - For REAPER versions without EnumInstalledFX(), the script will stop (this tool targets REAPER 7+).
--
--   Repository: IFLS Workbench Toolbar

local r = reaper

----------------------------------------------------------------
-- USER OPTIONS
----------------------------------------------------------------
-- If true, NEVER scan VST2/VST (.dll) entries. (VST3-only world)
-- If false (default), we still scan VST2 if no matching VST3 exists.
local STRICT_ONLY_VST3 = false

-- If true, also dump a lightweight plugin-level JSON array file (plugins.json).
-- Warning: can be huge for big systems; NDJSON is the robust default.
local ALSO_WRITE_PLUGINS_JSON_ARRAY = false

-- Safety: skip plugins with absurd param counts (rare, but prevents runaway)
local MAX_PARAMS_PER_PLUGIN = 50000

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end

local function file_exists(p)
  local f = io.open(p, "r")
  if f then f:close() return true end
  return false
end

local function read_file(p)
  local f = io.open(p, "r")
  if not f then return nil end
  local c = f:read("*a")
  f:close()
  return c
end

local function write_file(p, content)
  local f = io.open(p, "w")
  if not f then return false end
  f:write(content or "")
  f:close()
  return true
end

local function json_escape(s)
  s = tostring(s or "")
  s = s:gsub("\\","\\\\"):gsub("\"","\\\""):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")
  return s
end

local function csv_escape(s)
  s = tostring(s or "")
  if s:find("[\",\n\r]") then
    s = s:gsub("\"","\"\"")
    return "\"" .. s .. "\""
  end
  return s
end

-- Split "VST3: Foo" -> ("VST3", "Foo")
local function split_prefix(name)
  name = trim(name)
  local pref, rest = name:match("^([%w%+%-_]+)%s*:%s*(.+)$")
  if pref and rest then return trim(pref), trim(rest) end
  return "", name
end

-- Normalization for display-base name
local function normalize_base(display_name)
  local pref, rest = split_prefix(display_name)
  local s = rest
  -- remove vendor/arch blocks in parentheses to help matching (e.g. "(UADx)", "(x64)")
  s = s:gsub("%s*%b()", "")
  s = s:gsub("%s+"," ")
  s = s:gsub("%s*%((x64|64%-bit|64bit)%)%s*$","")
  return trim(s), trim(pref)
end

-- Normalize ident to help decide if VST2 and VST3 represent the "same plugin family"
-- Heuristic: keep only alphanumerics, drop obvious format tags.
local function normalize_ident(ident)
  ident = tostring(ident or "")
  local s = ident:lower()
  s = s:gsub("vst3",""):gsub("vst2",""):gsub("vst","")
  s = s:gsub("clap",""):gsub("au",""):gsub("js",""):gsub("lv2",""):gsub("dx","")
  s = s:gsub("[^%w]+","")
  return s
end

local function pref_rank(fxtype)
  fxtype = (fxtype or ""):upper()
  if fxtype == "VST3" then return 100 end
  if fxtype == "CLAP" then return 90 end
  if fxtype == "AU" then return 80 end
  if fxtype == "LV2" then return 70 end
  if fxtype == "VST" or fxtype == "VST2" then return 60 end
  if fxtype == "JS" or fxtype == "JSFX" then return 50 end
  if fxtype == "DX" then return 40 end
  return 10
end

----------------------------------------------------------------
-- Progress / Resume
----------------------------------------------------------------
local function load_progress(path)
  local c = read_file(path)
  if not c or c == "" then return {} end
  -- Very small JSON parser for {"done":{"ident":true,...}}
  local done = {}
  for ident in c:gmatch("\"([^\"]+)\"%s*:%s*true") do
    done[ident] = true
  end
  return done
end

local function save_progress(path, done_tbl)
  -- write minimal JSON
  local parts = {"{\"done\":{"}
  local first = true
  for ident, v in pairs(done_tbl) do
    if v then
      if not first then parts[#parts+1] = "," end
      first = false
      parts[#parts+1] = string.format("%q:true", ident)
    end
  end
  parts[#parts+1] = "}}"
  write_file(path, table.concat(parts))
end

----------------------------------------------------------------
-- Enumerate installed FX (REAPER-recognized)
----------------------------------------------------------------
-- Refresh JSFX list/metadata (supported by REAPER via idx=-1 in newer builds)
pcall(function() r.EnumInstalledFX(-1) end)

local installed = {}
local i = 0
while true do
  local ok, name, ident = r.EnumInstalledFX(i)
  if not ok then break end
  installed[#installed+1] = { name = name, ident = ident, idx = i }
  i = i + 1
end

if #installed == 0 then
  r.MB("EnumInstalledFX returned 0 entries.\nUpdate REAPER or check ReaScript support.", "IFLSWB Param Dump V3", 0)
  return
end

----------------------------------------------------------------
-- Strong matching + dedupe:
-- - Group by base name
-- - Within VST family: if VST3 and VST2 both exist and appear same (ident match heuristic), keep only VST3
-- - If STRICT_ONLY_VST3, drop VST2/VST completely
-- - Non-VST: keep all
----------------------------------------------------------------
local groups = {}  -- base -> {vst3={}, vst2={}, other={}}
for _, e in ipairs(installed) do
  local base, pref = normalize_base(e.name)
  local p = (pref or ""):upper()
  if not groups[base] then groups[base] = { vst3 = {}, vst2 = {}, other = {} } end
  if p == "VST3" then
    groups[base].vst3[#groups[base].vst3+1] = e
  elseif p == "VST" or p == "VST2" then
    groups[base].vst2[#groups[base].vst2+1] = e
  else
    groups[base].other[#groups[base].other+1] = e
  end
end

local final_list = {}

local function pick_best_vst3(list)
  -- if multiple VST3 entries share base, keep all (rare). We keep all by ident distinct.
  -- You can change this to "pick best by rank" but rank is identical here.
  return list
end

local function appears_same_plugin(vst2_ident, vst3_ident)
  local a = normalize_ident(vst2_ident)
  local b = normalize_ident(vst3_ident)
  if a == "" or b == "" then return false end
  if a == b then return true end
  -- fallback: large overlap
  if (#a >= 8 and #b >= 8) then
    if a:find(b, 1, true) or b:find(a, 1, true) then return true end
  end
  return false
end

for base, g in pairs(groups) do
  -- Add non-VST always
  for _, e in ipairs(g.other) do final_list[#final_list+1] = e end

  -- Handle VST family
  local vst3 = g.vst3
  local vst2 = g.vst2

  if #vst3 > 0 then
    -- Always keep VST3
    local keep_vst3 = pick_best_vst3(vst3)
    for _, e in ipairs(keep_vst3) do final_list[#final_list+1] = e end

    if not STRICT_ONLY_VST3 and #vst2 > 0 then
      -- Keep only those VST2 entries that do NOT appear to match any kept VST3 ident
      for _, e2 in ipairs(vst2) do
        local matched = false
        for _, e3 in ipairs(keep_vst3) do
          if appears_same_plugin(e2.ident, e3.ident) then matched = true break end
        end
        if not matched then
          -- VST2 seems genuinely different -> keep it
          final_list[#final_list+1] = e2
        end
      end
    end
  else
    -- No VST3 exists for this base -> keep VST2 unless strict
    if not STRICT_ONLY_VST3 then
      for _, e in ipairs(vst2) do final_list[#final_list+1] = e end
    end
  end
end

table.sort(final_list, function(a,b) return (a.name:lower() < b.name:lower()) end)

----------------------------------------------------------------
-- Prepare temp track & outputs
----------------------------------------------------------------
r.Undo_BeginBlock()
r.PreventUIRefresh(1)

local proj = 0
local track_count = r.CountTracks(proj)
r.InsertTrackAtIndex(track_count, true)
local tmp_tr = r.GetTrack(proj, track_count)
r.GetSetMediaTrackInfo_String(tmp_tr, "P_NAME", "__IFLSWB_PARAMSCAN_TMP__", true)

local res = r.GetResourcePath()
local out_dir = res .. "/Scripts/IFLSWB_ParamDump"
r.RecursiveCreateDirectory(out_dir, 0)

local plugins_csv = out_dir .. "/plugins.csv"
local params_csv  = out_dir .. "/params.csv"
local plugins_ndj = out_dir .. "/plugins.ndjson"
local failures_tx = out_dir .. "/failures.txt"
local progress_js = out_dir .. "/progress.json"
local plugins_jsa = out_dir .. "/plugins.json" -- optional array file

local done = load_progress(progress_js)

local f_plugins = io.open(plugins_csv, file_exists(plugins_csv) and "a" or "w")
local f_params  = io.open(params_csv,  file_exists(params_csv)  and "a" or "w")
local f_ndjson  = io.open(plugins_ndj, file_exists(plugins_ndj) and "a" or "w")
local f_fail    = io.open(failures_tx, file_exists(failures_tx) and "a" or "w")

if not f_plugins or not f_params or not f_ndjson or not f_fail then
  r.DeleteTrack(tmp_tr)
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock("IFLSWB Param Dump V3 (failed open files)", -1)
  r.MB("Could not open output files in:\n" .. out_dir, "IFLSWB Param Dump V3", 0)
  return
end

-- Write headers if new files
if (not file_exists(plugins_csv)) or (r.GetFileSize and r.GetFileSize(plugins_csv) == 0) then
  f_plugins:write("fx_display,fx_ident,fx_type,base_name,loaded_ok,load_name_used,param_count\n")
end
if (not file_exists(params_csv)) or (r.GetFileSize and r.GetFileSize(params_csv) == 0) then
  f_params:write("fx_ident,fx_display,fx_type,base_name,param_index,param_ident,param_name,formatted,val,min,max,mid,step_small,step_large,is_toggle\n")
end

----------------------------------------------------------------
-- Loader / Parameter dump
----------------------------------------------------------------
local function clear_tmp_fx()
  local fxcount = r.TrackFX_GetCount(tmp_tr)
  for fx = fxcount-1, 0, -1 do r.TrackFX_Delete(tmp_tr, fx) end
end

local function try_add_fx(display_name)
  -- 1) as-is
  local idx = r.TrackFX_AddByName(tmp_tr, display_name, false, -1)
  if idx >= 0 then return idx, display_name end

  -- 2) prefix + base
  local base, pref = normalize_base(display_name)
  if pref ~= "" then
    local c = pref .. ": " .. base
    idx = r.TrackFX_AddByName(tmp_tr, c, false, -1)
    if idx >= 0 then return idx, c end
  end

  -- 3) if VST2, try VST3 with same base
  local _, pref0 = normalize_base(display_name)
  local pU = (pref0 or ""):upper()
  if pU == "VST" or pU == "VST2" then
    local c = "VST3: " .. base
    idx = r.TrackFX_AddByName(tmp_tr, c, false, -1)
    if idx >= 0 then return idx, c end
  end

  -- 4) base only
  local base_only = (select(1, normalize_base(display_name)))
  idx = r.TrackFX_AddByName(tmp_tr, base_only, false, -1)
  if idx >= 0 then return idx, base_only end

  return -1, display_name
end

local function get_param_ident(track, fx, p)
  if r.TrackFX_GetParamIdent then
    local ok, ident = r.TrackFX_GetParamIdent(track, fx, p, "")
    if ok then return ident end
  end
  return ""
end

local function get_formatted(track, fx, p)
  if r.TrackFX_GetFormattedParamValue then
    local ok, s = r.TrackFX_GetFormattedParamValue(track, fx, p, "")
    if ok then return s end
  end
  return ""
end

local function get_steps(track, fx, p)
  if r.TrackFX_GetParameterStepSizes then
    local ok, step, small, large, istoggle = r.TrackFX_GetParameterStepSizes(track, fx, p)
    if ok then return step, small, large, istoggle end
  end
  return "", "", "", ""
end


----------------------------------------------------------------
-- Scan
----------------------------------------------------------------
local total = #final_list
local scanned = 0
local skipped = 0
local failed = 0

for _, fx in ipairs(final_list) do
  local key = tostring(fx.ident or "")
  if key == "" then key = tostring(fx.name or "") end
  if done[key] then
    skipped = skipped + 1
  else
    clear_tmp_fx()

    local fx_index, used_name = try_add_fx(fx.name)
    local base, pref = normalize_base(used_name)
    local fxtype = select(1, split_prefix(used_name))
    if fxtype == "" then fxtype = pref end

    if fx_index < 0 then
      failed = failed + 1
      f_fail:write(("FAILED_LOAD: %s | ident=%s\n"):format(fx.name, tostring(key)))
      f_plugins:write(table.concat({
        csv_escape(fx.name), csv_escape(key), csv_escape(fxtype), csv_escape(base),
        "0", csv_escape(used_name), "0"
      }, ",") .. "\n")
      done[key] = true
      save_progress(progress_js, done)
    else
      local num = r.TrackFX_GetNumParams(tmp_tr, fx_index)
      if num > MAX_PARAMS_PER_PLUGIN then
        f_fail:write(("SKIP_TOO_MANY_PARAMS: %s | ident=%s | params=%d\n"):format(used_name, tostring(key), num))
        f_plugins:write(table.concat({
          csv_escape(fx.name), csv_escape(key), csv_escape(fxtype), csv_escape(base),
          "0", csv_escape(used_name), tostring(num)
        }, ",") .. "\n")
        done[key] = true
        save_progress(progress_js, done)
      else
        -- plugin record
        f_plugins:write(table.concat({
          csv_escape(fx.name), csv_escape(key), csv_escape(fxtype), csv_escape(base),
          "1", csv_escape(used_name), tostring(num)
        }, ",") .. "\n")
        f_plugins:flush()

        -- NDJSON record (one line per plugin)
        f_ndjson:write(string.format(
          "{\"fx_display\":\"%s\",\"fx_ident\":\"%s\",\"fx_type\":\"%s\",\"base_name\":\"%s\",\"paramCount\":%d}\n",
          json_escape(used_name), json_escape(key), json_escape(fxtype), json_escape(base), num
        ))
        f_ndjson:flush()

        -- params (one line per param)
        for p = 0, num-1 do
          local _, pname = r.TrackFX_GetParamName(tmp_tr, fx_index, p, "")
          local pident = get_param_ident(tmp_tr, fx_index, p)
          local fmt = get_formatted(tmp_tr, fx_index, p)
          local val = r.TrackFX_GetParam(tmp_tr, fx_index, p)
          local ok, minv, maxv, midv = r.TrackFX_GetParamEx(tmp_tr, fx_index, p)
          local _step, small, large, istoggle = get_steps(tmp_tr, fx_index, p)

          f_params:write(table.concat({
            csv_escape(key),
            csv_escape(used_name),
            csv_escape(fxtype),
            csv_escape(base),
            tostring(p),
            csv_escape(pident),
            csv_escape(pname),
            csv_escape(fmt),
            string.format("%.10f", val),
            ok and string.format("%.10f", minv) or "",
            ok and string.format("%.10f", maxv) or "",
            ok and string.format("%.10f", midv) or "",
            tostring(small or ""),
            tostring(large or ""),
            tostring(istoggle or "")
          }, ",") .. "\n")
        end
        f_params:flush()

        done[key] = true
        save_progress(progress_js, done)

        scanned = scanned + 1
      end
    end
  end

  -- keep UI responsive on big rigs
  if (scanned + skipped + failed) % 50 == 0 then
    r.UpdateArrange()
  end
end

----------------------------------------------------------------
-- Optional plugins.json array (built from plugins.ndjson)
----------------------------------------------------------------
if ALSO_WRITE_PLUGINS_JSON_ARRAY then
  local nd = read_file(plugins_ndj) or ""
  local arr = {"[\n"}
  local first = true
  for line in nd:gmatch("[^\r\n]+") do
    if trim(line) ~= "" then
      if not first then arr[#arr+1] = ",\n" end
      first = false
      arr[#arr+1] = "  " .. line
    end
  end
  arr[#arr+1] = "\n]\n"
  write_file(plugins_jsa, table.concat(arr))
end

----------------------------------------------------------------
-- Cleanup
----------------------------------------------------------------
f_plugins:close()
f_params:close()
f_ndjson:close()
f_fail:close()

r.DeleteTrack(tmp_tr)
r.PreventUIRefresh(-1)
r.Undo_EndBlock("IFLSWB Param Dump V3", -1)

r.MB(
  ("Done.\nTotal candidates: %d\nScanned: %d\nSkipped(resume): %d\nFailed: %d\n\nOutput folder:\n%s")
  :format(total, scanned, skipped, failed, out_dir),
  "IFLSWB Param Dump V3",
  0
)
