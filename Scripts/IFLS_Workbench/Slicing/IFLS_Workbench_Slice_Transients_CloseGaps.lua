-- @description IFLS Workbench: Slice at transients (SWS) + close gaps + mute source
-- @version 1.0
-- @author IFLS
-- @about
--   Creates individual slices by splitting at transients (requires SWS).
--   Then removes the gaps between the resulting slices (butts items together).
--   Intended for IDM/Glitch sample-chain creation from field recordings.
--
--   Usage:
--     - Select one or more items (or select tracks; script will use all items on selected tracks).
--     - Run script.
--
--   Notes:
--     - This changes timing (it closes gaps). Use on a duplicated/printed track if you need original timing.

local r = reaper

local function msg(s) r.ShowMessageBox(s, "IFLS Workbench", 0) end

local function get_selected_items_fallback_tracks()
  local items = {}
  local selItemCount = r.CountSelectedMediaItems(0)
  if selItemCount > 0 then
    for i=0, selItemCount-1 do
      items[#items+1] = r.GetSelectedMediaItem(0, i)
    end
    return items
  end
  local selTrCount = r.CountSelectedTracks(0)
  if selTrCount == 0 then return items end
  for t=0, selTrCount-1 do
    local tr = r.GetSelectedTrack(0, t)
    local ic = r.CountTrackMediaItems(tr)
    for i=0, ic-1 do
      items[#items+1] = r.GetTrackMediaItem(tr, i)
    end
  end
  return items
end

local function sort_items_by_pos(items)
  table.sort(items, function(a,b)
    local pa = r.GetMediaItemInfo_Value(a, "D_POSITION")
    local pb = r.GetMediaItemInfo_Value(b, "D_POSITION")
    if pa == pb then
      local la = r.GetMediaItemInfo_Value(a, "D_LENGTH")
      local lb = r.GetMediaItemInfo_Value(b, "D_LENGTH")
      return la < lb
    end
    return pa < pb
  end)
end

local function find_track_by_name(nameLower)
  local proj = 0
  local n = r.CountTracks(proj)
  for i=0, n-1 do
    local tr = r.GetTrack(proj, i)
    local _, nm = r.GetTrackName(tr)
    if nm and nm:lower() == nameLower then return tr, i end
  end
  return nil, nil
end

local function insert_track_at(idx)
  r.InsertTrackAtIndex(idx, true)
  r.TrackList_AdjustWindows(false)
  return r.GetTrack(0, idx)
end

local function duplicate_items_to_track(srcItems, dstTrack)
  local newItems = {}
  for _, it in ipairs(srcItems) do
    local take = r.GetActiveTake(it)
    if take then
      local src = r.GetMediaItemTake_Source(take)
      local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
      local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
      local newIt = r.AddMediaItemToTrack(dstTrack)
      r.SetMediaItemInfo_Value(newIt, "D_POSITION", pos)
      r.SetMediaItemInfo_Value(newIt, "D_LENGTH", len)

      local newTake = r.AddTakeToMediaItem(newIt)
      r.SetMediaItemTake_Source(newTake, src)
      -- copy take offset / playrate
      local offs = r.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
      local pr = r.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
      r.SetMediaItemTakeInfo_Value(newTake, "D_STARTOFFS", offs)
      r.SetMediaItemTakeInfo_Value(newTake, "D_PLAYRATE", pr)
      -- set active take
      r.SetActiveTake(newTake)
      newItems[#newItems+1] = newIt
    end
  end
  return newItems
end

local function select_only_items(items)
  r.SelectAllMediaItems(0, false)
  for _, it in ipairs(items) do
    r.SetMediaItemSelected(it, true)
  end
end

local function get_items_on_track(track)
  local out = {}
  local n = r.CountTrackMediaItems(track)
  for i=0, n-1 do
    out[#out+1] = r.GetTrackMediaItem(track, i)
  end
  return out
end

local function close_gaps_on_track(track)
  local items = get_items_on_track(track)
  if #items < 2 then return end
  sort_items_by_pos(items)
  local cur = r.GetMediaItemInfo_Value(items[1], "D_POSITION")
  -- keep first position; butt others to previous end
  for i=2, #items do
    local prev = items[i-1]
    local prevPos = r.GetMediaItemInfo_Value(prev, "D_POSITION")
    local prevLen = r.GetMediaItemInfo_Value(prev, "D_LENGTH")
    local newPos = prevPos + prevLen
    r.SetMediaItemInfo_Value(items[i], "D_POSITION", newPos)
  end
end

local function add_micro_fades(track, fadeLen)
  local items = get_items_on_track(track)
  for _, it in ipairs(items) do
    r.SetMediaItemInfo_Value(it, "D_FADEINLEN", fadeLen)
    r.SetMediaItemInfo_Value(it, "D_FADEOUTLEN", fadeLen)
  end
end

-- MAIN
r.Undo_BeginBlock()
r.PreventUIRefresh(1)

local srcItems = get_selected_items_fallback_tracks()
if #srcItems == 0 then
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock("IFLS slice transients + close gaps", -1)
  msg("No items selected.\nSelect items (or tracks) and run again.")
  return
end

-- choose destination slice track:
-- if FX BUS exists, insert before it, otherwise right below the first source item track
local fxBus, fxIdx = find_track_by_name("fx bus")
local firstIt = srcItems[1]
local srcTrack = r.GetMediaItemTrack(firstIt)
local srcIdx = math.floor(r.GetMediaTrackInfo_Value(srcTrack, "IP_TRACKNUMBER") - 1)

local dstIdx = fxIdx or (srcIdx + 1)
local dstTrack = insert_track_at(dstIdx)
r.GetSetMediaTrackInfo_String(dstTrack, "P_NAME", "IFLS WB - SLICES", true)

-- duplicate items to slice track
local dup = duplicate_items_to_track(srcItems, dstTrack)
select_only_items(dup)

-- split at transients via SWS
local cmd = r.NamedCommandLookup("_XENAKIOS_SPLIT_ITEMSATRANSIENTS")
if cmd == 0 then
  r.PreventUIRefresh(-1)
  r.Undo_EndBlock("IFLS slice transients + close gaps", -1)
  msg("SWS action not found:\nXenakios/SWS: Split items at transients\n\nInstall SWS or use Dynamic split items manually, then run only the 'close gaps' script.")
  return
end

local beforeCount = r.CountTrackMediaItems(dstTrack)
r.Main_OnCommand(cmd, 0)
local afterCount = r.CountTrackMediaItems(dstTrack)

-- If nothing changed, warn about transient threshold
if afterCount <= beforeCount then
  -- still close gaps (maybe user already pre-split)
end

-- close gaps + micro fades
close_gaps_on_track(dstTrack)
add_micro_fades(dstTrack, 0.003)

-- mute source track (user-requested default)
r.SetMediaTrackInfo_Value(srcTrack, "B_MUTE", 1)

r.UpdateArrange()
r.PreventUIRefresh(-1)
r.Undo_EndBlock("IFLS: slice at transients + close gaps", -1)

if afterCount <= beforeCount then
  msg("Split at transients produced no new splits.\n\nTip:\n- Try a more percussive section\n- Adjust transient sensitivity (SWS/Xenakios) or use REAPER 'Dynamic split items' and rerun this script.\n\nGaps were still closed on the slice track (if multiple items existed).")
end
