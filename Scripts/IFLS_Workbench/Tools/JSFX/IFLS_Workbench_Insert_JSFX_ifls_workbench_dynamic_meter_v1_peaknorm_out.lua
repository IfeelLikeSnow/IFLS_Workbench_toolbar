-- @description IFLS Workbench - Tools/JSFX/IFLS_Workbench_Insert_JSFX_ifls_workbench_dynamic_meter_v1_peaknorm_out.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Insert JSFX - IFLS Workbench - Dynamic Meter v1 (PeakNorm out)
-- @version 0.7.8
-- @author IFLS
-- @about Inserts the JSFX "IFLS Workbench - Dynamic Meter v1 (PeakNorm out)" onto all selected tracks (or last touched track).


local r = reaper

local SafeApply = require("IFLS_Workbench/Engine/IFLS_SafeApply")
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

local fxname = 'IFLS Workbench - Dynamic Meter v1 (PeakNorm out)'

local targets = get_targets()
if #targets == 0 then
  r.MB("No selected track and no last-touched track.", "IFLS Insert JSFX", 0)
  return
end

return SafeApply.run("IFLS: IFLS Workbench Insert JSFX ifls workbench dynamic meter v1 peaknorm out", function()
for _,tr in ipairs(targets) do
  r.TrackFX_AddByName(tr, "JS:"..fxname, false, -1)
end
r.TrackList_AdjustWindows(false)
r.UpdateArrange()
