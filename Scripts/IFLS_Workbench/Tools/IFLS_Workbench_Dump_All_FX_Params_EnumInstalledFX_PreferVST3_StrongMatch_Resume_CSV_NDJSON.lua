-- @description IFLS Workbench - Tools/IFLS_Workbench_Dump_All_FX_Params_EnumInstalledFX_PreferVST3_StrongMatch_Resume_CSV_NDJSON.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: IFLS_Workbench_Dump_All_FX_Params_EnumInstalledFX_PreferVST3_StrongMatch_Resume_CSV_NDJSON
-- @version 1.0.0

ï»¿--@description IFLS Workbench: Dump ALL FX params (EnumInstalledFX, prefer VST3, strong match, resume, CSV+NDJSON)
-- @version 0.4.4
--@author IFLS (ported from DF95)
--@about
--  Enumerates all REAPER-recognized FX via EnumInstalledFX().
--  Stronger matching + dedupe: prefers VST3 when VST2 and VST3 appear to be the same plugin.

--  Writes: plugins.csv, params.csv, plugins.ndjson, failures.txt, progress.json
--  Resume-safe: already dumped fx_ident entries are skipped on next runs.
--
--  Output folder: REAPER resource path / Scripts/IFLS_Workbench/_ParamDumps/

local r = reaper

local SafeApply = require("IFLS_Workbench/Engine/IFLS_SafeApply")
-- Paths (declared early so helper closures capture locals)
local progress_js, progress_done_txt, cursor_txt

----------------------------------------------------------------
-- USER OPTIONS

-- Safety / Debug switches (recommended defaults)
local ENUM_ONLY        = false   -- true: only enumerate installed FX, do NOT instantiate (no crash risk)
local SCAN_VST3        = true
local SCAN_VST2        = true
local SCAN_JSFX        = true
local SCAN_CLAP        = false   -- CLAP can be crash-prone in some setups; enable if you want
local SCAN_AU          = true
local SCAN_DX          = true

-- If REAPER crashes, bisect by narrowing the range:
local START_FROM_INDEX = 0       -- start scan at this installed-FX index (EnumInstalledFX)
local MAX_NEW_PER_PASS  = 100     -- number of NEW plugins to process per pass (0 = no limit)
local AUTO_CONTINUE     = true    -- automatically start the next pass until all are done
local SHOW_FINAL_SUMMARY = true   -- show a summary message when finished (or when AUTO_CONTINUE=false)
local MAX_TO_SCAN      = 0       -- (legacy, unused) kept for compatibility

-- Skip patterns (Lua patterns, case-insensitive via :lower())
local SKIP_NAME_PATTERNS = {
  -- "ilok", "pace", "license", "trial",
}

local blacklist_set = nil

local function should_skip_fx(fx)
  local n = (fx.name or ""):lower()
  if n == "" then return true end
  local t = (fx.fx_type or ""):upper()
  if (t == "VST3" and not SCAN_VST3) or (t == "VST" and not SCAN_VST2) or (t == "JS" and not SCAN_JSFX)
     or (t == "CLAP" and not SCAN_CLAP) or (t == "AU" and not SCAN_AU) or (t == "DX" and not SCAN_DX) then
end)
  end

  -- skip explicit blacklist entries
  if blacklist_set then
    if blacklist_set[fx.ident or ""] or blacklist_set[fx.name or ""] or blacklist_set[fx.display or ""] then
      return true
    end
  end

  for _,pat in ipairs(SKIP_NAME_PATTERNS) do
    if pat ~= "" and n:find(pat:lower()) then return true end
  end
  return false
end


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


local function open_append_with_header(path, header_line)
  -- Open in append/update mode; write header only if file is empty.
  local f = io.open(path, "a+")
  if not f then return nil end
  local cur = f:seek()
  local size = f:seek("end")
  if size == 0 and header_line and header_line ~= "" then
    f:write(header_line)
    f:flush()
  end
  f:seek("end")
  return f
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


