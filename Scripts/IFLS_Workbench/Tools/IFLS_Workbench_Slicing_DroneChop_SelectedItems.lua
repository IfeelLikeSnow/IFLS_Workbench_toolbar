-- @description IFLS Workbench - Tools/IFLS_Workbench_Slicing_DroneChop_SelectedItems.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Drone Chop selected material (glue -> time chops with fades)
-- @version 0.7.6
-- @author IFLS
-- @about
--   Creates drone-friendly slices from selected items:
--   1) Optionally glue selected items (built-in action 41588).
--   2) Split into segments of random or fixed length (seconds).
--   3) Apply fades to each segment for smoothness.


local r = reaper
local EXT_NS  = "IFLS_WORKBENCH_SLICING"
local EXT_KEY = "DRONE_CHOP_SETTINGS" -- len_min,len_max,random,fade_ms,glue

local function parse(csv)
  local t = {}
  for tok in (csv or ""):gmatch("([^,]+)") do t[#t+1] = tok end
  return t
end

local function load_settings()
  local st = {len_min=0.5, len_max=2.5, random=1, fade_ms=30.0, glue=1}
  local s = r.GetExtState(EXT_NS, EXT_KEY)
  if s and s ~= "" then
    local v = parse(s)
    if #v >= 5 then
      st.len_min = tonumber(v[1]) or st.len_min
      st.len_max = tonumber(v[2]) or st.len_max
      st.random  = tonumber(v[3]) or st.random
      st.fade_ms = tonumber(v[4]) or st.fade_ms
      st.glue    = tonumber(v[5]) or st.glue
    end
  end
  if st.len_max < st.len_min then st.len_max = st.len_min end
  return st
end

local function save_settings(st)
  r.SetExtState(EXT_NS, EXT_KEY, string.format("%.6f,%.6f,%d,%.6f,%d", st.len_min, st.len_max, st.random, st.fade_ms, st.glue), true)
end

local function prompt_settings(st)
  local ok, csv = r.GetUserInputs(
    "IFLS Drone Chop",
    5,
    "Len min (s),Len max (s),Random (1/0),Fade ms,Glue first (1/0)",
    string.format("%.2f,%.2f,%d,%.1f,%d", st.len_min, st.len_max, st.random, st.fade_ms, st.glue)
  )
  if not ok then return nil end
  local v = parse(csv)
  if #v < 5 then return nil end
  st.len_min = tonumber(v[1]) or st.len_min
  st.len_max = tonumber(v[2]) or st.len_max
  st.random  = tonumber(v[3]) or st.random
  st.fade_ms = tonumber(v[4]) or st.fade_ms
  st.glue    = tonumber(v[5]) or st.glue
  if st.len_max < st.len_min then st.len_max = st.len_min end
  save_settings(st)
  return st
end

local function rand_between(a,b)
  if b <= a then return a end
  return a + math.random()*(b-a)
end

local function apply_fades(item, fade_s)
  local len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  local f = math.min(fade_s, len*0.45)
  r.SetMediaItemInfo_Value(item, "D_FADEINLEN", f)
  r.SetMediaItemInfo_Value(item, "D_FADEOUTLEN", f)
end

local function main()
  math.randomseed((r.time_precise()*1000000)%2147483647)
  local st = load_settings()
  st = prompt_settings(st)
  if not st then return end

  local n = r.CountSelectedMediaItems(0)
  if n == 0 then
    r.MB("No selected items.\n\nTip: select items on IFLS Slices track first.", "IFLS Drone Chop", 0)
    return
  end

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  if st.glue == 1 and n > 1 then
    r.Main_OnCommand(41588, 0)
  end

  local items = {}
  local nn = r.CountSelectedMediaItems(0)
  for i=0,nn-1 do
    items[#items+1] = r.GetSelectedMediaItem(0,i)
  end

  local fade_s = st.fade_ms / 1000.0

  for _,it in ipairs(items) do
    local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
    local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
    local endpos = pos + len

    local t = pos
    while t + 0.01 < endpos do
      local seg = (st.random==1) and rand_between(st.len_min, st.len_max) or st.len_min
      local splitpos = math.min(endpos, t + seg)
      if splitpos < endpos - 0.0005 then
        local right = r.SplitMediaItem(it, splitpos)
        apply_fades(it, fade_s)
        it = right
      else
        apply_fades(it, fade_s)
        break
      end
      t = splitpos
    end
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS: Drone chop selected material", -1)
end

main()
