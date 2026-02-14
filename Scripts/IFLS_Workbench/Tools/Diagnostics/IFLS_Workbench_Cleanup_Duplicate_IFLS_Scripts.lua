-- @description IFLS Workbench - Tools/Diagnostics/IFLS_Workbench_Cleanup_Duplicate_IFLS_Scripts.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS (compat stub): IFLS_Cleanup_Duplicate_IFLS_Scripts.lua -> IFLS_Workbench_Cleanup_Duplicate_Workbench_Scripts.lua
-- @version 0.7.8
-- @author IFLS
-- @about Compatibility wrapper. Use the IFLS_Workbench version going forward.


local r = reaper
local function join(a,b)
  local sep = package.config:sub(1,1)
  if a:sub(-1)==sep then return a..b end
  return a..sep..b
end

local path = join(join(join(join(r.GetResourcePath(),"Scripts"),"IFLS_Workbench"),"Tools"), join("Diagnostics","IFLS_Workbench_Cleanup_Duplicate_Workbench_Scripts.lua"))
dofile(path)
