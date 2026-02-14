-- @description IFLS Workbench - Tools/IFLSWB_Generate_IFLSWB_Toolbar_ReaperMenu_v2.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS WB: Generate Toolbar v2 (no individual JSFX buttons)
-- @version 2.0.0
-- @author IFLS Workbench
-- @about
--   Generates a .ReaperMenu toolbar definition that contains IFLS Workbench core buttons,
--   but removes the individual "Insert JSFX: ..." buttons (use the JSFX Menu instead).
--   This script is safe to run multiple times; it (re)creates the .ReaperMenu file.


--[[---------------------------------------------------------------------------
HOW TO USE (quick):
1) Run this script once. It writes a .ReaperMenu file into:
     REAPER resource path/MenuSets/IFLSWB_Toolbar_v2.ReaperMenu
2) In REAPER: Options -> Customize menus/toolbars...
   Choose the toolbar you want (e.g. Floating toolbar 1)
   Click Import/Export -> Import... and pick the generated file.
---------------------------------------------------------------------------]]--

local function msg(s) reaper.ShowConsoleMsg(tostring(s).."\n") end

local function join(a,b)
  if a:sub(-1) == "\\" or a:sub(-1) == "/" then return a..b end
  return a.."/"..b
end

local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close() return true end
  return false
end

local function ensure_dir(p)
  -- RecursiveCreateDirectory wants a path and ignored second param
  reaper.RecursiveCreateDirectory(p, 0)
end

local function register_script(abs_path)
  -- Registers into Main section (0). commit=true writes to reaper-kb.ini, so Named IDs persist.
  local cmd = reaper.AddRemoveReaScript(true, 0, abs_path, true)
  if not cmd or cmd == 0 then return nil end
  local named = reaper.ReverseNamedCommandLookup(cmd) -- without leading underscore
  if not named or named == "" then return nil end
  return "_"..named
end

local function make_button(named_cmd, is_toggle, icon, text, tooltip)
  -- Exported toolbar files often use this format:
  -- BUTTON " _RSxxxx" 0 "icon" "text" "tooltip" ""
  -- Keep fields simple; user can assign icons later.
  icon = icon or ""
  text = text or ""
  tooltip = tooltip or ""
  local t = is_toggle and 1 or 0
  return string.format('BUTTON "%s" %d "%s" "%s" "%s" ""', named_cmd, t, icon, text, tooltip)
end

