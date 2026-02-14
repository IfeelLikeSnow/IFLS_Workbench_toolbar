-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Tools/IFLSWB_Generate_Fieldrec_SmartSlicer_Toolbar_ReaperMenu.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: IFLSWB_Generate_Fieldrec_SmartSlicer_Toolbar_ReaperMenu
-- @version 1.0.0

ï»¿-- @description IFLS Workbench - Generate Fieldrec SmartSlicer Toolbar (ReaperMenu)
-- @version 1.0.0
-- @author IFLS Workbench
-- @about
--   Generates a .ReaperMenu file that can be imported into a REAPER toolbar.--   It references these scripts by their installed actions (named command IDs).--   Steps:--   1) Load the scripts into Action List first (so named IDs exist)--   2) Run this script--   3) Import the generated .ReaperMenu in Customize toolbar
local r = reaper

local function join(a,b)
  local sep = package.config:sub(1,1)
  if a:sub(-1)==sep then return a..b end
  return a..sep..b
end

-- You can change these names if you prefer
local MENU_NAME = "IFLSWB_Fieldrec_SmartSlicer_Toolbar.ReaperMenu"
local out_path = join(join(r.GetResourcePath(),"MenuSets"), MENU_NAME)

-- Named command IDs: these are created by REAPER when you load ReaScripts.
-- We'll try to find them by script filenames; if missing, we warn.

local function find_cmd_id_by_filename(filename)
  -- brute-force scan of action list isn't exposed; workaround: ask user to load scripts and then use NamedCommandLookup on custom ID if known.
  -- Here we store IDs in ExtState once the user runs the scripts at least once.
  local key = "CMD_"..filename
  local v = r.GetExtState("IFLSWB_SmartSlicer", key)
  if v ~= "" then return v end
  return nil
end

local function ensure_hint()
  r.MB("IMPORTANT:\n\n1) Load these scripts in Actions â†’ ReaScript: Load:\n- IFLS_Workbench_Fieldrec_SmartSlice_ModeMenu.lua\n- IFLS_Workbench_Fieldrec_SmartSlice_Hits.lua\n- IFLS_Workbench_Fieldrec_SmartSlice_Textures.lua\n- IFLS_Workbench_Fieldrec_SmartSlice_HQ_Toggle.lua\n\n2) Run each once (so REAPER assigns IDs).\n3) Re-run this generator.\n\nThis is a REAPER limitation: scripts get their command IDs at load-time.", "IFLSWB Toolbar Generator", 0)
end

local ids = {
  mode = find_cmd_id_by_filename("IFLS_Workbench_Fieldrec_SmartSlice_ModeMenu.lua"),
  hits = find_cmd_id_by_filename("IFLS_Workbench_Fieldrec_SmartSlice_Hits.lua"),
  tex  = find_cmd_id_by_filename("IFLS_Workbench_Fieldrec_SmartSlice_Textures.lua"),
  hq   = find_cmd_id_by_filename("IFLS_Workbench_Fieldrec_SmartSlice_HQ_Toggle.lua"),
}

if not (ids.mode and ids.hits and ids.tex and ids.hq) then
  ensure_hint()
  -- Still write a template with placeholders:
end

local function line(s) return s.."\n" end

local content = ""
content = content .. line("TB 1 16 0 0 0 0 0 0")
content = content .. line('  BUTTON "'..(ids.mode or "_RSCRIPT_MODEMENU")..'" 0 "" "" "" ""')
content = content .. line('  BUTTON "'..(ids.hq   or "_RSCRIPT_HQ")..'" 1 "" "" "" ""')
content = content .. line('  BUTTON "'..(ids.hits or "_RSCRIPT_HITS")..'" 0 "" "" "" ""')
content = content .. line('  BUTTON "'..(ids.tex  or "_RSCRIPT_TEX")..'" 0 "" "" "" ""')
content = content .. line("TBEND")

local f = io.open(out_path, "w")
if not f then
  r.MB("Failed to write:\n"..out_path, "IFLSWB Toolbar Generator", 0)
  return
end
f:write(content)
f:close()

r.MB("Wrote toolbar menu:\n"..out_path.."\n\nImport it via: Toolbar â†’ Customize â†’ Import", "IFLSWB Toolbar Generator", 0)
