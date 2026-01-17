-- @description IFLS Workbench: Generate toolbar .ReaperMenu (floating toolbar import file)
-- @version 0.3
-- @author I feel like snow
-- @about
--   Creates a ready-to-import .ReaperMenu file for a Floating Toolbar (1-16).
--   This avoids the "custom script command IDs differ per install" problem by:
--     - registering the scripts into your Action List (AddRemoveReaScript),
--     - writing the toolbar file using the returned command ID numbers.
--

--   After running:
--     Options -> Customize toolbars... -> (pick toolbar) -> Import... -> select the created .ReaperMenu
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
  {"JSFX Menu (DSP Tools)", "Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Menu_JSFX_DSP_Tools.lua", "IFLSWB_jsfx_menu"},
  {"Insert JSFX: Dynamic Meter", "Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Insert_JSFX_ifls_workbench_dynamic_meter_v1_peaknorm_out.lua", "IFLSWB_jsfx_meter"},
  {"Insert JSFX: Analyzer FFT", "Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Insert_JSFX_ifls_workbench_reampsuite_analyzer_fft.lua", "IFLSWB_jsfx_fft"},
  {"Insert JSFX: Euclid Slicer", "Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Insert_JSFX_ifls_workbench_euclid_slicer_tempo_synced_euclidean_gate.lua", "IFLSWB_jsfx_euclid"},
  {"Insert JSFX: IDM Chopper", "Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Insert_JSFX_ifls_workbench_idm_chopper_tempo_synced_gate.lua", "IFLSWB_jsfx_idm"},
  {"Insert JSFX: Drone Granular", "Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Insert_JSFX_ifls_workbench_drone_granular_texture.lua", "IFLSWB_jsfx_drone"},

  {"Explode Fieldrec + MicFX + Buses", "Scripts/IFLS_Workbench/IFLS_Workbench_Explode_Fieldrec.lua", "IFLSWB_explode"},
  {"PolyWAV Toolbox (ImGui)",          "Scripts/IFLS_Workbench/IFLS_Workbench_PolyWAV_Toolbox.lua", "IFLSWB_polywav"},

  {"Slicing dropdown menu",            "Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Menu_Slicing_Dropdown.lua", "IFLSWB_slice_menu"},
  {"Smart Slice (PrintBus -> Slice)",  "Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.lua", "IFLSWB_smart_slice"},
  {"SmartSlicing Mode Menu",           "Scripts/IFLS_Workbench/Tools/IFLS_Workbench_SmartSlicing_Mode_Menu.lua", "IFLSWB_smart_slicing_mode_menu"},
  {"Slicing Control Panel (ReaImGui)", "Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_Control_Panel_ReaImGui.lua", "IFLSWB_slicing_control_panel"},

  {"TailTrim selected slices",         "Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_TailTrim_SelectedItems.lua", "IFLSWB_tailtrim"},
  {"Spread slices with gaps",          "Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_Spread_SelectedItems_With_Gaps.lua", "IFLSWB_spread_slices"},
  {"Clickify (Clicks & Pops)",         "Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_Clickify_SelectedItems.lua", "IFLSWB_clickify"},
  {"DroneChop (Drones)",               "Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_DroneChop_SelectedItems.lua", "IFLSWB_dronechop"},
  {"Toggle ZeroCross",                 "Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_Toggle_ZeroCross.lua", "IFLSWB_toggle_zerocross"},
  {"ZeroCross PostFix",                "Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_ZeroCross_PostFix.lua", "IFLSWB_zerocross_postfix"},

  {"Install helpers (register scripts)", "Scripts/IFLS_Workbench/IFLS_Workbench_Install_Toolbar.lua", "IFLSWB_install"},
  {"Diagnostics",                      "Scripts/IFLS_Workbench/Tools/Diagnostics/IFLS_Workbench_Diagnostics.lua", "IFLSWB_diag"},
  {"Cleanup duplicates",               "Scripts/IFLS_Workbench/Tools/Diagnostics/IFLS_Workbench_Cleanup_Duplicate_Workbench_Scripts.lua", "IFLSWB_cleanup"},
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