-- Ordered list of toolbar entries.
-- We resolve by script file path under ResourcePath.
-- Missing files are skipped (the generator prints a summary).
local entries = {
  { rel="Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Menu_JSFX_DSP_Tools.lua", toggle=false, label="IFLS WB: JSFX Menu (DSP Tools)" },

  { rel="Scripts/IFLS_Workbench/IFLS_Workbench_Explode_Fieldrec.lua", toggle=false, label="IFLS WB: Explode Fieldrec + MicFX + Buses" },

  -- New: topology-based Reamp Print Toggle (from FX bus)
  { rel="Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Reamp_Print_Toggle_From_FXBus.lua", toggle=true, label="IFLS WB: Reamp Print Toggle (FX -> Print)" },

  { rel="Scripts/IFLS_Workbench/IFLS_Workbench_PolyWAV_Toolbox.lua", toggle=false, label="IFLS WB: PolyWAV Toolbox (ImGui)" },

  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Menu_Slicing_Dropdown.lua", toggle=false, label="IFLS WB: Slicing dropdown menu" },

  -- Smart Slicing core
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.lua", toggle=false, label="IFLS WB: Smart Slice (PrintBus -> Slice)" },

  -- Optional Fieldrec SmartSlicer helpers (if installed)
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_ModeMenu.lua", toggle=false, label="IFLS WB: SmartSlicing Mode Menu" },
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_HQ_Toggle.lua", toggle=true, label="IFLS WB: SmartSlicer HQ Toggle" },
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_Hits.lua", toggle=false, label="IFLS WB: SmartSlice (Hits)" },
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_Textures.lua", toggle=false, label="IFLS WB: SmartSlice (Textures)" },

  -- Post tools
  { rel="Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_Control_Panel_ReaImGui.lua", toggle=false, label="IFLS WB: Slicing Control Panel (ReaImGui)" },
  { rel="Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_TailTrim_SelectedItems.lua", toggle=false, label="IFLS WB: TailTrim selected slices" },
  { rel="Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_Spread_SelectedItems_With_Gaps.lua", toggle=false, label="IFLS WB: Spread slices with gaps" },
  { rel="Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_Clickify_SelectedItems.lua", toggle=false, label="IFLS WB: Clickify (Clicks & Pops)" },
  { rel="Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Slicing_DroneChop_SelectedItems.lua", toggle=false, label="IFLS WB: DroneChop (Drones)" },

  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_Toggle_ZeroCross.lua", toggle=true, label="IFLS WB: Toggle ZeroCross" },
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_ZeroCross_PostFix.lua", toggle=false, label="IFLS WB: ZeroCross PostFix" },

  -- Helpers
  { rel="Scripts/IFLS_Workbench/IFLS_Workbench_Install_Toolbar.lua", toggle=false, label="IFLS WB: Install helpers (register scripts)" },
  { rel="Scripts/IFLS_Workbench/Tools/Diagnostics/IFLS_Workbench_Diagnostics.lua", toggle=false, label="IFLS WB: Diagnostics" },
  { rel="Scripts/IFLS_Workbench/Tools/Diagnostics/IFLS_Workbench_Cleanup_Duplicate_Workbench_Scripts.lua", toggle=false, label="IFLS WB: Cleanup duplicates" },
}

local resource = reaper.GetResourcePath()
local menusets = join(resource, "MenuSets")
ensure_dir(menusets)

local out_path = join(menusets, "IFLSWB_Toolbar_v2.ReaperMenu")

local resolved = {}
local skipped = {}

for _,e in ipairs(entries) do
  local abs = join(resource, e.rel)
  if file_exists(abs) then
    local named_cmd = register_script(abs)
    if named_cmd then
      table.insert(resolved, {cmd=named_cmd, toggle=e.toggle, label=e.label})
    else
      table.insert(skipped, {rel=e.rel, why="register failed"})
    end
  else
    table.insert(skipped, {rel=e.rel, why="missing file"})
  end
end

-- Build .ReaperMenu content (toolbar export style).
-- We intentionally do NOT include the old individual "Insert JSFX: ..." actions.
local lines = {}
table.insert(lines, 'REAPER_MENU 1.0')
table.insert(lines, 'TB_BEGIN 1 0 0 "IFLS WB - Fieldrec/IDM Toolbar (v2)"')

for _,r in ipairs(resolved) do
  table.insert(lines, make_button(r.cmd, r.toggle, "", "", r.label))
end

table.insert(lines, 'TB_END')

local f, err = io.open(out_path, "wb")
if not f then
  reaper.MB("Failed to write:\n"..out_path.."\n\n"..tostring(err), "IFLSWB Toolbar Generator", 0)
  return
end
f:write(table.concat(lines, "\n"))
f:close()

msg("== IFLSWB Toolbar v2 generated ==")
msg("Wrote: "..out_path)
msg("Buttons: "..tostring(#resolved))
if #skipped > 0 then
  msg("Skipped ("..#skipped.."):")
  for _,s in ipairs(skipped) do
    msg("  - "..s.rel.."  ("..s.why..")")
  end
end

reaper.MB(
  "Toolbar file generated:\n\n"..out_path..
  "\n\nNext:\nOptions -> Customize menus/toolbars...\nSelect a toolbar (e.g. Floating toolbar 1)\nImport/Export -> Import... -> pick IFLSWB_Toolbar_v2.ReaperMenu\n\nNote: individual JSFX-insert buttons were intentionally removed.\nUse the JSFX Menu (DSP Tools).",
  "IFLSWB Toolbar Generator (v2)",
  0
)
