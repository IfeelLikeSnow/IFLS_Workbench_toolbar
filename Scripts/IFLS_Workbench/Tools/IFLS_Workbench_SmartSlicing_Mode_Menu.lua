-- @description IFLS Workbench: Smart Slicing Mode Menu (Normal / Clicks&Pops / Drones)
-- @version 0.7.6
-- @author IFLS
-- @about
--   Dropdown menu to choose Smart Slicing flavor:
--   1) Normal (runs your IFLS pipeline: Smart Slice -> Trim -> Spread)
--   2) Clicks & Pops (pipeline + clickify)
--   3) Drones (pipeline + drone chop)

local r = reaper

local function join(a,b)
  local sep = package.config:sub(1,1)
  if a:sub(-1) == sep then return a..b end
  return a..sep..b
end

local function run_script(path)
  local cmd = r.AddRemoveReaScript(true, 0, path, true)
  if not cmd or cmd == 0 then
    r.MB("Could not register/run:\n\n"..path, "IFLS Smart Slicing Menu", 0)
    return false
  end
  r.Main_OnCommand(cmd, 0)
  return true
end

local function show_menu()
  local x, y = r.GetMousePosition()
  gfx.init("", 0, 0, 0, x, y)
  local choice = gfx.showmenu("Smart Slice: Normal|Smart Slice: Clicks & Pops|Smart Slice: Drones|>Helpers|Select items on IFLS Slices tracks|<")
  gfx.quit()
  return choice
end

local rp = r.GetResourcePath()
local base = join(join(rp, "Scripts"), "IFLS_Workbench")
local slicing = join(base, "Slicing")
local tools   = join(base, "Tools")

-- If your pipeline wrapper has a different name, adjust this:
local pipeline = join(slicing, "IFLS_Workbench_Slice_Smart_Trim_And_Spread.lua")

local select_items = join(tools, "IFLS_Workbench_Select_Items_On_IFLS_Slices_Tracks.lua")
local clickify     = join(tools, "IFLS_Workbench_Slicing_Clickify_SelectedItems.lua")
local dronechop     = join(tools, "IFLS_Workbench_Slicing_DroneChop_SelectedItems.lua")

local choice = show_menu()
if choice == 0 then return end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

if choice == 1 then
  run_script(pipeline)
elseif choice == 2 then
  run_script(pipeline)
  run_script(select_items)
  run_script(clickify)
elseif choice == 3 then
  run_script(pipeline)
  run_script(select_items)
  run_script(dronechop)
elseif choice == 5 then
  run_script(select_items)
end

r.PreventUIRefresh(-1)
r.UpdateArrange()
r.Undo_EndBlock("IFLS: Smart slicing mode menu", -1)
