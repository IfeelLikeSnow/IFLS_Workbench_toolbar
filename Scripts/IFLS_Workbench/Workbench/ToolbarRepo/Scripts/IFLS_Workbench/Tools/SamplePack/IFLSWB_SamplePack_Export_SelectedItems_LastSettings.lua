-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Export_SelectedItems_LastSettings.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS WB: SamplePack Export (Render selected items via master, last settings)
-- @version 1.0.0
-- @author IFLS Workbench
-- @about Sets render bounds to selected media items, sets output folder/pattern, then triggers "Render project using the most recent render settings" (41824).


local r = reaper

local function ensure_dir(path)
  r.RecursiveCreateDirectory(path, 0)
end

local function main()
  local n = r.CountSelectedMediaItems(0)
  if n == 0 then
    r.MB("Select items to export.", "IFLSWB Export Selected Items", 0)
    return
  end

  local proj_path = r.GetProjectPath("")
  local out_dir = r.GetOS():match("Win") and (proj_path .. "\\Rendered\\SamplePack") or (proj_path .. "/Rendered/SamplePack")
  ensure_dir(out_dir)

  r.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 4, true) -- 4=selected media items
  r.GetSetProjectInfo_String(0, "RENDER_FILE", out_dir, true)
  r.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$item", true)
  r.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", 0, true)

  r.Main_OnCommand(41824, 0)
end

r.Undo_BeginBlock()
main()
r.Undo_EndBlock("IFLS WB: Export selected items (last settings)", -1)
