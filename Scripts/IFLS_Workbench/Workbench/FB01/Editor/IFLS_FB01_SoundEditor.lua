-- @description IFLS FB-01 Sound Editor (MVP)
-- @version 0.90.0
-- @author IFLS
-- @about
--   Native FB-01 editor for REAPER using ReaImGui + SWS SysEx send.
--   MVP: live parameter change for Voice + Operators + Instruments, plus dump-request buttons.
--
-- Requirements:
--   - ReaImGui
--   - SWS (SNM_SendSysEx)
--
-- Data:
--   - Workbench/FB01/Data/fb01_params_mvp.json

local r = reaper

-- deps
if not r.ImGui_CreateContext then
  r.MB("ReaImGui not found. Install ReaImGui first.", "FB-01 Sound Editor", 0)
  return
end
if not r.SNM_SendSysEx then
  r.MB("SWS not found (SNM_SendSysEx missing). Install SWS first.", "FB-01 Sound Editor", 0)
  return
end

local root = r.GetResourcePath() .. "/Scripts/IFLS_Workbench"
local Syx = dofile(root .. "/Workbench/FB01/Core/ifls_fb01_sysex.lua")

local function read_json(path)
  local f=io.open(path,"rb"); if not f then return nil end
  local s=f:read("*all"); f:close()
  return r.JSON_Parse and r.JSON_Parse(s) or nil
end

-- fallback JSON parser if REAPER lacks JSON_Parse: tiny decoder for our file
local function json_decode_min(s)
  -- minimal: rely on Lua load trick for trusted repo file
  local t = s:gsub('"%s*:%s*', '"='):gsub("null","nil")
  t = "return " .. t
  local ok, res = pcall(load(t))
  if ok then return res end
  return nil
end

local params_path = root .. "/Workbench/FB01/Data/fb01_params_mvp.json"
local raw = io.open(params_path,"rb"); local js = raw and raw:read("*all"); if raw then raw:close() end
local P = js and json_decode_min(js) or nil
if not P then
  r.MB("Failed to load params JSON:\n"..params_path, "FB-01 Sound Editor", 0)
  return
end

local function bin_to_hex(bin)
  local out={}
  for i=1,#bin do out[#out+1]=string.format("%02X", bin:byte(i)) end
  return table.concat(out)
end

local function send_sysex(bin)
  -- store hex in ExtState and call helper (keeps binary-safe across Lua layers)
  r.SetExtState("IFLS_FB01", "SYSEX_PAYLOAD", bin_to_hex(bin), false)
  dofile(root .. "/Workbench/FB01/Pack_v8/Scripts/IFLS_FB01_Send_SysEx_FromExtState.lua")
end


-- Preset / Random / Save-Load helpers (V93)

local function now_seed()
  local t = r.time_precise()
  return math.floor((t - math.floor(t)) * 1000000) + math.floor(t)
end

local function rand_int(lo, hi)
  if hi < lo then lo,hi=hi,lo end
  return lo + math.random(0, hi-lo)
end

local function sleep_ms(ms) r.Sleep(ms) end

local function apply_voice_param(param, val)
  voice_vals[param] = val
  local msg = Syx.voice_param(sysch, inst, param, val)
  send_sysex(msg)
  sleep_ms(5)
end

local function apply_op_param(op_id, param, val)
  op_vals[op_id+1][param] = val
  local msg = Syx.operator_param(sysch, inst, op_id, param, val)
  send_sysex(msg)
  sleep_ms(5)
end

local function apply_inst_param(param, val)
  inst_vals[param] = val
  local msg = Syx.instrument_param(sysch, inst, param, val)
  send_sysex(msg)
  sleep_ms(5)
end

local function apply_template(tpl)
  if tpl.voice then
    for k,v in pairs(tpl.voice) do apply_voice_param(k, v) end
  end
  if tpl.ops then
    for op_id, params in pairs(tpl.ops) do
      for k,v in pairs(params) do apply_op_param(op_id, k, v) end
    end
  end
  if tpl.instrument then
    for k,v in pairs(tpl.instrument) do apply_inst_param(k, v) end
  end
end

