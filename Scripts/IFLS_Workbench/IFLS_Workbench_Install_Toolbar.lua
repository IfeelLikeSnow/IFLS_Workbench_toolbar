-- @description IFLS Workbench: Install helpers (register scripts + open toolbar customization)
-- @version 1.0
-- @author I feel like snow
-- @about
--   Convenience helper after installing via ReaPack/ZIP:
--   1) Ensures the IFLS Workbench scripts are registered in the Action List.
--   2) Opens the toolbar customization dialog so you can add the actions quickly.
--
--   Note: ReaPack usually registers scripts automatically. This helper is safe to run anyway.

local r = reaper

local function script_dir()
  local src = debug.getinfo(1, "S").source
  return (src:match("@(.*[\\/])") or "")
end

local function register(path)
  -- section 0 = Main
  r.AddRemoveReaScript(true, 0, path, true)
end

local base = script_dir()

register(base .. "IFLS_Workbench_Explode_Fieldrec.lua")
register(base .. "IFLS_Workbench_Explode_AutoBus_Smart_Route.lua")
register(base .. "IFLS_Workbench_PolyWAV_Toolbox.lua")

r.ShowMessageBox(
  "IFLS Workbench scripts registered.\n\n" ..
  "Next: Actions > Show action list... and search for 'IFLS Workbench'.\n" ..
  "To add a toolbar button: right-click a toolbar > Customize... > Add action.",
  "IFLS Workbench", 0
)

-- Open toolbar customization window (native action)
-- Options: Customize toolbars...
r.Main_OnCommand(42174, 0)
