-- @version 0.0.1
-- @noindex
-- IFLS Workbench Slicing Fade Common

local r = reaper
local function set_item_fades(shape, fin, fout)
  local cnt = r.CountSelectedMediaItems(0)
  -- shape: linear=0, slow=1, fast=2 (REAPER fade shapes indices for item fade curve; simplified mapping)
  local shape_idx = ({linear=0, slow=1, fast=2})[shape] or 0
  for i=0,cnt-1 do
    local it = r.GetSelectedMediaItem(0,i)
    r.SetMediaItemInfo_Value(it, "D_FADEINLEN",  (fin or 0)/1000.0)
    r.SetMediaItemInfo_Value(it, "D_FADEOUTLEN", (fout or 0)/1000.0)
    r.SetMediaItemInfo_Value(it, "C_FADEINSHAPE",  shape_idx)
    r.SetMediaItemInfo_Value(it, "C_FADEOUTSHAPE", shape_idx)
  end
  r.UpdateArrange()
end
return set_item_fades
