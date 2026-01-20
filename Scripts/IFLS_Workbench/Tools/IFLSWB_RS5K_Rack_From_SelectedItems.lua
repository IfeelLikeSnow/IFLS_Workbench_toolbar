-- @description IFLS Workbench - Build RS5K Rack from Selected Items (basic)
-- @author IFLS / DF95
-- @version 0.4.0
-- @about
-- Creates a new track "RS5K Rack" and inserts one ReaSamplOmatic5000 instance per selected item,
-- loading the item's source file into FILE0 and committing via "DONE".
-- Note: mapping (note ranges) is left at defaults; adjust within RS5K or extend this script later.

local r = reaper

local function get_take_source_path(take)
  local src = r.GetMediaItemTake_Source(take)
  if not src then return nil end
  local buf = ""
  local ok, fn = r.GetMediaSourceFileName(src, buf)
  if ok and fn and fn ~= "" then return fn end
  return nil
end

local proj = 0
local n = r.CountSelectedMediaItems(proj)
if n == 0 then r.MB("Select sliced items first.", "RS5K Rack", 0) return end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

local idx = r.CountTracks(proj)
r.InsertTrackAtIndex(idx, true)
local tr = r.GetTrack(proj, idx)
r.GetSetMediaTrackInfo_String(tr, "P_NAME", "RS5K Rack", true)

for i=0,n-1 do
  local item = r.GetSelectedMediaItem(proj, i)
  local take = item and r.GetActiveTake(item)
  local fn = take and get_take_source_path(take)
  if fn then
    local fx = r.TrackFX_AddByName(tr, "ReaSamplOmatic5000", false, -1)
    if fx >= 0 then
      r.TrackFX_SetNamedConfigParm(tr, fx, "FILE0", fn)
      r.TrackFX_SetNamedConfigParm(tr, fx, "DONE", "")
    end
  end
end

r.TrackList_AdjustWindows(false)
r.UpdateArrange()
r.PreventUIRefresh(-1)
r.Undo_EndBlock("Build RS5K Rack from selected items", -1)
