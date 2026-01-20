-- @description IFLS WB: PostFix (Extend slices to next start)
-- @version 1.0.0
-- @author IFLS Workbench
-- @about Extends each selected slice's length so it reaches the next slice start (per track). Useful after transient-only slicing.
-- @provides [main] .

local r = reaper

local function sort_items_by_pos(items)
  table.sort(items, function(a,b)
    return r.GetMediaItemInfo_Value(a,"D_POSITION") < r.GetMediaItemInfo_Value(b,"D_POSITION")
  end)
end

local function get_selected_items_by_track()
  local by_tr = {}
  local n = r.CountSelectedMediaItems(0)
  for i=0,n-1 do
    local it = r.GetSelectedMediaItem(0,i)
    local tr = r.GetMediaItem_Track(it)
    by_tr[tr] = by_tr[tr] or {}
    table.insert(by_tr[tr], it)
  end
  return by_tr
end

local function main()
  local by_tr = get_selected_items_by_track()
  local any = false
  for tr, items in pairs(by_tr) do
    if #items >= 2 then
      any = true
      sort_items_by_pos(items)
      for i=1,#items-1 do
        local a = items[i]
        local b = items[i+1]
        local a_pos = r.GetMediaItemInfo_Value(a,"D_POSITION")
        local b_pos = r.GetMediaItemInfo_Value(b,"D_POSITION")
        r.SetMediaItemInfo_Value(a,"D_LENGTH", math.max(0.0, b_pos - a_pos))
      end
    end
  end

  if not any then
    r.MB("Select at least 2 items on a track to extend them to the next start.", "IFLSWB PostFix", 0)
    return
  end
  r.UpdateArrange()
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)
main()
r.PreventUIRefresh(-1)
r.Undo_EndBlock("IFLS WB: PostFix Extend slices to next start", -1)
