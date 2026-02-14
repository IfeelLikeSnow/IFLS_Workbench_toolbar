-- @description IFLS Workbench - IFLS_Workbench_Toolbar_Generate_ReaperMenu.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Generate toolbar .ReaperMenu (floating toolbar import file)
-- @version 0.3
-- @author I feel like snow
-- @about
--   Creates a ready-to-import .ReaperMenu file for a Floating Toolbar (1-16).
--   This avoids the "custom script command IDs differ per install" problem by:
--     - registering the scripts into your Action List (AddRemoveReaScript),
--     - writing the toolbar file using the returned command ID numbers.
--   After running:
--     Options -> Customize toolbars... -> (pick toolbar) -> Import... -> select the created .ReaperMenu

--
--
local r = reaper

local function join(a,b)
  if not a or a=="" then return b end
  local sep = package.config:sub(1,1)
  if a:sub(-1) == sep or a:sub(-1) == "/" then return a .. b end
  return a .. sep .. b
end

local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

local function write_file(path, content)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

local function open_folder(path)
  if r.CF_ShellExecute then
    r.CF_ShellExecute(path)
    return
  end
  r.ShowMessageBox("Open this folder manually:\n\n"..path, "IFLS Toolbar", 0)
end

local res = r.GetResourcePath()
local ok, tb = r.GetUserInputs("IFLS Toolbar", 1, "Floating toolbar number (1-16)", "16")
if not ok then return end

local tb_num = tonumber(tb) or 16
if tb_num < 1 then tb_num = 1 end
if tb_num > 16 then tb_num = 16 end

local entries = {
  {"Explode Fieldrec + MicFX + Buses", "Scripts/IFLS_Workbench/IFLS_Workbench_Explode_Fieldrec.lua", "IFLSWB_explode"},
  {"PolyWAV Toolbox (ImGui)",          "Scripts/IFLS_Workbench/IFLS_Workbench_PolyWAV_Toolbox.lua", "IFLSWB_polywav"},
  {"Slice Smart (print bus -> slice)", "Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.lua", "IFLSWB_slicesmart"},
  {"Slicing dropdown menu",            "Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Menu_Slicing_Dropdown.lua", "IFLSWB_slicemenu"},
  {"Install helpers (register scripts)", "Scripts/IFLS_Workbench/IFLS_Workbench_Install_Toolbar.lua", "IFLSWB_install"},
  {"Diagnostics",                      "Scripts/IFLS/IFLS_Diagnostics.lua", "IFLSWB_diag"},
  {"Cleanup duplicates",               "Scripts/IFLS/IFLS_Cleanup_Duplicate_IFLS_Scripts.lua", "IFLSWB_cleanup"},
}


-- Register scripts to Action List (main section = 0)
local cmd_ids = {}
for i, e in ipairs(entries) do
  local full = join(res, e[2]):gsub("/", package.config:sub(1,1))
  if not file_exists(full) then
    cmd_ids[i] = 0
  else
    local commit = (i == #entries)
    local cmd = r.AddRemoveReaScript(true, 0, full, commit)
    cmd_ids[i] = cmd or 0
  end
end

-- Generate .ReaperMenu content (same syntax rules as reaper-menu.ini)
local lines = {}
table.insert(lines, "[Floating toolbar "..tb_num.."]")
for i, e in ipairs(entries) do
  local id = i - 1
  local cmd = cmd_ids[i]
  if cmd and cmd ~= 0 then
    local ic = e[3] or "text"
    table.insert(lines, "icon_"..id.."="..ic)
    table.insert(lines, "item_"..id.."="..cmd.." IFLS WB: "..e[1])
  else
    -- keep placeholder so user sees what's missing
    local ic = e[3] or "text"
    table.insert(lines, "icon_"..id.."="..ic)
    table.insert(lines, "item_"..id.."=-4 MISSING: "..e[2])
  end
end
local content = table.concat(lines, "\r\n") .. "\r\n"

local menusets = join(res, "MenuSets")
r.RecursiveCreateDirectory(menusets, 0)

local out = join(menusets, string.format("IFLS_Workbench_TB%d.ReaperMenu", tb_num))
if write_file(out, content) then
  open_folder(menusets)
  r.ShowMessageBox(
    "Toolbar file generated:\n\n"..out.."\n\nNext:\nOptions -> Customize toolbars... -> Import... -> pick this file.",
    "IFLS Toolbar", 0
  )
else
  r.ShowMessageBox("Couldn't write:\n\n"..out, "IFLS Toolbar", 0)
end
