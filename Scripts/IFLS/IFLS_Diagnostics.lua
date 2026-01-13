-- @description IFLS (compat stub): IFLS_Diagnostics.lua -> IFLS_Workbench_Diagnostics.lua
-- @version 0.7.8
-- @author IFLS
-- @about Compatibility wrapper. Use the IFLS_Workbench version going forward.

local r = reaper
local function join(a,b)
  local sep = package.config:sub(1,1)
  if a:sub(-1)==sep then return a..b end
  return a..sep..b
end

local path = join(join(join(join(r.GetResourcePath(),"Scripts"),"IFLS_Workbench"),"Tools"), join("Diagnostics","IFLS_Workbench_Diagnostics.lua"))
dofile(path)
