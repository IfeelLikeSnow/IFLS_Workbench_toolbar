-- @description IFLS Workbench - Tools/SamplePack/IFLSWB_SamplePack_Pipeline_PostFixHQ_GainDry_ExportPostBus.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS WB: SamplePack Pipeline (PostFix HQ -> GainStage DRY -> Export POST-BUS)
-- @version 1.0.0
-- @author IFLS Workbench
-- @about Runs: PostFix HQ (extend+tail-detect) -> GainStage DRY (peak -3) -> Export POST-BUS (selected items via master: FX-Bus -> Coloring -> Master).


local r = reaper

local function join(a,b)
  if a:sub(-1) == "/" or a:sub(-1) == "\" then return a..b end
  local sep = r.GetOS():match("Win") and "\" or "/"
  return a..sep..b
end

local function file_exists(p)
  local f = io.open(p,"rb")
  if f then f:close() return true end
  return false
end

local function run(rel)
  local abs = join(r.GetResourcePath(), rel)
  if not file_exists(abs) then return false end
  local cmd = r.AddRemoveReaScript(true, 0, abs, true)
  if cmd and cmd ~= 0 then r.Main_OnCommand(cmd, 0); return true end
  return false
end

local function main()
  local ok1 = run("Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_PostFix_Extend_And_TailDetect.lua")
  local ok2 = run("Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_GainStage_SelectedItems_DRY.lua")
  local ok3 = run("Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Export_SelectedItems_POSTBUS.lua")
  if not (ok1 and ok2 and ok3) then
    r.MB("Pipeline could not find/register one or more component scripts.", "IFLSWB Pipeline", 0)
  end
end

main()