local function randomize(scope)
  math.randomseed(now_seed())
  if scope=="voice" or scope=="all" then
    for _,it in ipairs(P.voice_params) do
      apply_voice_param(it.param, rand_int(0,127))
    end
  end
  if scope=="ops" or scope=="all" then
    for op_id=0,3 do
      for _,it in ipairs(P.operator_params) do
        apply_op_param(op_id, it.param, rand_int(0,127))
      end
    end
  end
  if scope=="instrument" or scope=="all" then
    for _,it in ipairs(P.instrument_params) do
      apply_inst_param(it.param, rand_int(0,127))
    end
  end
end

-- Simple "genre templates" (starting points; adjust by ear)
local TEMPLATES = {
  ["Organ (bright)"] = {
    voice = { [0]=2, [1]=16, [3]=1, [7]=40, [8]=2, [11]=0, [13]=20, [14]=10, [15]=127, [16]=127, [17]=127, [18]=127 },
    ops = {
      [0] = { [0]=110, [6]=64, [12]=60, [8]=5, [11]=25, [14]=90, [15]=20 },
      [1] = { [0]=95,  [6]=64, [12]=60, [8]=5, [11]=25, [14]=90, [15]=20 },
      [2] = { [0]=0 },
      [3] = { [0]=0 },
    }
  },
  ["Synth (pad soft)"] = {
    voice = { [0]=6, [1]=10, [3]=1, [7]=30, [8]=1, [11]=10, [13]=25, [14]=15, [15]=127, [16]=127, [17]=127, [18]=127 },
    ops = {
      [0] = { [0]=95, [6]=48, [12]=40, [8]=40, [11]=60, [13]=80, [14]=80, [15]=60 },
      [1] = { [0]=85, [6]=48, [12]=40, [8]=40, [11]=60, [13]=80, [14]=80, [15]=60 },
      [2] = { [0]=70, [6]=32, [12]=40, [8]=50, [11]=70, [13]=90, [14]=70, [15]=70 },
      [3] = { [0]=0 },
    }
  },
  ["BD (kick-ish)"] = {
    voice = { [0]=0, [1]=0, [2]=0, [3]=0, [7]=0, [15]=127, [16]=0, [17]=0, [18]=0 },
    ops = {
      [0] = { [0]=127, [6]=10, [12]=20, [8]=0, [11]=10, [13]=20, [14]=0, [15]=5 },
      [1] = { [0]=90,  [6]=5,  [12]=10, [8]=0, [11]=15, [13]=30, [14]=0, [15]=10 },
    }
  },
  ["SD (snare-ish)"] = {
    voice = { [0]=4, [1]=8, [3]=0, [15]=127, [16]=127, [17]=0, [18]=0 },
    ops = {
      [0] = { [0]=110, [6]=30, [12]=50, [8]=0, [11]=20, [13]=50, [14]=0, [15]=25 },
      [1] = { [0]=90,  [6]=50, [12]=70, [8]=0, [11]=30, [13]=70, [14]=0, [15]=40 },
    }
  },
  ["HH (hat-ish)"] = {
    voice = { [0]=7, [1]=0, [3]=0, [15]=127, [16]=127, [17]=127, [18]=0 },
    ops = {
      [0] = { [0]=80, [6]=90, [12]=90, [8]=0, [11]=5, [13]=20, [14]=0, [15]=10 },
      [1] = { [0]=80, [6]=110,[12]=110,[8]=0, [11]=5, [13]=20, [14]=0, [15]=10 },
      [2] = { [0]=70, [6]=120,[12]=120,[8]=0, [11]=5, [13]=20, [14]=0, [15]=10 },
    }
  },
}

