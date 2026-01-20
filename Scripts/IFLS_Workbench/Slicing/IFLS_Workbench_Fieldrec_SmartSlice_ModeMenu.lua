-- @description IFLS Workbench - Fieldrec SmartSlice (Mode Menu + HQ Toggle) [v3]
-- @version 3.0.0
-- @author IFLS Workbench
-- @about
--   Popup menu:
--     1) SmartSlice: Hits
--     2) SmartSlice: Textures
--     3) SmartSlice: Auto (per-item classification)
--     4) Toggle HQ Mode (zero-cross snap) [stored]

local core = dofile((reaper.GetResourcePath().."/Scripts/IFLS_Workbench/Slicing/IFLSWB_Fieldrec_SmartSlicer_Core.lua"))

if not gfx or not gfx.init then
  reaper.ShowMessageBox("gfx API not available.", "IFLSWB SmartSlicer", 0)
  return
end

gfx.init("IFLSWB SmartSlicer Menu", 0,0,0,0,0)
gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y

local function hq_label()
  local v = reaper.GetExtState("IFLSWB_SmartSlicer","HQ")
  if v=="" then v="1" end
  return (v=="1") and "HQ: ON" or "HQ: OFF"
end

local menu =
  "SmartSlice: Hits|SmartSlice: Textures|SmartSlice: Auto||Toggle "..hq_label().."|Cancel"

local choice = gfx.showmenu(menu)
gfx.quit()

if choice == 1 then core.run("hits")
elseif choice == 2 then core.run("textures")
elseif choice == 3 then core.run("auto")
elseif choice == 5 then core.toggle_hq()
end
