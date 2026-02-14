-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Export_SelectedItems_POSTBUS.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS WB: SamplePack Export POST-BUS (Selected items via master)
-- @version 1.0.1
-- @author IFLS Workbench
-- @about Renders each selected item *via master* (includes FX-Bus -> Coloring -> Master routing), using render bounds=Selected media items and render source=Selected media items via master.


local r = reaper

local function ensure_dir(path)
  r.RecursiveCreateDirectory(path, 0)
end

local function get_str(key)
  local _, v = r.GetSetProjectInfo_String(0, key, "", false)
  return v
end

local function set_str(key, val)
  r.GetSetProjectInfo_String(0, key, tostring(val or ""), true)
end

local function main()
  if r.CountSelectedMediaItems(0) == 0 then
    r.MB("Select items to export.", "IFLSWB Export POST-BUS", 0)
    return
  end

  -- Output folder: <project>/Rendered/SamplePack/POSTBUS
  local proj_path = r.GetProjectPath("")
  if not proj_path or proj_path == "" then
    proj_path = r.GetResourcePath()
  end
  local sep = r.GetOS():match("Win") and "\" or "/"
  local out_dir = proj_path .. sep .. "Rendered" .. sep .. "SamplePack" .. sep .. "POSTBUS"
  ensure_dir(out_dir)


  -- De-duplicate selection by time-range (helps multi-mic: avoids rendering the same slice N times).
  local sel_items = {}
  local sel_cnt = r.CountSelectedMediaItems(0)
  for i = 0, sel_cnt-1 do
    local it = r.GetSelectedMediaItem(0, i)
    if it then
      local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
      local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
      sel_items[#sel_items+1] = { item=it, pos=pos, len=len }
    end
  end

  local function key(pos, len)
    -- 1e-4s quantization is usually safe; adjust if you do sub-ms slicing
    return string.format("%.4f|%.4f", pos, len)
  end

  local kept = {}
  local kept_list = {}
  for _,x in ipairs(sel_items) do
    local k = key(x.pos, x.len)
    if not kept[k] then
      kept[k] = x.item
      kept_list[#kept_list+1] = x.item
    end
  end

  if #kept_list < #sel_items then
    -- Replace selection with unique slice ranges
    r.SelectAllMediaItems(0, false)
    for _,it in ipairs(kept_list) do
      r.SetMediaItemSelected(it, true)
    end
    r.UpdateArrange()
  end

  -- Save current render settings (so we don't permanently change user prefs)
  local old_settings = r.GetSetProjectInfo(0, "RENDER_SETTINGS", 0, false)
  local old_bounds   = r.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 0, false)
  local old_addproj  = r.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", 0, false)
  local old_file     = get_str("RENDER_FILE")
  local old_pattern  = get_str("RENDER_PATTERN")

  -- Force: bounds = selected media items; source = selected media items via master (POST-BUS)
  r.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 4, true) -- 4=selected media items

  local SOURCE_MASK = 1+2+8+32+64+128 -- bits that define source (master/stems/render-matrix/selected items/via master)
  local new_settings = (old_settings & (~SOURCE_MASK)) | 64 -- 64 = selected media items via master
  r.GetSetProjectInfo(0, "RENDER_SETTINGS", new_settings, true)

  set_str("RENDER_FILE", out_dir)
  set_str("RENDER_PATTERN", "$item")
  r.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", 0, true)

  -- Render project using most recent settings (offline), respecting the forced source/bounds.
  r.Main_OnCommand(41824, 0)

  -- Restore
  -- Restore original item selection
  if sel_items and #sel_items > 0 then
    r.SelectAllMediaItems(0, false)
    for _,x in ipairs(sel_items) do r.SetMediaItemSelected(x.item, true) end
    r.UpdateArrange()
  end

  r.GetSetProjectInfo(0, "RENDER_SETTINGS", old_settings, true)
  r.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", old_bounds, true)
  r.GetSetProjectInfo(0, "RENDER_ADDTOPROJ", old_addproj, true)
  set_str("RENDER_FILE", old_file)
  set_str("RENDER_PATTERN", old_pattern)
end

r.Undo_BeginBlock()
main()
r.Undo_EndBlock("IFLS WB: Export POST-BUS (selected items via master)", -1)
