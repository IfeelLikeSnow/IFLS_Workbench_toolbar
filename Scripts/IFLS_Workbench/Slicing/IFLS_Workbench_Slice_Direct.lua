-- @description IFLS Workbench - Slice Direct (Cursor or Time Selection)
-- @author IFLS / DF95
-- @version 0.7.6
-- @changelog
--   + Fix: time-selection mode now splits at BOTH boundaries reliably
--   + Safer: snapshot selected items before splitting (new items won't break iteration)
--   + Add undo block + UI refresh guard
--
-- @about
--   If a time selection exists: split each selected item at time selection start AND end.
--   Otherwise: split each selected item at edit cursor.

local r = reaper

local function split_item_at(it, pos)
  if not it or not pos then return nil end
  local it_pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
  local it_len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
  local it_end = it_pos + it_len
  if pos <= it_pos or pos >= it_end then return nil end
  return r.SplitMediaItem(it, pos) -- returns right-hand item
end

local function get_time_selection()
  local _, start_t, end_t = r.GetSet_LoopTimeRange2(0, false, false, 0, 0, false)
  if end_t and start_t and end_t > start_t then return start_t, end_t end
  return nil, nil
end

local function get_selected_items()
  local items = {}
  local n = r.CountSelectedMediaItems(0)
  for i = 0, n-1 do
    items[#items+1] = r.GetSelectedMediaItem(0, i)
  end
  return items
end

local function main()
  local items = get_selected_items()
  if #items == 0 then
    r.MB("Bitte mindestens ein Item auswählen.", "IFLS Slice Direct", 0)
    return
  end

  local ts_start, ts_end = get_time_selection()
  local cursor = r.GetCursorPosition()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  if ts_start and ts_end then
    for _, it in ipairs(items) do
      local right = split_item_at(it, ts_start) or it
      split_item_at(right, ts_end)
    end
  else
    for _, it in ipairs(items) do
      split_item_at(it, cursor)
    end
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS Slice Direct", -1)
end

main()
