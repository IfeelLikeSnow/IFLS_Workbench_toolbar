-- @description IFLS Workbench: Smart Slice -> TailTrim -> Spread (one-shot macro)
-- @author IFLS / DF95
-- @version 0.7.6
-- @about
--   Convenience macro if you prefer one entry in the Action List.
--   Calls the Smart Slice script, then trims tails and spreads slices with gaps.

local r = reaper

local function join(a,b)
  local sep = package.config:sub(1,1)
  if a:sub(-1) == sep then return a..b end
  return a..sep..b
end

local rp = r.GetResourcePath()
local base = join(join(rp,"Scripts"), "IFLS_Workbench")

local function run_script(rel)
  local p = join(base, rel)
  local f = io.open(p, "r")
  if not f then
    r.MB("Missing script:\n\n"..p, "IFLS Macro", 0)
    return false
  end
  f:close()
  dofile(p)
  return true
end

-- 1) Smart Slice (creates/moves slices)
if not run_script(join("Slicing","IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.lua")) then return end

-- 2) Tail trim selected items (if any)
run_script(join("Tools","IFLS_Workbench_Slicing_TailTrim_SelectedItems.lua"))

-- 3) Spread selected items (if any)
run_script(join("Tools","IFLS_Workbench_Slicing_Spread_SelectedItems_With_Gaps.lua"))