local function table_to_json(t)
  -- minimal JSON serializer for our state (numbers/tables/strings)
  local function esc(s) return s:gsub('\\','\\\\'):gsub('"','\\"') end
  local function ser(v)
    local tv=type(v)
    if tv=="number" then return tostring(math.floor(v))
    elseif tv=="boolean" then return v and "true" or "false"
    elseif tv=="string" then return '"'..esc(v)..'"'
    elseif tv=="table" then
      -- decide array vs object
      local is_arr=true
      local n=0
      for k,_ in pairs(v) do
        if type(k)~="number" then is_arr=false; break end
        n = math.max(n, k)
      end
      local out={}
      if is_arr then
        for i=1,n do out[#out+1]=ser(v[i]) end
        return "["..table.concat(out,",").."]"
      else
        for k,val in pairs(v) do
          out[#out+1]=ser(tostring(k))..":"..ser(val)
        end
        return "{"..table.concat(out,",").."}"
      end
    end
    return "null"
  end
  return ser(t)
end

local function save_state_json()
  local ok, path = r.GetUserFileNameForWrite("", "Save FB-01 state as JSON", ".json")
  if not ok or not path or path=="" then return end
  local state = { meta={version="0.93.0", sysch=sysch, inst=inst}, voice=voice_vals, ops=op_vals, instrument=inst_vals }
  local f=io.open(path,"wb"); if not f then r.MB("Cannot write:\n"..path, "FB-01", 0); return end
  f:write(table_to_json(state)); f:close()
  r.MB("Saved JSON:\n"..path, "FB-01", 0)
end

local function load_state_json()
  local ok, path = r.GetUserFileNameForRead("", "Load FB-01 state JSON", ".json")
  if not ok or not path or path=="" then return end
  local f=io.open(path,"rb"); if not f then r.MB("Cannot read:\n"..path, "FB-01", 0); return end
  local s=f:read("*all"); f:close()
  -- trusted local file: convert JSON-ish to Lua table (same trick)
  local t = s:gsub('"%s*:%s*', '"='):gsub("%[","{"):gsub("%]","}"):gsub("null","nil")
  local ok2, obj = pcall(load("return "..t))
  if not ok2 or type(obj)~="table" then r.MB("Invalid JSON file.", "FB-01", 0); return end

  if obj.voice then
    for k,v in pairs(obj.voice) do apply_voice_param(tonumber(k) or k, tonumber(v) or 0) end
  end
  if obj.ops then
    for op_id=0,3 do
      local op_t = obj.ops[op_id+1]
      if type(op_t)=="table" then
        for k,v in pairs(op_t) do apply_op_param(op_id, tonumber(k) or k, tonumber(v) or 0) end
      end
    end
  end
  if obj.instrument then
    for k,v in pairs(obj.instrument) do apply_inst_param(tonumber(k) or k, tonumber(v) or 0) end
  end
end


-- V94 additions: constrained random + user templates

local USER_TEMPLATES_PATH = root .. "/Workbench/FB01/Templates/user_templates.json"

local function read_file(path)
  local f=io.open(path,"rb"); if not f then return nil end
  local s=f:read("*all"); f:close(); return s
end
local function write_file(path, data)
  local f=io.open(path,"wb"); if not f then return false end
  f:write(data); f:close(); return true
end

local function load_user_templates()
  local s = read_file(USER_TEMPLATES_PATH)
  if not s or s=="" then return {meta={version="0.1.0"}, templates={}} end
  local t = s:gsub('"%s*:%s*', '"='):gsub("%[","{"):gsub("%]","}"):gsub("null","nil")
  local ok, obj = pcall(load("return "..t))
  if ok and type(obj)=="table" then
    obj.templates = obj.templates or {}
    return obj
  end
  return {meta={version="0.1.0"}, templates={}}
end

local function save_user_templates(db)
  db = db or {meta={version="0.1.0"}, templates={}}
  local ok = write_file(USER_TEMPLATES_PATH, table_to_json(db))
  return ok
end

local function capture_current_as_template(name)
  local tpl = {
    name = name,
    created_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    meta = {sysch=sysch, inst=inst},
    voice = voice_vals,
    ops = op_vals,
    instrument = inst_vals
  }
  return tpl
end

-- Parameter groups for constrained random
local OP_ENV = {8,11,13,14,15} -- Attack, Decay1, Decay2, Sustain, Release
local OP_PITCH = {5,6,12}      -- Fine, Multiple, Coarse (MVP IDs)
local OP_LEVEL = {0,1,2,3}     -- Volume + level mods
local VOICE_LFO = {7,8,9,10,11,12,13,14}

local function randomize_groups(opts)
  math.randomseed(now_seed())
  opts = opts or {}
  if opts.voice_lfo then
    for _,p in ipairs(VOICE_LFO) do apply_voice_param(p, rand_int(0,127)) end
  end
  if opts.voice_all then
    for _,it in ipairs(P.voice_params) do apply_voice_param(it.param, rand_int(0,127)) end
  end
  if opts.ops_env or opts.ops_pitch or opts.ops_level or opts.ops_all then
    for op_id=0,3 do
      if opts.ops_all then
        for _,it in ipairs(P.operator_params) do apply_op_param(op_id, it.param, rand_int(0,127)) end
      else
        if opts.ops_env then
          for _,p in ipairs(OP_ENV) do apply_op_param(op_id, p, rand_int(0,127)) end
        end
        if opts.ops_pitch then
          for _,p in ipairs(OP_PITCH) do apply_op_param(op_id, p, rand_int(0,127)) end
        end
        if opts.ops_level then
          for _,p in ipairs(OP_LEVEL) do apply_op_param(op_id, p, rand_int(0,127)) end
        end
      end
    end
  end
end

-- V95 additions: locks + intensity + export .syx as param-stream

local locks = {
  voice = {},         -- [param]=true
  ops = { {},{},{},{} }, -- [op+1][param]=true
  instrument = {},    -- [param]=true
}

local function is_locked(scope, a, b)
  if scope=="voice" then return locks.voice[a] == true end
  if scope=="instrument" then return locks.instrument[a] == true end
  if scope=="op" then return locks.ops[a+1][b] == true end
  return false
end

local function set_locked(scope, a, b, v)
  v = v and true or false
  if scope=="voice" then locks.voice[a] = v; return end
  if scope=="instrument" then locks.instrument[a] = v; return end
  if scope=="op" then locks.ops[a+1][b] = v; return end
end

local function export_param_stream_syx()
  local ok, path = r.GetUserFileNameForWrite("", "Export FB-01 state as .syx (param stream)", ".syx")
  if not ok or not path or path=="" then return end

  local out = {}
  -- voice
  for _,it in ipairs(P.voice_params) do
    local v = voice_vals[it.param] or 0
    out[#out+1] = Syx.voice_param(sysch, inst, it.param, v)
  end
  -- operators
  for op_id=0,3 do
    local t = op_vals[op_id+1]
    for _,it in ipairs(P.operator_params) do
      local v = (t and t[it.param]) or 0
      out[#out+1] = Syx.operator_param(sysch, inst, op_id, it.param, v)
    end
  end
  -- instrument
  for _,it in ipairs(P.instrument_params) do
    local v = inst_vals[it.param] or 0
    out[#out+1] = Syx.instrument_param(sysch, inst, it.param, v)
  end

  local f = io.open(path, "wb")
  if not f then r.MB("Cannot write:\n"..path, "FB-01", 0); return end
  for _,msg in ipairs(out) do f:write(msg) end
  f:close()
  r.MB("Exported .syx param stream:\n"..path, "FB-01", 0)
end

local function randomize_groups_intensity(opts, intensity)
  intensity = tonumber(intensity) or 1.0
  if intensity < 0 then intensity = 0 elseif intensity > 1 then intensity = 1 end
  math.randomseed(now_seed())
  opts = opts or {}

  local function mix(old, rnd)
    -- intensity=0 keeps old; intensity=1 uses rnd
    return clamp(math.floor(old*(1-intensity) + rnd*intensity + 0.5), 0, 127)
  end

  if opts.voice_lfo then
    for _,p in ipairs(VOICE_LFO) do
      if not is_locked("voice", p) then
        local old = voice_vals[p] or 0
        apply_voice_param(p, mix(old, rand_int(0,127)))
      end
    end
  end

  if opts.voice_all then
    for _,it in ipairs(P.voice_params) do
      local p = it.param
      if not is_locked("voice", p) then
        local old = voice_vals[p] or 0
        apply_voice_param(p, mix(old, rand_int(0,127)))
      end
    end
  end

  local function op_apply(op_id, p)
    if not is_locked("op", op_id, p) then
      local old = op_vals[op_id+1][p] or 0
      apply_op_param(op_id, p, mix(old, rand_int(0,127)))
    end
  end

  if opts.ops_all or opts.ops_env or opts.ops_pitch or opts.ops_level then
    for op_id=0,3 do
      if opts.ops_all then
        for _,it in ipairs(P.operator_params) do op_apply(op_id, it.param) end
      else
        if opts.ops_env then for _,p in ipairs(OP_ENV) do op_apply(op_id, p) end end
        if opts.ops_pitch then for _,p in ipairs(OP_PITCH) do op_apply(op_id, p) end end
        if opts.ops_level then for _,p in ipairs(OP_LEVEL) do op_apply(op_id, p) end end
      end
    end
  end
end
-- UI state
local ctx = r.ImGui_CreateContext("IFLS FB-01 Sound Editor (MVP)")
local inst = 0
local op = 0
local sysch = 0
local voice_vals = {}
local op_vals = {{},{},{},{}}
local inst_vals = {}
local user_db = load_user_templates()
local user_tpl_idx = 0
local template_names = {}
for k,_ in pairs(TEMPLATES) do template_names[#template_names+1]=k end
table.sort(template_names)
local template_idx = 0
local rand_intensity = 1.0

local function clamp(v, lo, hi)
  v = math.floor(tonumber(v) or 0)
  if v < lo then return lo elseif v > hi then return hi end
  return v
end

local function voice_panel()
  r.ImGui_Text(ctx, "Voice params (8-bit nibble-split)")
  for _,it in ipairs(P.voice_params) do
    local key = it.param
    local v = voice_vals[key] or 0
    local lock = is_locked("voice", key)
    local chkl, nlock = r.ImGui_Checkbox(ctx, "L##vlock"..key, lock)
    if chkl then set_locked("voice", key, nil, nlock) end
    r.ImGui_SameLine(ctx)
    local changed, nv = r.ImGui_SliderInt(ctx, it.name .. "##v"..key, v, 0, 127)
    if changed then
      nv = clamp(nv, 0, 127)
      voice_vals[key] = nv
      local msg = Syx.voice_param(sysch, inst, key, nv)
      send_sysex(msg)
    end
  end
end

local function operator_panel()
  r.ImGui_Text(ctx, "Operator params (8-bit nibble-split)")
  local changed, newop = r.ImGui_Combo(ctx, "Operator", op, "OP1\0OP2\0OP3\0OP4\0")
  if changed then op = newop end
  local t = op_vals[op+1]
  for _,it in ipairs(P.operator_params) do
    local key = it.param
    local v = t[key] or 0
    local lock = is_locked("op", op, key)
    local chkl, nlock = r.ImGui_Checkbox(ctx, "L##oplock"..op.."_"..key, lock)
    if chkl then set_locked("op", op, key, nlock) end
    r.ImGui_SameLine(ctx)
    local ch, nv = r.ImGui_SliderInt(ctx, it.name .. "##op"..op.."_"..key, v, 0, 127)
    if ch then
      nv = clamp(nv, 0, 127)
      t[key] = nv
      local msg = Syx.operator_param(sysch, inst, op, key, nv)
      send_sysex(msg)
    end
  end
end

local function instrument_panel()
  r.ImGui_Text(ctx, "Instrument params (7-bit)")
  for _,it in ipairs(P.instrument_params) do
    local key = it.param
    local v = inst_vals[key] or 0
    local lock = is_locked("instrument", key)
    local chkl, nlock = r.ImGui_Checkbox(ctx, "L##ilock"..key, lock)
    if chkl then set_locked("instrument", key, nil, nlock) end
    r.ImGui_SameLine(ctx)
    local ch, nv = r.ImGui_SliderInt(ctx, it.name .. "##i"..key, v, 0, 127)
    if ch then
      nv = clamp(nv, 0, 127)
      inst_vals[key] = nv
      local msg = Syx.instrument_param(sysch, inst, key, nv)
      send_sysex(msg)
    end
  end
end

local function requests_panel()
    r.ImGui_Separator(ctx)
    if r.ImGui_Button(ctx, "Randomize: Voice", 160, 0) then randomize("voice") end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Randomize: All Ops", 160, 0) then randomize("ops") end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Randomize: All", 160, 0) then randomize("all") end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Constrained random")
    local chg_i, ni = r.ImGui_SliderDouble(ctx, "Random intensity", rand_intensity, 0.0, 1.0)
    if chg_i then rand_intensity = ni end
    if r.ImGui_Button(ctx, "Rand: OP Env", 120, 0) then randomize_groups_intensity({ops_env=true}, rand_intensity) end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Rand: OP Pitch", 120, 0) then randomize_groups_intensity({ops_pitch=true}, rand_intensity) end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Rand: OP Level", 120, 0) then randomize_groups_intensity({ops_level=true}, rand_intensity) end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Rand: Voice LFO", 140, 0) then randomize_groups_intensity({voice_lfo=true}, rand_intensity) end

    if r.ImGui_Button(ctx, "Save patch state (JSON)", 200, 0) then save_state_json() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Load patch state (JSON)", 200, 0) then load_state_json() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Export .syx (param stream)", 200, 0) then export_param_stream_syx() end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "User templates")
    local names = ""
    for i=1,#(user_db.templates or {}) do names = names .. (user_db.templates[i].name or ("Template "..i)) .. "\0" end
    if names == "" then names = " (none)\0" end
    local chg_u, new_u = r.ImGui_Combo(ctx, "Saved", user_tpl_idx, names)
    if chg_u then user_tpl_idx = new_u end
    if r.ImGui_Button(ctx, "Apply Saved Template", 180, 0) then
      local t = (user_db.templates or {})[user_tpl_idx+1]
      if t then apply_template(t) end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Save Current as Template", 200, 0) then
      local okN, nm = r.GetUserInputs("Save Template", 1, "Name", "My Template")
      if okN and nm ~= "" then
        user_db = load_user_templates()
        user_db.templates = user_db.templates or {}
        user_db.templates[#user_db.templates+1] = capture_current_as_template(nm)
        save_user_templates(user_db)
      end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Reload Templates", 140, 0) then
      user_db = load_user_templates()
      user_tpl_idx = 0
    end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Templates (starting points)")
    local combo_str = ""
    for i=1,#template_names do combo_str = combo_str .. template_names[i] .. "\0" end
    local chg_t, new_idx = r.ImGui_Combo(ctx, "Template", template_idx, combo_str)
    if chg_t then template_idx = new_idx end
    if r.ImGui_Button(ctx, "Apply Template", 160, 0) then
      local name = template_names[template_idx+1]
      if name and TEMPLATES[name] then apply_template(TEMPLATES[name]) end
    end

    
  if r.ImGui_Button(ctx, "Request Voice Dump (current instrument)", -1, 0) then
    send_sysex(Syx.request_voice(sysch, inst))
  end
  if r.ImGui_Button(ctx, "Request Set Dump", -1, 0) then
    send_sysex(Syx.request_set(sysch))
  end
  if r.ImGui_Button(ctx, "Request Bank Dump (0)", -1, 0) then
    send_sysex(Syx.request_bank(sysch, 0))
  end
end

local function loop()
  local visible, open = r.ImGui_Begin(ctx, "IFLS FB-01 Sound Editor (MVP)", true, r.ImGui_WindowFlags_MenuBar())
  if visible then
    if r.ImGui_BeginMenuBar(ctx) then
      if r.ImGui_BeginMenu(ctx, "Help", true) then
        r.ImGui_Text(ctx, "Requires: ReaImGui + SWS SysEx")
        r.ImGui_Separator(ctx)
        r.ImGui_Text(ctx, "Tip: Use your existing FB-01 dump record/replay tools for librarian/recall.")
        r.ImGui_EndMenu(ctx)
      end
      r.ImGui_EndMenuBar(ctx)
    end

    r.ImGui_Separator(ctx)
    local chg, nsys = r.ImGui_SliderInt(ctx, "FB-01 SysEx Channel (SysCh)", sysch, 0, 15)
    if chg then sysch = clamp(nsys,0,15) end
    local ch2, ninst = r.ImGui_SliderInt(ctx, "Instrument (0..7)", inst, 0, 7)
    if ch2 then inst = clamp(ninst,0,7) end

    r.ImGui_Separator(ctx)
    requests_panel()
    r.ImGui_Separator(ctx)
    if r.ImGui_Button(ctx, "Randomize: Voice", 160, 0) then randomize("voice") end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Randomize: All Ops", 160, 0) then randomize("ops") end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Randomize: All", 160, 0) then randomize("all") end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Constrained random")
    local chg_i, ni = r.ImGui_SliderDouble(ctx, "Random intensity", rand_intensity, 0.0, 1.0)
    if chg_i then rand_intensity = ni end
    if r.ImGui_Button(ctx, "Rand: OP Env", 120, 0) then randomize_groups_intensity({ops_env=true}, rand_intensity) end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Rand: OP Pitch", 120, 0) then randomize_groups_intensity({ops_pitch=true}, rand_intensity) end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Rand: OP Level", 120, 0) then randomize_groups_intensity({ops_level=true}, rand_intensity) end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Rand: Voice LFO", 140, 0) then randomize_groups_intensity({voice_lfo=true}, rand_intensity) end

    if r.ImGui_Button(ctx, "Save patch state (JSON)", 200, 0) then save_state_json() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Load patch state (JSON)", 200, 0) then load_state_json() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Export .syx (param stream)", 200, 0) then export_param_stream_syx() end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "User templates")
    local names = ""
    for i=1,#(user_db.templates or {}) do names = names .. (user_db.templates[i].name or ("Template "..i)) .. "\0" end
    if names == "" then names = " (none)\0" end
    local chg_u, new_u = r.ImGui_Combo(ctx, "Saved", user_tpl_idx, names)
    if chg_u then user_tpl_idx = new_u end
    if r.ImGui_Button(ctx, "Apply Saved Template", 180, 0) then
      local t = (user_db.templates or {})[user_tpl_idx+1]
      if t then apply_template(t) end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Save Current as Template", 200, 0) then
      local okN, nm = r.GetUserInputs("Save Template", 1, "Name", "My Template")
      if okN and nm ~= "" then
        user_db = load_user_templates()
        user_db.templates = user_db.templates or {}
        user_db.templates[#user_db.templates+1] = capture_current_as_template(nm)
        save_user_templates(user_db)
      end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Reload Templates", 140, 0) then
      user_db = load_user_templates()
      user_tpl_idx = 0
    end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Templates (starting points)")
    local combo_str = ""
    for i=1,#template_names do combo_str = combo_str .. template_names[i] .. "\0" end
    local chg_t, new_idx = r.ImGui_Combo(ctx, "Template", template_idx, combo_str)
    if chg_t then template_idx = new_idx end
    if r.ImGui_Button(ctx, "Apply Template", 160, 0) then
      local name = template_names[template_idx+1]
      if name and TEMPLATES[name] then apply_template(TEMPLATES[name]) end
    end

    
    r.ImGui_Separator(ctx)

    if r.ImGui_BeginTabBar(ctx, "tabs") then
      if r.ImGui_BeginTabItem(ctx, "Voice", true) then
        voice_panel()
        r.ImGui_EndTabItem(ctx)
      end
      if r.ImGui_BeginTabItem(ctx, "Operators", true) then
        operator_panel()
        r.ImGui_EndTabItem(ctx)
      end
      if r.ImGui_BeginTabItem(ctx, "Instrument", true) then
        instrument_panel()
        r.ImGui_EndTabItem(ctx)
      end
      if r.ImGui_BeginTabItem(ctx, "Library", true) then
        r.ImGui_Text(ctx, "Library + Project Recall")
        if r.ImGui_Button(ctx, "Open FB-01 Library Browser (v2)", -1, 0) then
          dofile(root .. "/Workbench/FB01/Tools/IFLS_FB01_Library_Browser_v2.lua")
        end
        if r.ImGui_Button(ctx, "Project Recall: Save voice (.syx)", -1, 0) then
          dofile(root .. "/Workbench/FB01/Tools/IFLS_FB01_Project_Save_Recall.lua")
        end
        if r.ImGui_Button(ctx, "Project Recall: Apply stored voice", -1, 0) then
          dofile(root .. "/Workbench/FB01/Tools/IFLS_FB01_Project_Apply_Recall.lua")
        end
        r.ImGui_Separator(ctx)
        r.ImGui_Text(ctx, "Fix/Normalize SysEx (offline)")
        if r.ImGui_Button(ctx, "Normalize DeviceID/SysExCh", -1, 0) then
          dofile(root .. "/Workbench/FB01/Tools/IFLS_FB01_Normalize_DeviceID.lua")
        end
        if r.ImGui_Button(ctx, "Retarget Bank1<->Bank2", -1, 0) then
          dofile(root .. "/Workbench/FB01/Tools/IFLS_FB01_Retarget_Bank1_Bank2.lua")
        end
        r.ImGui_EndTabItem(ctx)
      end
      r.ImGui_EndTabBar(ctx)
    end

    r.ImGui_End(ctx)
  end

  if open then
    r.defer(loop)
  else
    r.ImGui_DestroyContext(ctx)
  end
end

r.defer(loop)
