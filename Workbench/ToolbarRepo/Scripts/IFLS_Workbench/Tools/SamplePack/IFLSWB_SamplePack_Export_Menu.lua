-- @description IFLS WB: SamplePack Export Menu (DRY / POST-BUS / Last settings)
-- @version 1.0.0
-- @author IFLS Workbench
-- @about Popup menu that runs one of the export scripts: DRY (selected media items), POST-BUS (selected media items via master), or legacy export (last settings).
-- @provides [main] .


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
  gfx.init("IFLSWB Export Menu", 0, 0, 0, 0, 0)
  local choice = gfx.showmenu("Export DRY (items)\nExport POST-BUS (via master)\nExport (last settings)")
  gfx.quit()

  if choice == 1 then
    run("Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Export_SelectedItems_DRY.lua")
  elseif choice == 2 then
    run("Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Export_SelectedItems_POSTBUS.lua")
  elseif choice == 3 then
    run("Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Export_SelectedItems_LastSettings.lua")
  end
end

main()
