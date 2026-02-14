-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Menu_JSFX_DSP_Tools.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: JSFX Menu (DSP Tools)
-- @version 0.7.8
-- @author IFLS
-- @about
--   Dropdown menu to insert IFLS Workbench JSFX (DSP) onto selected tracks.
--   JSFX live in <ResourcePath>/Effects/IFLS_Workbench/
--   After installing/updating, use FX browser or TrackFX_AddByName with "JS:".
--   Notes:
--   - Inserts as last FX on each selected track.
--   - If no track selected, inserts on the last touched track (if any), else shows a message.

--

local r = reaper

local FX = {
  {name="IFLS Workbench - Drone Granular Texture"},
  {name="IFLS Workbench - Drum RR & Velocity Mapper (Phase 112)"},
  {name="IFLS Workbench - Dynamic Meter v1 (PeakNorm out)"},
  {name="IFLS Workbench - Euclid Slicer (tempo-synced Euclidean gate)"},
  {name="IFLS Workbench - Granular Hold (micro-grain freeze)"},
  {name="IFLS Workbench - IDM Chopper (tempo-synced gate)"},
  {name="IFLS Workbench - IDM Clicks&Pops Bus Tone"},
  {name="IFLS Workbench - IDM Hats Bus Tone"},
  {name="IFLS Workbench - IDM Kick Bus Tone"},
  {name="IFLS Workbench - IDM MicroPerc Bus Tone"},
  {name="IFLS Workbench - IDM Snare Bus Tone"},
  {name="IFLS Workbench - MIDI Processor (Microtonal / Pitchbend Mapper)"},
  {name="IFLS Workbench - ReampSuite Analyzer FFT"},
  {name="IFLS Workbench - RoundRobin Note Channel Cycler"},
  {name="IFLS Workbench - Stereo Alternator (tempo-synced L/R switcher)"},
}
local function get_targets()
  local t = {}
  local cnt = r.CountSelectedTracks(0)
  for i=0,cnt-1 do
    t[#t+1] = r.GetSelectedTrack(0,i)
  end
  if #t==0 then
    local last = r.GetLastTouchedTrack()
    if last then t[#t+1]=last end
  end
  return t
end

local function insert_fx(track, fxname)
  local add = r.TrackFX_AddByName(track, "JS:"..fxname, false, -1)
  return add ~= -1
end

local function show_menu()
  local menu = ""
  for i=1,#FX do
    menu = menu .. FX[i].name
    if i < #FX then menu = menu .. "|" end
  end
  gfx.init("IFLS JSFX Menu", 0, 0, 0, 0, 0)
  local sel = gfx.showmenu(menu)
  gfx.quit()
  if sel <= 0 then return nil end
  return FX[sel].name
end

local choice = show_menu()
if not choice then return end

local targets = get_targets()
if #targets == 0 then
  r.MB("No selected track and no last-touched track.\n\nSelect a track and re-run.", "IFLS JSFX Menu", 0)
  return
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

for _,tr in ipairs(targets) do
  insert_fx(tr, choice)
end

r.PreventUIRefresh(-1)
r.TrackList_AdjustWindows(false)
r.UpdateArrange()
r.Undo_EndBlock("IFLS: Insert JSFX - "..choice, -1)