-- Progress helpers (append-only done.txt)
local function load_done_set()
  local done = {}

  -- 1) preferred: done.txt (one key per line)
  local c = read_file(progress_done_txt)
  if c and c ~= "" then
    for line in c:gsub("\r",""):gmatch("([^\n]+)") do
      line = (line or ""):gsub("^%s+",""):gsub("%s+$","")
      if line ~= "" then done[line] = true end
    end
  end

  -- 2) legacy import: progress.json (small JSON with {"done":{"key":true,...}})
  local j = read_file(progress_js)
  if j and j ~= "" then
    for ident in j:gmatch("\"([^\"]+)\"%s*:%s*true") do
      if ident and ident ~= "" then done[ident] = true end
    end
  end

  return done
end

local function append_done_key(key)
  local f = io.open(progress_done_txt, "a")
  if not f then return false end
  f:write(key, "\n")
  f:close()
  return true
end

local function mark_done(done_tbl, key)
  if not key or key == "" then return end
  if not done_tbl[key] then
    done_tbl[key] = true
    append_done_key(key)
  end
end

local function load_cursor()
  local c = read_file(cursor_txt)
  if not c or c == "" then return nil end
  local n = tonumber(c:match("(%d+)"))
  return n
end

local function save_cursor(n)
  if not n then return end
  write_file(cursor_txt, tostring(math.floor(n)))
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
  r.MB("EnumInstalledFX returned 0 entries.\nUpdate REAPER or check ReaScript support.", "DF95 Param Dump V3", 0)
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
return SafeApply.run("IFLS: IFLS Workbench Dump All FX Params EnumInstalledFX PreferVST3 StrongMatch Resume CSV NDJSON", function()
local proj = 0
local track_count = r.CountTracks(proj)
r.InsertTrackAtIndex(track_count, true)
local tmp_tr = r.GetTrack(proj, track_count)
r.GetSetMediaTrackInfo_String(tmp_tr, "P_NAME", "__DF95_PARAMSCAN_TMP__", true)

local res = r.GetResourcePath()
local out_dir = res .. "/Scripts/IFLS_Workbench/_ParamDumps"

local current_fx_path = out_dir .. "/current_fx.txt"
local crash_blacklist_path = out_dir .. "/crash_blacklist.txt"
local user_blacklist_path  = out_dir .. "/user_blacklist.txt"


local function load_blacklist_set()
  local set = {}
  local function load_file(path)
    local c = read_file(path)
    if not c or c == "" then return end
    for line in c:gsub("\r",""):gmatch("([^\n]+)") do
      -- accept "idx<TAB>ident<TAB>name" or just "ident" / "name"
      local a,b,d = line:match("^(.-)	(.-)	(.*)$")
      if b and b ~= "" then set[b] = true end
      if d and d ~= "" then set[d] = true end
      if not b and line ~= "" then set[line] = true end
    end
  end
  load_file(crash_blacklist_path)
  load_file(user_blacklist_path)
  return set
end



local function write_current_fx(info)
  -- info = {idx=, ident=, name=}
  local line = string.format("%s\t%s\t%s\n", tostring(info.idx or ""), tostring(info.ident or ""), tostring(info.name or ""))
  write_file(current_fx_path, line) -- overwrite
end

local function read_current_fx()
  local c = read_file(current_fx_path)
  if not c or c == "" then return nil end
  c = c:gsub("\r",""):gsub("\n","")
  local a,b,d = c:match("^(.-)\t(.-)\t(.*)$")
  if not a then return nil end
  return { idx = tonumber(a) or -1, ident = b, name = d }
end

local function clear_current_fx()
  write_file(current_fx_path, "")
end


r.RecursiveCreateDirectory(out_dir, 0)

local plugins_csv = out_dir .. "/plugins.csv"
local params_csv  = out_dir .. "/params.csv"
local plugins_ndj = out_dir .. "/plugins.ndjson"
local failures_tx = out_dir .. "/failures.txt"
progress_js       = out_dir .. "/progress.json"  -- legacy (read-only / optional)
progress_done_txt = out_dir .. "/done.txt"       -- append-only progress
cursor_txt        = out_dir .. "/cursor.txt"     -- resume cursor (optional)
local plugins_jsa = out_dir .. "/plugins.json" -- optional array file

local done = load_done_set()
blacklist_set = load_blacklist_set()


local f_plugins = open_append_with_header(plugins_csv, "fx_display,fx_ident,fx_type,base_name,loaded_ok,load_name_used,param_count\n")
local f_params  = open_append_with_header(params_csv,  "fx_ident,fx_display,fx_type,base_name,param_index,param_ident,param_name,formatted,val,min,max,mid,step_small,step_large,is_toggle\n")
local f_ndjson  = io.open(plugins_ndj, file_exists(plugins_ndj) and "a" or "w")
local f_fail    = io.open(failures_tx, file_exists(failures_tx) and "a" or "w")

if not f_plugins or not f_params or not f_ndjson or not f_fail then
  r.DeleteTrack(tmp_tr)
  ", -1)
  r.MB("Could not open output files in:\n" .. out_dir, "DF95 Param Dump V3", 0)
  return
end

-- headers handled by open_append_with_header()

-- Crash-safe: if REAPER crashed last run, current_fx.txt will still contain the last attempted FX.
-- We persistently blacklist that FX by writing it into progress.json immediately,
-- so we don't keep re-crashing on the same one.
do
  local crashed = read_current_fx()
  if crashed and ((crashed.ident and crashed.ident ~= "") or (crashed.name and crashed.name ~= "")) then
    local crash_key = tostring(crashed.ident or "")
    if crash_key == "" then crash_key = tostring(crashed.name or "") end
    if crash_key ~= "" and not done[crash_key] then
      mark_done(done, crash_key) -- skip in this and future runs
      -- save_progress disabled (using done.txt)

      f_fail:write(string.format("CRASH_LAST_RUN\tidx=%s\tident=%s\tname=%s\n",
        tostring(crashed.idx or ""), tostring(crashed.ident or ""), tostring(crashed.name or "")))
      f_fail:flush()

      local line = string.format("%s\t%s\t%s\n", tostring(crashed.idx or ""), tostring(crashed.ident or ""), tostring(crashed.name or ""))
      local f = io.open(crash_blacklist_path, "a")
      if f then f:write(line) f:close() end

      if blacklist_set then
        blacklist_set[crash_key] = true
        if crashed.name and crashed.name ~= "" then blacklist_set[crashed.name] = true end
      end

      r.MB("Last run crashed while loading:\n\n" .. tostring(crash_key) .. "\n\nIt was added to crash_blacklist.txt and progress.json.\nRun the script again to continue scanning.", "IFLS Workbench Param Dump", 0)
    end
  end
  clear_current_fx() -- clear marker (we only need it once)
end


----------------------------------------------------------------
-- Loader / Parameter dump
----------------------------------------------------------------
local function clear_tmp_fx()
  local fxcount = r.TrackFX_GetCount(tmp_tr)
  for fx = fxcount-1, 0, -1 do r.TrackFX_Delete(tmp_tr, fx) end
end

local function try_add_fx(track, fxname, fxdisplay, fxtype, basename)
  -- TrackFX_AddByName expects fxname as string; guard against userdata mixups.
  if not track then return false, -1, "NO_TRACK" end
  if type(fxname) ~= "string" then
    return false, -1, "BAD_FXNAME_TYPE_" .. tostring(type(fxname))
  end
  if fxname == "" then return false, -1, "EMPTY_FXNAME" end

  -- Already prefixed? e.g. "VST3: ..." / "VST: ..." / "CLAP: ..."
  local has_prefix = fxname:match("^[A-Z0-9]+:%s")
  local candidates = {}
  if has_prefix then
    candidates = { fxname }
  else
    -- Try preferred order based on fxtype if provided
    if fxtype == "VST3" then
      candidates = { "VST3: "..fxname, "VST: "..fxname, "CLAP: "..fxname, "JS: "..fxname, fxname }
    elseif fxtype == "VST" then
      candidates = { "VST: "..fxname, "VST3: "..fxname, "CLAP: "..fxname, "JS: "..fxname, fxname }
    elseif fxtype == "CLAP" then
      candidates = { "CLAP: "..fxname, "VST3: "..fxname, "VST: "..fxname, fxname }
    elseif fxtype == "JS" then
      candidates = { "JS: "..fxname, fxname }
    else
      candidates = { "VST3: "..fxname, "VST: "..fxname, "CLAP: "..fxname, "JS: "..fxname, fxname }
    end
  end

  for _, name in ipairs(candidates) do
    local idx = r.TrackFX_AddByName(track, name, false, -1000)
    if idx and idx >= 0 then
      return true, idx, name
    end
  end
  return false, -1, "NOT_FOUND"
end



local function get_param_name(track, fx, p)
  local ok, name = r.TrackFX_GetParamName(track, fx, p, "")
  if ok and name and name ~= "" then return name end
  return ""
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
local scanned = 0           -- NEW processed (incl. failures) this run
local skipped = 0           -- resume/filtered/empty keys this run
local failed = 0            -- load failures this run
local new_budget = tonumber(MAX_NEW_PER_PASS) or 0
local pass_limit_reached = false

local function make_key(fx)
  local k = tostring(fx.ident or "")
  if k == "" then k = tostring(fx.name or "") end
  return k
end

local function has_remaining()
  local start_i = load_cursor() or 1
for i = start_i, #final_list do
  local fx = final_list[i]
    local k = make_key(fx)
    if k ~= "" and not done[k] and not should_skip_fx(fx) then
      return true
    end
  end
  return false
end

local start_i = load_cursor() or 1
for i = start_i, #final_list do
  local fx = final_list[i]
  repeat
    local key = make_key(fx)
    if key == "" then
      skipped = skipped + 1
      break
    end

    if done[key] then
      skipped = skipped + 1
      break
    end

    if should_skip_fx(fx) then
      skipped = skipped + 1
      break
    end

    if new_budget > 0 and scanned >= new_budget then
      pass_limit_reached = true
      break
    end

    if ENUM_ONLY then
      -- No instantiation: safe enumerate-only mode (counts as scanned)
      f_plugins:write(string.format("%s,%s,%s,%s,%d,%s,%d\n",
        csv_escape(fx.display),
        csv_escape(key),
        csv_escape(fx.fx_type),
        csv_escape(fx.base),
        0,
        csv_escape("ENUM_ONLY"),
        0
      ))
      f_plugins:flush()
      mark_done(done, key)
      -- save_progress disabled (using done.txt)
      scanned = scanned + 1
      break
    end

    -- Crash-safe marker BEFORE instantiation
    write_current_fx({ idx = fx.idx, ident = fx.ident, name = fx.name })

    local _ok_call, loaded_ok, fx_index, used_name = pcall(try_add_fx, tmp_tr, fx.name, fx.display, fx.fx_type, fx.base)
    if not _ok_call then
      loaded_ok = false
      fx_index = -1
      used_name = "PCALL_ERROR"
    end

    if not loaded_ok or (not fx_index) or fx_index < 0 then
      failed = failed + 1
      f_fail:write(string.format("LOAD_FAIL\tidx=%s\tident=%s\tname=%s\tinfo=%s\n",
        tostring(fx.idx or ""), tostring(fx.ident or ""), tostring(fx.name or ""), tostring(used_name or "")
      ))
      f_fail:flush()

      f_plugins:write(string.format("%s,%s,%s,%s,%d,%s,%d\n",
        csv_escape(fx.display),
        csv_escape(key),
        csv_escape(fx.fx_type),
        csv_escape(fx.base),
        0,
        csv_escape(tostring(used_name or "")),
        0
      ))
      f_plugins:flush()

      mark_done(done, key)
      -- save_progress disabled (using done.txt)
      clear_tmp_fx(tmp_tr)
      clear_current_fx()
      scanned = scanned + 1
      break
    end

    -- Dump params
    local param_count = r.TrackFX_GetNumParams(tmp_tr, fx_index) or 0

    f_plugins:write(string.format("%s,%s,%s,%s,%d,%s,%d\n",
      csv_escape(fx.display),
      csv_escape(key),
      csv_escape(fx.fx_type),
      csv_escape(fx.base),
      1,
      csv_escape(used_name or ""),
      param_count
    ))
    f_plugins:flush()

    f_ndjson:write(string.format("{\"fx_display\":\"%s\",\"fx_ident\":\"%s\",\"fx_type\":\"%s\",\"base_name\":\"%s\",\"loaded_ok\":%s,\"load_name_used\":\"%s\",\"param_count\":%d}\n",
      json_escape(fx.display),
      json_escape(key),
      json_escape(fx.fx_type),
      json_escape(fx.base),
      "true",
      json_escape(used_name or ""),
      param_count
    ))
    f_ndjson:flush()

    for p = 0, param_count - 1 do
      local ok, minv, maxv, midv = r.TrackFX_GetParamEx(tmp_tr, fx_index, p)
      local val = r.TrackFX_GetParam(tmp_tr, fx_index, p) or 0.0
      local pname = get_param_name(tmp_tr, fx_index, p)
      local pident = get_param_ident(tmp_tr, fx_index, p)
      local fmt = get_formatted(tmp_tr, fx_index, p, val)
      local _step, small, large, istoggle = get_steps(tmp_tr, fx_index, p)

      f_params:write(string.format("%s,%s,%s,%s,%d,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n",
        csv_escape(key),
        csv_escape(fx.display),
        csv_escape(fx.fx_type),
        csv_escape(fx.base),
        p,
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
      ))
    end
    f_params:flush()

    clear_tmp_fx(tmp_tr)
    clear_current_fx()
    mark_done(done, key)
    -- save_progress disabled (using done.txt)
    scanned = scanned + 1

  until true

  save_cursor(i + 1)

  if pass_limit_reached then break end

  if scanned % 5 == 0 then
    r.UpdateArrange()
    if r.EscapeKeyPressed and r.EscapeKeyPressed() then
      f_fail:write("ABORT\tuser_pressed_esc\n")
      f_fail:flush()
      break
    end
  end
end

----------------------------------------------------------------
local remaining = has_remaining()

-- If we reached the end before hitting the batch size, reset cursor so the next pass starts from the beginning.
if not pass_limit_reached then
  save_cursor(1)
end

-- Auto-continue should run again as long as there are remaining NEW candidates,
-- even if this pass ended early due to reaching the end of the list.
local auto_rerun = (AUTO_CONTINUE and remaining)

-- Cleanup
----------------------------------------------------------------
f_plugins:close()
f_params:close()
f_ndjson:close()
f_fail:close()

r.DeleteTrack(tmp_tr)
if auto_rerun then
  local _, _, _, cmdID = r.get_action_context()
  if cmdID and cmdID ~= 0 then
    r.defer(function() r.Main_OnCommand(cmdID, 0) end)
  end
end

if (not auto_rerun) and SHOW_FINAL_SUMMARY then
  local total_n  = tonumber(total) or (final_list and #final_list) or 0
  local scanned_n = tonumber(scanned) or 0
  local skipped_n = tonumber(skipped) or 0
  local failed_n  = tonumber(failed) or 0

  r.MB(
    ("Done.\nTotal candidates: %d\nScanned (new): %d\nSkipped (resume/filtered): %d\nFailed: %d\n\nOutput folder:\n%s\n\nBatch size (new per pass): %s\nAuto-continue: %s\nRemaining: %s")
    :format(total_n, scanned_n, skipped_n, failed_n, out_dir, tostring(MAX_NEW_PER_PASS), tostring(AUTO_CONTINUE), tostring(remaining)),
    "IFLS Workbench Param Dump",
    0
  )
end
