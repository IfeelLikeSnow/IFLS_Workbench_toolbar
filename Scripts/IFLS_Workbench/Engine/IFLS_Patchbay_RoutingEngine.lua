-- @description IFLS Workbench - Engine/IFLS_Patchbay_RoutingEngine.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @noindex
-- IFLS Patchbay Routing Engine
-- Shared module used by IFLS Workbench scripts.
-- Loads Data/IFLS_Workbench/patchbay.json, suggests channels, tracks conflicts, stores recall.

local r = reaper

local M = {}

-- ---------- tiny JSON decoder (limited but OK for our generated JSON) ----------
local function json_decode(str)
  local i = 1
  local function skip()
    while true do
      local c = str:sub(i,i)
      if c == '' then return end
      if c == ' ' or c == '\n' or c == '\r' or c == '\t' then i = i + 1 else return end
    end
  end
  local function parse_value()
    local function parse_string()
      i = i + 1
      local out = {}
      while true do
        local c = str:sub(i,i)
        if c == '' then error("Unterminated string") end
        if c == '"' then i = i + 1; return table.concat(out) end
        if c == '\\' then
          local n = str:sub(i+1,i+1)
          if n == '"' or n == '\\' or n == '/' then out[#out+1]=n; i=i+2
          elseif n == 'b' then out[#out+1]='\b'; i=i+2
          elseif n == 'f' then out[#out+1]='\f'; i=i+2
          elseif n == 'n' then out[#out+1]='\n'; i=i+2
          elseif n == 'r' then out[#out+1]='\r'; i=i+2
          elseif n == 't' then out[#out+1]='\t'; i=i+2
          else out[#out+1]='\\'..n; i=i+2 end
        else out[#out+1]=c; i=i+1 end
      end
    end
    local function parse_number()
      local s = i
      local c = str:sub(i,i)
      if c == '-' then i=i+1 end
      while str:sub(i,i):match('%d') do i=i+1 end
      if str:sub(i,i) == '.' then i=i+1; while str:sub(i,i):match('%d') do i=i+1 end end
      local e = str:sub(i,i)
      if e == 'e' or e == 'E' then
        i=i+1
        local sign = str:sub(i,i)
        if sign == '+' or sign == '-' then i=i+1 end
        while str:sub(i,i):match('%d') do i=i+1 end
      end
      return tonumber(str:sub(s,i-1))
    end
    local function parse_array()
      i=i+1; skip()
      local arr = {}
      if str:sub(i,i) == ']' then i=i+1; return arr end
      while true do
        arr[#arr+1] = parse_value()
        skip()
        local c = str:sub(i,i)
        if c == ',' then i=i+1; skip()
        elseif c == ']' then i=i+1; return arr
        else error("Expected , or ]") end
      end
    end
    local function parse_object()
      i=i+1; skip()
      local obj = {}
      if str:sub(i,i) == '}' then i=i+1; return obj end
      while true do
        if str:sub(i,i) ~= '"' then error("Expected string key") end
        local k = parse_string()
        skip()
        if str:sub(i,i) ~= ':' then error("Expected :") end
        i=i+1; skip()
        obj[k] = parse_value()
        skip()
        local c = str:sub(i,i)
        if c == ',' then i=i+1; skip()
        elseif c == '}' then i=i+1; return obj
        else error("Expected , or }") end
      end
    end

    skip()
    local c = str:sub(i,i)
    if c == '"' then return parse_string()
    elseif c == '{' then return parse_object()
    elseif c == '[' then return parse_array()
    elseif c:match('[%-%d]') then return parse_number()
    elseif str:sub(i,i+3) == 'true' then i=i+4; return true
    elseif str:sub(i,i+4) == 'false' then i=i+5; return false
    elseif str:sub(i,i+3) == 'null' then i=i+4; return nil
    else error("Unexpected token at "..i) end
  end
  local ok, res = pcall(parse_value)
  if not ok then return nil, res end
  return res, nil
end

local function slurp(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function norm(s) return tostring(s or ""):lower() end

function M.is_patched(mark)
  return mark == "present" or mark == "left" or mark == "right" or mark == "sidechain_in"
end

function M.load_patchbay()
  local resource = r.GetResourcePath()
  local patch_path = resource .. "/Data/IFLS_Workbench/patchbay.json"
  local s = slurp(patch_path)
  if not s then return nil, "patchbay.json not found: " .. patch_path end
  local data, err = json_decode(s)
  if not data then return nil, err end
  if not (data.outputs and data.inputs) then
    return nil, "patchbay.json missing outputs/inputs matrices"
  end
  return data, nil
end

function M.list_devices_common(patch_data)
  local outputs = patch_data.outputs or {}
  local inputs  = patch_data.inputs or {}
  local oset, iset = {}, {}
  for _, d in ipairs(outputs.devices or {}) do oset[d.name] = true end
  for _, d in ipairs(inputs.devices or {}) do iset[d.name] = true end
  local list = {}
  for name in pairs(oset) do if iset[name] then list[#list+1]=name end end
  table.sort(list)
  return list
end

function M.get_device_map(matrix, device_name)
  for _, d in ipairs((matrix and matrix.devices) or {}) do
    if d.name == device_name then return d.map end
  end
  return nil
end

function M.suggest_mono_channel(map)
  local all = {}
  for ch, m in pairs(map or {}) do
    local n = tonumber(ch)
    if n and M.is_patched(m) then all[#all+1]=n end
  end
  table.sort(all)
  return all[1]
end

function M.suggest_stereo_channels(map)
  local lefts, rights, presents = {}, {}, {}
  for ch, m in pairs(map or {}) do
    local n = tonumber(ch)
    if n then
      if m == "left" then lefts[n] = true
      elseif m == "right" then rights[n] = true
      elseif m == "present" then presents[n] = true end
    end
  end
  for n in pairs(lefts) do
    if rights[n+1] then return n, n+1, "L/R consecutive" end
  end
  for n in pairs(presents) do
    if presents[n+1] then return n, n+1, "present consecutive" end
  end
  local all = {}
  for ch, m in pairs(map or {}) do
    local n = tonumber(ch)
    if n and M.is_patched(m) then all[#all+1]=n end
  end
  table.sort(all)
  if #all >= 2 then return all[1], all[2], "first two patched" end
  return nil
end

-- ---------- recall (project) ----------
local EXT_SECTION = "IFLS_WORKBENCH"
local EXT_KEY = "HW_ROUTING"

local function get_proj()
  return r.EnumProjects(-1, "")
end

function M.load_recall()
  local proj = get_proj()
  local ok, str = r.GetProjExtState(proj, EXT_SECTION, EXT_KEY)
  if ok == 1 and str and str ~= "" then
    local obj = json_decode(str)
    if type(obj) == "table" then return obj end
  end
  return {}
end

local function esc(s)
  s = tostring(s)
  s = s:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r','\\r'):gsub('\t','\\t')
  return s
end

local function enc(v)
  local t = type(v)
  if t == "string" then return '"'..esc(v)..'"'
  elseif t == "number" then return tostring(v)
  elseif t == "boolean" then return v and "true" or "false"
  elseif t == "table" then
    local parts = {}
    for k,val in pairs(v) do
      parts[#parts+1] = '"'..esc(k)..'":'..enc(val)
    end
    table.sort(parts)
    return "{"..table.concat(parts,",").."}"
  else return "null" end
end

function M.save_recall(obj)
  local proj = get_proj()
  r.SetProjExtState(proj, EXT_SECTION, EXT_KEY, enc(obj))
end

function M.conflicts_with_recall(recall, device_name, mode, outL, outR, outMono)
  local used = {}
  for dev, cfg in pairs(recall or {}) do
    if dev ~= device_name and type(cfg) == "table" then
      if cfg.mode == "stereo" then
        if cfg.outL then used[cfg.outL] = dev end
        if cfg.outR then used[cfg.outR] = dev end
      elseif cfg.mode == "mono" then
        if cfg.out then used[cfg.out] = dev end
      end
    end
  end
  local hits = {}
  local function check(ch)
    if ch and used[ch] then hits[#hits+1] = {ch=ch, dev=used[ch]} end
  end
  if mode == "stereo" then check(outL); check(outR) else check(outMono) end
  table.sort(hits, function(a,b) return a.ch < b.ch end)
  return hits
end

function M.filter_list(devices, query)
  local q = norm(query)
  if q == "" then return devices end
  local out = {}
  for _, name in ipairs(devices) do
    if norm(name):find(q, 1, true) then out[#out+1] = name end
  end
  return out
end

-- ---------- routing builders ----------
-- Hardware output sends use TrackSend category=1 and I_DSTCHAN (&1024 = mono) (REAPER convention; see docs and community refs).
-- Source: REAPER ReaScript API docs & function semantics. https://www.reaper.fm/sdk/reascript/reascripthelp.html
function M.add_hw_out_send(track, out_left_ch, mode)
  local sendidx = r.CreateTrackSend(track, nil) -- nil dest => hardware output
  if sendidx < 0 then return false, "CreateTrackSend failed" end

  if mode == "stereo" then
    r.SetTrackSendInfo_Value(track, 1, sendidx, "I_SRCCHAN", 0)
    r.SetTrackSendInfo_Value(track, 1, sendidx, "I_DSTCHAN", (out_left_ch - 1))
  else
    r.SetTrackSendInfo_Value(track, 1, sendidx, "I_SRCCHAN", (0 | 1024))
    r.SetTrackSendInfo_Value(track, 1, sendidx, "I_DSTCHAN", ((out_left_ch - 1) | 1024))
  end
  return true
end

-- Record input encoding: low bits represent input channel (0-based). Details are in common API mirrors (eg Ultraschall docs).
-- https://mespotin.uber.space/Ultraschall/Reaper_Api_Documentation.html
function M.set_track_hw_input(track, in_left_ch)
  local recinput = (in_left_ch - 1)
  r.SetMediaTrackInfo_Value(track, "I_RECINPUT", recinput)
  r.SetMediaTrackInfo_Value(track, "I_RECMON", 1)
  r.SetMediaTrackInfo_Value(track, "I_RECARM", 1)
end

function M.ensure_track_channels(track, ch)
  r.SetMediaTrackInfo_Value(track, "I_NCHAN", ch)
end

function M.add_reainsert_fx(track, open_ui)
  local fx = r.TrackFX_AddByName(track, "ReaInsert (Cockos)", false, -1)
  if fx >= 0 and open_ui then
    r.TrackFX_Show(track, fx, 3) -- 3 = show floating window
  end
  return fx
end



-- Build a map: hw_out_channel -> {device_names...}
function M.compute_used_outputs(recall)
  local used = {}
  for dev, cfg in pairs(recall or {}) do
    if type(cfg) == "table" then
      if cfg.mode == "stereo" then
        if cfg.outL then used[cfg.outL] = used[cfg.outL] or {}; table.insert(used[cfg.outL], dev) end
        if cfg.outR then used[cfg.outR] = used[cfg.outR] or {}; table.insert(used[cfg.outR], dev) end
      elseif cfg.mode == "mono" then
        if cfg.out then used[cfg.out] = used[cfg.out] or {}; table.insert(used[cfg.out], dev) end
      end
    end
  end
  for ch, lst in pairs(used) do table.sort(lst) end
  return used
end

-- Returns list of duplicates: { {ch=3, devices={"A","B"}}, ... } where #devices>1
function M.detect_output_conflicts(recall)
  local used = M.compute_used_outputs(recall)
  local conflicts = {}
  for ch, devs in pairs(used) do
    if #devs > 1 then conflicts[#conflicts+1] = { ch=ch, devices=devs } end
  end
  table.sort(conflicts, function(a,b) return a.ch < b.ch end)
  return conflicts
end

function M.get_recall_devices(recall)
  local list = {}
  for dev in pairs(recall or {}) do list[#list+1] = dev end
  table.sort(list)
  return list
end

-- Remove all hardware output sends (category=1) from a track
function M.clear_hw_out_sends(track)
  local n = r.GetTrackNumSends(track, 1)
  for i = n-1, 0, -1 do
    r.RemoveTrackSend(track, 1, i)
  end
end

-- Apply recalled routing to a track:
-- method: "tracks_send_only" (hw out send only), "reainsert", "both"
function M.apply_recall_to_track(track, device_name, cfg, method, open_reainsert_ui)
  if not track or not cfg then return false, "missing track/cfg" end

  local mode = cfg.mode or "stereo"
  local outL = cfg.outL or cfg.out
  if not outL then return false, "missing out channel" end

  if method == "tracks_send_only" or method == "both" then
    M.clear_hw_out_sends(track)
    local ok, err = M.add_hw_out_send(track, outL, mode)
    if not ok then return false, err end
  end

  if method == "reainsert" or method == "both" then
    local fx = M.add_reainsert_fx(track, open_reainsert_ui)
    if fx < 0 then return false, "failed to add ReaInsert" end
  end

  local notes = r.GetSetMediaTrackInfo_String(track, "P_NOTES", "", false)
  local out_txt = (mode=="stereo") and (tostring(cfg.outL).."/"..tostring(cfg.outR)) or tostring(cfg.out)
  local in_txt  = (mode=="stereo") and (tostring(cfg.inL ).."/"..tostring(cfg.inR )) or tostring(cfg.in_)
  local new_notes = ("IFLS HW Recall Apply\nDevice: %s\nMode: %s\nHW OUT: %s\nHW IN: %s\n\n%s")
    :format(device_name, mode, out_txt, in_txt, (notes or ""))
  r.GetSetMediaTrackInfo_String(track, "P_NOTES", new_notes, true)

  return true
end

return M
