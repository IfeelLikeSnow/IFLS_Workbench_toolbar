-- @description IFLS Workbench - Tools/IFLS_Workbench_Preflight.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_Workbench_Preflight.lua
-- V58: One-click preflight for a machine.
-- Runs:
-- - Workbench Doctor
-- - Workbench SelfTest
-- - Validate Data JSON (local)
--
-- Note: these scripts show their own dialogs; run one by one.

local r = reaper
local base = r.GetResourcePath().."/Scripts"

local function run(rel)
  local path = base.."/"..rel
  local f = io.open(path, "rb")
  if not f then
    r.MB("Missing script:\n"..path, "IFLS Preflight", 0)
    return false
  end
  f:close()
  dofile(path)
  return true
end

run("IFLS_Workbench/Tools/IFLS_Workbench_Doctor.lua")
run("IFLS_Workbench/Tools/IFLS_Workbench_SelfTest.lua")
run("IFLS_Workbench/Tools/IFLS_Workbench_Validate_Data_JSON.lua")

-- Optional: PSS580 module lives under Scripts/IFLS_Workbench/PSS580/

-- V65: Doctor v2 available: Tools/IFLS_Workbench_Doctor_v2.lua
