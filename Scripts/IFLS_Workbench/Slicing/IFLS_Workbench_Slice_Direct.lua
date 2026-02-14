-- @description IFLS Workbench - Slicing/IFLS_Workbench_Slice_Direct.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Slice Direct (cursor or time selection)
-- @version 1.0
-- @about Schneidet ausgewÃ¤hlte Items direkt an Time Selection oder Edit-Cursor.


local r = reaper

local function get_time_sel()
  local start_time, end_time = r.GetSet_LoopTimeRange(false, false, 0, 0, false)
  if end_time > start_time then
    return start_time, end_time
  end
  return nil, nil
end

local function slice_at_pos(item, pos)
  local it_pos = r.GetMediaItemInfo_Value(item, "D_POSITION")
  local it_len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  if pos <= it_pos or pos >= it_pos + it_len then return end
  r.SplitMediaItem(item, pos)
end

local function main()
  local cnt = r.CountSelectedMediaItems(0)
  if cnt == 0 then return end

  local ts_start, ts_end = get_time_sel()
  local cursor = r.GetCursorPosition()

  r.Undo_BeginBlock()

  for i = 0, cnt-1 do
    local it = r.GetSelectedMediaItem(0, i)
    if ts_start then
      slice_at_pos(it, ts_start)
      slice_at_pos(it, ts_end)
    else
      slice_at_pos(it, cursor)
    end
  end

  r.Undo_EndBlock("IFLS Workbench: Slice Direct", -1)
  r.UpdateArrange()
end

main()
