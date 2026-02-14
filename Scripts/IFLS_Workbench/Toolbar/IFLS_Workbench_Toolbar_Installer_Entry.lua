-- @description IFLS Workbench - Toolbar/IFLS_Workbench_Toolbar_Installer_Entry.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_Workbench_Toolbar_Installer_Entry.lua
-- V55 merge: Convenience entry point that runs the toolbar repo installer script if present.
--
-- This exists so you can keep the toolbar repo versioned inside Workbench,
-- but still have a single action to run from REAPER.

local r = reaper
local Boot_ok, Boot = pcall(require, "IFLS_Workbench/_bootstrap")
if not Boot_ok then Boot = nil end

local function run_script(relpath)
  local full = (Boot and Boot.scripts_root or r.GetResourcePath().."/Scripts") .. "/" .. relpath
  if not (Boot and Boot.file_exists and Boot.file_exists(full)) then
    local f = io.open(full, "rb")
    if f then f:close() else
      r.MB("Installer not found:\n"..full, "IFLS Toolbar", 0)
      return
    end
  end
  dofile(full)
end

-- Prefer toolbar repo installer if present:
run_script("IFLS_Workbench/IFLS_Workbench_Install_Toolbar.lua")
