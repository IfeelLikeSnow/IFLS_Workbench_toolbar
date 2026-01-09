-- @description IFLS Workbench: Install / Generate Toolbar file
-- @version 1.0.0
-- @author I feel like snow
-- @link GitHub https://github.com/IfeelLikeSnow/IFLS_Workbench_toolbar
-- @donation PayPal https://www.paypal.com/donate/?hosted_button_id=PK9T9DX6UFRZ8
-- @about
--   Generates an importable toolbar file (.ReaperMenuSet) for IFLS Workbench scripts.
--   It also registers the scripts in the Action List (Main section) using AddRemoveReaScript.
--
--   Usage:
--     1) Run this script once after installing/updating the repository.
--     2) It writes: REAPER/ResourcePath/MenuSets/IFLS_Workbench.Toolbar.ReaperMenuSet
--     3) In REAPER: Options > Customize toolbars... > Import... (choose the file)
--
--   Notes:
--     - You can pick which toolbar number to target (1..16) when asked.
--     - You can re-run this any time; it will overwrite the file.

local r = reaper

local function msg(s) r.ShowMessageBox(tostring(s or ""), "IFLS Workbench", 0) end

local function get_script_dir()
  local info = debug.getinfo(1, "S")
  local p = (info and info.source) or ""
  p = p:gsub("^@", "")
  return p:match("^(.*[\\/])") or ""
end

local function join(a,b)
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then return a..b end
  return a.."/"..b
end

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

local function register_script(fullpath)
  if not file_exists(fullpath) then return nil, "File not found: "..tostring(fullpath) end
  local cmd = r.AddRemoveReaScript(true, 0, fullpath, true)
  if not cmd or cmd == 0 then return nil, "Failed to register: "..tostring(fullpath) end
  local named = r.ReverseNamedCommandLookup(cmd)
  if not named or named == "" then return nil, "Failed to get named command id for: "..tostring(fullpath) end
  return named, nil
end

-- scripts in this folder (same directory as this installer)
local base = get_script_dir()

local scripts = {
  {file="IFLS_Workbench_Explode_Fieldrec.lua", label="Explode Fieldrec"},
  {file="IFLS_Workbench_Explode_AutoBus_Smart_Route.lua", label="Explode + AutoBus Route"},
  {file="IFLS_Workbench_PolyWAV_Toolbox.lua", label="PolyWAV Toolbox (ImGui)"},
}

-- ask toolbar number
local ok, csv = r.GetUserInputs("IFLS Workbench Toolbar", 1, "Toolbar number (1-16)", "1")
if not ok then return end
local tb = tonumber(csv) or 1
if tb < 1 then tb = 1 elseif tb > 16 then tb = 16 end

-- register scripts and build menu entries
local entries = {}
for _, s in ipairs(scripts) do
  local named, err = register_script(join(base, s.file))
  if not named then
    msg(err)
    return
  end
  table.insert(entries, {cmd=named, label=s.label})
end

-- write ReaperMenuSet toolbar file
local res = r.GetResourcePath()
local menusets = join(res, "MenuSets")
-- ensure dir exists (best-effort)
r.RecursiveCreateDirectory(menusets, 0)
local outpath = join(menusets, "IFLS_Workbench.Toolbar.ReaperMenuSet")

local section = string.format("[Floating toolbar %d (Toolbar %d)]", tb, tb)
local t = {}
table.insert(t, "; IFLS Workbench Toolbar - generated")
table.insert(t, "; Install: copy to REAPER\\MenuSets\\IFLS_Workbench.Toolbar.ReaperMenuSet then import into your toolbar slot")
table.insert(t, "")
table.insert(t, section)
table.insert(t, "title=IFLS Workbench")
for i,e in ipairs(entries) do
  table.insert(t, string.format("icon_%d=text_wide", i-1))
  table.insert(t, string.format("item_%d=%s %s", i-1, e.cmd, e.label))
end
table.insert(t, "")

local f, ferr = io.open(outpath, "wb")
if not f then msg("Couldn't write:\n"..tostring(outpath).."\n\n"..tostring(ferr)) return end
f:write(table.concat(t, "\n"))
f:close()

msg("Toolbar file written:\n\n"..outpath.."\n\nNow import it:\nOptions > Customize toolbars... > Import...")
