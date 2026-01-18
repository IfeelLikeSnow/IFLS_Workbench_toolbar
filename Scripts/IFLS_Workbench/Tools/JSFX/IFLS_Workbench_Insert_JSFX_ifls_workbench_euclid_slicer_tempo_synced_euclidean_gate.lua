-- @description IFLS Workbench: Insert JSFX - IFLS Workbench - Euclid Slicer (tempo-synced Euclidean gate)
-- @version 0.7.8
-- @author IFLS
-- @about Inserts the JSFX "IFLS Workbench - Euclid Slicer (tempo-synced Euclidean gate)" onto all selected tracks (or last touched track).

local r = reaper

local function get_targets()
  local t = {}
  local cnt = r.CountSelectedTracks(0)
  for i=0,cnt-1 do t[#t+1] = r.GetSelectedTrack(0,i) end
  if #t==0 then
    local last = r.GetLastTouchedTrack()
    if last then t[#t+1]=last end
  end
  return t
end

local fxname = 'IFLS Workbench - Euclid Slicer (tempo-synced Euclidean gate)'

local targets = get_targets()
if #targets == 0 then
  r.MB("No selected track and no last-touched track.", "IFLS Insert JSFX", 0)
  return
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)
for _,tr in ipairs(targets) do
  r.TrackFX_AddByName(tr, "JS:"..fxname, false, -1)
end
r.PreventUIRefresh(-1)
r.TrackList_AdjustWindows(false)
r.UpdateArrange()
r.Undo_EndBlock("IFLS: Insert JSFX - "..fxname, -1)
