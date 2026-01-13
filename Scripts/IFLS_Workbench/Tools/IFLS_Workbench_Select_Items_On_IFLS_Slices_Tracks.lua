-- @description IFLS Workbench: Select all items on IFLS Slices tracks
-- @version 0.7.6
-- @author IFLS
-- @about
--   Selects all items on tracks named "IFLS Slices" or starting with "IFLS Slices -".
--   Helper for post-processing (trim tails, spread, clickify, drones).

local r = reaper
local PREFIX = "IFLS Slices"

local function track_name(tr)
  local _, name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  return name or ""
end

local function main()
  local n = r.CountTracks(0)
  if n == 0 then return end

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  r.Main_OnCommand(40289, 0) -- Unselect all items

  local selected = 0
  for i=0,n-1 do
    local tr = r.GetTrack(0,i)
    local name = track_name(tr)
    if name == PREFIX or name:find("^"..PREFIX.." %-") then
      local ni = r.CountTrackMediaItems(tr)
      for j=0,ni-1 do
        local it = r.GetTrackMediaItem(tr, j)
        r.SetMediaItemSelected(it, true)
        selected = selected + 1
      end
    end
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS: Select items on IFLS Slices tracks ("..selected..")", -1)
end

main()
