-- @description IFLS Workbench: Spread selected slices with gaps (for delay/reverb tails)
-- @author IFLS / DF95
-- @version 0.7.6
-- @about
--   Repositions selected items sequentially starting at the edit cursor.
--   Adds a gap between items (min..max seconds). Great after slicing to let FX tails ring out.
--   Settings are stored per-project in ExtState:
--     Section: IFLS_SLICING
--     Keys: SPREAD_MIN_S, SPREAD_MAX_S, SPREAD_RANDOM, SPREAD_PROMPT
-- @changelog
--   + Initial release

--
--

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

local function parse_bool(v, default)
  if v == nil or v == "" then return default end
  v = tostring(v):lower()
  if v == "1" or v == "true" or v == "yes" then return true end
  if v == "0" or v == "false" or v == "no" then return false end
  return default
end

local function get_cfg()
  local cfg = {}
  cfg.min_s = parse_num(get_ext("SPREAD_MIN_S", "1.0"), 1.0)
  cfg.max_s = parse_num(get_ext("SPREAD_MAX_S", "5.0"), 5.0)
  cfg.random = parse_bool(get_ext("SPREAD_RANDOM", "1"), true)
  cfg.prompt = parse_bool(get_ext("SPREAD_PROMPT", "1"), true)
  return cfg
end

local function prompt_cfg(cfg)
  local ok, out = r.GetUserInputs(
    "IFLS Spread slices",
    3,
    "Gap min (s),Gap max (s),Random 1/0",
    string.format("%.3f,%.3f,%d", cfg.min_s, cfg.max_s, cfg.random and 1 or 0)
  )
  if not ok then return nil end
  local a,b,c = out:match("^%s*([^,]+),%s*([^,]+),%s*([^,]+)%s*$")
  if not a then return nil end
  cfg.min_s = math.max(0, parse_num(a, cfg.min_s))
  cfg.max_s = math.max(cfg.min_s, parse_num(b, cfg.max_s))
  cfg.random = (parse_num(c, cfg.random and 1 or 0) ~= 0)

  set_ext("SPREAD_MIN_S", cfg.min_s)
  set_ext("SPREAD_MAX_S", cfg.max_s)
  set_ext("SPREAD_RANDOM", cfg.random and 1 or 0)
  return cfg
end

local function get_selected_items_sorted()
  local n = r.CountSelectedMediaItems(0)
  local items = {}
  for i=0,n-1 do
    local it = r.GetSelectedMediaItem(0,i)
    local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
    local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
    items[#items+1] = {it=it, pos=pos, len=len}
  end
  table.sort(items, function(a,b) return a.pos < b.pos end)
  return items
end

local function main()
  local n = r.CountSelectedMediaItems(0)
  if n < 2 then
    r.MB("Select 2+ slices to spread.", "IFLS Spread", 0)
    return
  end

  local cfg = get_cfg()
  if cfg.prompt then
    cfg = prompt_cfg(cfg) or cfg
  end

  local items = get_selected_items_sorted()
  local cursor = r.GetCursorPosition()
  local t = cursor

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  math.randomseed(tonumber(tostring(r.time_precise()):gsub("%D","")) or os.time())

  for _,x in ipairs(items) do
    r.SetMediaItemInfo_Value(x.it, "D_POSITION", t)
    local gap = cfg.min_s
    if cfg.random and cfg.max_s > cfg.min_s then
      gap = cfg.min_s + (cfg.max_s - cfg.min_s) * math.random()
    end
    t = t + x.len + gap
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock(string.format("IFLS: Spread slices (gap %.2f..%.2fs)", cfg.min_s, cfg.max_s), -1)
end

main()
