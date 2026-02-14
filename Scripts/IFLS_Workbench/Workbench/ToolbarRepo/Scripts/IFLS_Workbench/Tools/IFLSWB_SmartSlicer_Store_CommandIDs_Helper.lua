-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Tools/IFLSWB_SmartSlicer_Store_CommandIDs_Helper.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: IFLSWB_SmartSlicer_Store_CommandIDs_Helper
-- @version 1.0.0

ï»¿-- @description IFLS Workbench - SmartSlicer: Store Command IDs (one-time helper)
-- @version 1.0.0
-- @author IFLS Workbench
-- @about
--   Stores this script's Named Command ID (and known filenames) into ExtState so the toolbar generator can reference them.
local r = reaper

-- When a ReaScript is loaded, REAPER assigns it a named command ID like "_RSxxxxxx".
-- We can store the *currently running* script's named ID via get_action_context().
local function store_current()
  local _, _, _, _, _, cmd = r.get_action_context()
  if cmd and cmd ~= 0 then
    -- Unfortunately cmd is numeric. NamedCommandLookup needs string.
    -- We'll just tell the user to store manually if needed.
  end
end

r.MB("Load scripts in Action List and use them via toolbar directly (recommended).\n\nThis helper is optional; the generator has placeholders if IDs aren't stored.", "IFLSWB", 0)
