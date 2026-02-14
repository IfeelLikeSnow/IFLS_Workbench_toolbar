-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_Set_PostFX_Settings.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Set Spread/Trim settings (project)
-- @author IFLS / DF95
-- @version 0.7.6
-- @about
--   Opens one dialog to configure Smart Slice post-processing:
--   Tail trim threshold/pad and Spread gap range.
--   Settings are stored in project extstate (IFLS_SLICING).


local r = reaper

local function get_ext(key, default)
  local _, v = r.GetProjExtState(0, "IFLS_SLICING", key)
  if v == nil or v == "" then return default end
  return v
end

local function set_ext(key, value)
  r.SetProjExtState(0, "IFLS_SLICING", key, tostring(value))
end

local function parse_num(v, default)
  v = tostring(v or ""):gsub(",", ".")
  local n = tonumber(v)
  if not n then return default end
  return n
end

local function parse_bool01(v, default)
  if v == nil or v == "" then return default end
  v = tostring(v):lower()
  if v == "1" or v == "true" or v == "yes" then return 1 end
  if v == "0" or v == "false" or v == "no" then return 0 end
  return default
end

local min_s = parse_num(get_ext("SPREAD_MIN_S", "1.0"), 1.0)
local max_s = parse_num(get_ext("SPREAD_MAX_S", "5.0"), 5.0)
local rnd   = parse_bool01(get_ext("SPREAD_RANDOM", "1"), 1)
local prompt = parse_bool01(get_ext("SPREAD_PROMPT", "1"), 1)

local tdb = parse_num(get_ext("TAILTRIM_DB", "-50"), -50)
local pad = parse_num(get_ext("TAILTRIM_PAD_MS", "5"), 5)
local ten = parse_bool01(get_ext("TAILTRIM_ENABLE", "1"), 1)
local sen = parse_bool01(get_ext("SPREAD_ENABLE", "1"), 1)

local ok, out = r.GetUserInputs(
  "IFLS Smart Slice: Post settings",
  8,
  "Spread enable 1/0,Gap min s,Gap max s,Random 1/0,Prompt each run 1/0,TailTrim enable 1/0,Threshold dB,Pad ms",
  string.format("%d,%.3f,%.3f,%d,%d,%d,%.1f,%.1f", sen, min_s, max_s, rnd, prompt, ten, tdb, pad)
)
if not ok then return end

local a,b,c,d,e,f,g,h = out:match("^%s*([^,]+),%s*([^,]+),%s*([^,]+),%s*([^,]+),%s*([^,]+),%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$")
if not a then return end

sen = (parse_num(a, sen) ~= 0) and 1 or 0
min_s = math.max(0, parse_num(b, min_s))
max_s = math.max(min_s, parse_num(c, max_s))
rnd = (parse_num(d, rnd) ~= 0) and 1 or 0
prompt = (parse_num(e, prompt) ~= 0) and 1 or 0
ten = (parse_num(f, ten) ~= 0) and 1 or 0
tdb = parse_num(g, tdb)
pad = math.max(0, parse_num(h, pad))

set_ext("SPREAD_ENABLE", sen)
set_ext("SPREAD_MIN_S", min_s)
set_ext("SPREAD_MAX_S", max_s)
set_ext("SPREAD_RANDOM", rnd)
set_ext("SPREAD_PROMPT", prompt)

set_ext("TAILTRIM_ENABLE", ten)
set_ext("TAILTRIM_DB", tdb)
set_ext("TAILTRIM_PAD_MS", pad)

r.ShowConsoleMsg(string.format("[IFLS] Spread %s (%.2f..%.2fs, random=%s, prompt=%s) | TailTrim %s (%.1fdB, pad %.1fms)\n",
  sen==1 and "ON" or "OFF", min_s, max_s, rnd==1 and "yes" or "no", prompt==1 and "yes" or "no",
  ten==1 and "ON" or "OFF", tdb, pad
))
