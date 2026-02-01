-- @description IFLS WB: Generate Toolbar v3 (SmartSlicing + SamplePack + ReampPrint)
-- @version 3.1.3
-- @author IFLS Workbench
-- @about Generates IFLSWB_Toolbar_v3.ReaperMenu (JSFX menu only + SmartSlicing + SamplePack buttons + ReampPrint + AutoSplit AUTO).
-- @provides [main] .


local r = reaper

local function path_join(a,b)
  if not a or a=="" then return b end
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then return a .. b end
  local sep = r.GetOS():match("Win") and "\\" or "/"
  return a .. sep .. b
end

local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

local function register_script(abs_path)
  local cmd = r.AddRemoveReaScript(true, 0, abs_path, true)
  if not cmd or cmd == 0 then return nil end
  local named = r.ReverseNamedCommandLookup(cmd)
  if not named or named == "" then return nil end
  if named:sub(1,1) ~= "_" then named = "_"..named end
  return named
end

local function make_button(named_cmd, is_toggle, icon, text, tooltip)
  icon = icon or ""
  text = text or ""
  tooltip = tooltip or ""
  local t = is_toggle and 1 or 0
  return string.format('BUTTON "%s" %d "%s" "%s" "%s" ""', named_cmd, t, icon, text, tooltip)
end

local resource = r.GetResourcePath()
local menu_dir = path_join(resource, "MenuSets")
r.RecursiveCreateDirectory(menu_dir, 0)

local entries = {
  { rel="Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Menu_JSFX_DSP_Tools.lua", toggle=false, label="IFLS WB: JSFX Menu (DSP Tools)" },
  { rel="Scripts/IFLS_Workbench/IFLS_Workbench_Explode_Fieldrec.lua", toggle=false, label="IFLS WB: Explode Fieldrec + Buses" },
  { rel="Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Reamp_Print_Toggle_From_FXBus.lua", toggle=true, label="IFLS WB: Reamp Print Toggle (FX -> Print)" },

  -- One-click auto pipeline for mixed fieldrec
  { rel="Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_AutoSplit_Then_SmartSlice_AUTO.lua", toggle=false, label="IFLS WB: AutoSplit + AutoSlice AUTO" },

  -- Smart slicing (manual)
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slice_Smart_PrintBus_Then_Slice.lua", toggle=false, label="IFLS WB: Smart Slice (PrintBus -> Slice)" },
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_ModeMenu.lua", toggle=false, label="IFLS WB: SmartSlicing Mode Menu" },
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_HQ_Toggle.lua", toggle=true, label="IFLS WB: SmartSlicer HQ Toggle" },
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_Hits.lua", toggle=false, label="IFLS WB: SmartSlice (Hits)" },
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_Textures.lua", toggle=false, label="IFLS WB: SmartSlice (Textures)" },

  -- Mixed content splitter (manual)
  { rel="Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_AutoSplit_MixedContent.lua", toggle=false, label="IFLS WB: AutoSplit Mixed Content" },

  -- PostFix
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_PostFix_ExtendSlices_ToNextStart.lua", toggle=false, label="IFLS WB: PostFix Extend -> Next Start" },
  { rel="Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_PostFix_Extend_And_TailDetect.lua", toggle=false, label="IFLS WB: PostFix HQ (Extend + TailDetect)" },

  -- SamplePack buttons
  { rel="Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_GainStage_SelectedItems_DRY.lua", toggle=false, label="IFLS WB: GainStage DRY (peak -3)" },
  { rel="Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_GainStage_SelectedItems_WET.lua", toggle=false, label="IFLS WB: GainStage WET (TP -1)" },
  { rel="Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_GainStage_Loops_LUFSI_TP.lua", toggle=false, label="IFLS WB: GainStage Loops (LUFS-I -> TP)" },
  { rel="Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Export_SelectedItems_DRY.lua", toggle=false, label="IFLS WB: Export DRY (items)" },
  { rel="Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Export_SelectedItems_POSTBUS.lua", toggle=false, label="IFLS WB: Export POST-BUS (via master)" },
  { rel="Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Export_Menu.lua", toggle=false, label="IFLS WB: Export Menu (DRY/POST/Last)" },
  { rel="Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Export_SelectedItems_LastSettings.lua", toggle=false, label="IFLS WB: Export selected items (last settings)" },
  { rel="Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Pipeline_PostFixHQ_GainWet_Export.lua", toggle=false, label="IFLS WB: Pipeline (PostFixHQ -> GainWet -> Export)" },
  { rel="Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_SamplePack_Pipeline_PostFixHQ_GainDry_ExportPostBus.lua", toggle=false, label="IFLS WB: Pipeline (PostFixHQ -> GainDry -> Export POST)" },
}

local lines = {}
lines[#lines+1] = "REAPER_MENU 1.0"
lines[#lines+1] = "TITLE IFLSWB Toolbar v3"

local added, skipped = 0, 0
for _,e in ipairs(entries) do
  local abs = path_join(resource, e.rel)
  if file_exists(abs) then
    local named = register_script(abs)
    if named then
      lines[#lines+1] = make_button(named, e.toggle, "", e.label, e.label)
      added = added + 1
    else
      skipped = skipped + 1
    end
  else
    skipped = skipped + 1
  end
end

local out_path = path_join(menu_dir, "IFLSWB_Toolbar_v3.ReaperMenu")
local f = assert(io.open(out_path, "wb"))
f:write(table.concat(lines, "\n"))
f:close()

r.MB(("Generated:\n%s\n\nButtons added: %d\nSkipped: %d\n\nImport via Options -> Customize menus/toolbars -> Import."):format(out_path, added, skipped), "IFLSWB Toolbar Generator v3", 0)