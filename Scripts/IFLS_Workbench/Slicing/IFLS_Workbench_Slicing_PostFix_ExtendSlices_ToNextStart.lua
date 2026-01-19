-- @description IFLS Workbench - Slicing PostFix: Extend slices to next start
-- @version 1.0.0
-- @author IFLS
-- @about
--   Fixes micro-slices by extending each selected item to the next selected item's start (minus gap).
--   Use after Smart Slicing (PrintBus) to restore meaningful slice lengths.
-- @provides [main] .

local GAP_MS     = 5      -- gap between slices (avoid overlap)
local MIN_LEN_MS = 40     -- never shorter than this
local function s2ms(s) return s*1000 end

local function get_sel_items_sorted()
  local t = {}
  local n = reaper.CountSelectedMediaItems(0)
  for i=0,n-1 do
    local it = reaper.GetSelectedMediaItem(0,i)
    local pos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
    t[#t+1] = {item=it, pos=pos}
  end
  table.sort(t, function(a,b) return a.pos < b.pos end)
  return t
end

local function set_item_len(it, len_s)
  local min_s = MIN_LEN_MS/1000.0
  if len_s < min_s then len_s = min_s end
  reaper.SetMediaItemInfo_Value(it, "D_LENGTH", len_s)
end

local function main()
  local items = get_sel_items_sorted()
  if #items < 2 then return end

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local gap_s = GAP_MS/1000.0
  for i=1,#items-1 do
    local it  = items[i].item
    local pos = items[i].pos
    local next_pos = items[i+1].pos
    local new_len = (next_pos - gap_s) - pos
    set_item_len(it, new_len)
  end

  -- last item: leave as is (optional tail detection can be added if you want)
  reaper.UpdateArrange()
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("IFLSWB PostFix: Extend slices to next start", -1)
end

main()
