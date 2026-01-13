-- @description IFLS Workbench - Slicing Menu (Dropdown)
-- @author IFLS / DF95
-- @version 0.7.6
-- @changelog
--   + Fix: GetMousePosition() only returns (x,y) -> menu now opens at the correct mouse position
--   + Improvement: auto-detect all FXChain folders starting with 'Slicing_' (no hard-coded list)
--   + Improvement: remember last chosen FadeShape, Auto uses it
--   + Safety: only runs ZeroCross post-fix when items are selected

-- NOTE:
-- This script loads .RfxChain presets from:
--   <REAPER resource>/FXChains/IFLS Workbench/Slicing_*/
-- onto the currently selected tracks.

local r = reaper

local function msg(s) r.ShowConsoleMsg(tostring(s).."\n") end
local res = r.GetResourcePath()
local sep = package.config:sub(1,1)

local function norm(p)
  return (p:gsub("\\", "/"))
end

local function join(a,b)
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then return a..b end
  return a..sep..b
end

local function script_dir()
  local _, _, _, _, _, path = r.get_action_context()
  return path:match("^(.*)[/\\]") or ""
end

local function dofile_rel(rel_path)
  local p = norm(join(script_dir(), rel_path))
  local ok, err = pcall(dofile, p)
  if not ok then
    r.MB("Fehler beim Laden:\n"..tostring(rel_path).."\n\n"..tostring(err), "IFLS Slicing", 0)
  end
end

-- ---- Fade shape helpers ----------------------------------------------------
local function set_fade_shape_state(shape)
  r.SetProjExtState(0, "IFLS_SLICING", "FADE_SHAPE", tostring(shape))
end

local function get_fade_shape_state()
  local v = ({r.GetProjExtState(0, "IFLS_SLICING", "FADE_SHAPE")})[2]
  if v == "slow" or v == "fast" or v == "linear" then return v end
  return "linear"
end

local function run_fade_shape(shape)
  if shape == "linear" then
    dofile_rel("IFLS_Workbench_Slicing_FadeShape_Set_Linear.lua")
  elseif shape == "slow" then
    dofile_rel("IFLS_Workbench_Slicing_FadeShape_Set_Slow.lua")
  elseif shape == "fast" then
    dofile_rel("IFLS_Workbench_Slicing_FadeShape_Set_Fast.lua")
  end
  set_fade_shape_state(shape)
end

local function maybe_run_zerocross_postfix()
  local zc_flag = ({r.GetProjExtState(0, "IFLS_SLICING", "ZC_RESPECT")})[2]
  if zc_flag ~= "1" then return end
  if r.CountSelectedMediaItems(0) == 0 then return end
  dofile_rel("IFLS_Workbench_Slicing_ZeroCross_PostFix.lua")
end

-- ---- FXChain discovery -----------------------------------------------------
local fxroot = join(join(res, "FXChains"), "IFLS Workbench")

local function list_slicing_dirs()
  local out = {}
  local i = 0
  while true do
    local d = r.EnumerateSubdirectories(fxroot, i)
    if not d then break end
    if d:match("^Slicing_") then out[#out+1] = d end
    i = i + 1
  end
  table.sort(out)
  return out
end

local function list_chains_in_dir(dirname)
  local dirpath = join(fxroot, dirname)
  local chains = {}
  local i = 0
  while true do
    local fn = r.EnumerateFiles(dirpath, i)
    if not fn then break end
    if fn:lower():match("%.rfxchain$") then
      local name = fn:gsub("%.rfxchain$", "")
      chains[#chains+1] = {name=name, path=join(dirpath, fn)}
    end
    i = i + 1
  end
  table.sort(chains, function(a,b) return a.name:lower() < b.name:lower() end)
  return chains
end

local function cat_label(dirname)
  local lab = dirname:gsub("^Slicing_", "")
  lab = lab:gsub("_", "/")
  if lab == "" then lab = "Slicing" end
  return lab
end

local function build_catalog()
  local cats = {}
  for _, d in ipairs(list_slicing_dirs()) do
    local cat = cat_label(d)
    cats[cat] = cats[cat] or {}
    local chains = list_chains_in_dir(d)
    for _, c in ipairs(chains) do
      cats[cat][#cats[cat]+1] = c
    end
  end
  return cats
end

-- ---- Menu building + dispatch ---------------------------------------------
local function main()
  if not r.file_exists or not r.file_exists(fxroot) then
    r.MB("FXChains-Ordner nicht gefunden:\n"..norm(fxroot).."\n\n"..
          "Erwartet: <ResourcePath>/FXChains/IFLS Workbench/Slicing_*", "IFLS Slicing", 0)
    return
  end

  local cats = build_catalog()
  local catnames = {}
  for k,_ in pairs(cats) do catnames[#catnames+1] = k end
  table.sort(catnames)

  if #catnames == 0 then
    r.MB("Keine Slicing_Presets gefunden in:\n"..norm(fxroot), "IFLS Slicing", 0)
    return
  end

  local menu_items = {}
  local actions = {}

  -- Fade submenu
  menu_items[#menu_items+1] = ">Fade Shapes"
  menu_items[#menu_items+1] = "Linear"
  actions[#actions+1] = function() run_fade_shape("linear") end
  menu_items[#menu_items+1] = "Slow"
  actions[#actions+1] = function() run_fade_shape("slow") end
  menu_items[#menu_items+1] = "Fast"
  actions[#actions+1] = function() run_fade_shape("fast") end
  menu_items[#menu_items+1] = "Auto (last choice)<|"
  actions[#actions+1] = function() run_fade_shape(get_fade_shape_state()) end

  -- ZeroCross toggle entry
  menu_items[#menu_items+1] = "Toggle ZeroCross Respect"
  actions[#actions+1] = function() dofile_rel("IFLS_Workbench_Slicing_Toggle_ZeroCross.lua") end

  -- Preset categories
  for _, cat in ipairs(catnames) do
    menu_items[#menu_items+1] = ">"..cat
    for _, c in ipairs(cats[cat]) do
      menu_items[#menu_items+1] = c.name
      actions[#actions+1] = function()
        local sel = r.CountSelectedTracks(0)
        if sel == 0 then
          r.MB("Keine Tracks ausgewählt. Bitte Zielspuren markieren.", "IFLS Slicing", 0)
          return
        end
        for i=0, sel-1 do
          local tr = r.GetSelectedTrack(0, i)
          r.TrackFX_AddByName(tr, c.path, false, 1) -- load from .rfxchain
        end
        msg(string.format("[IFLS] Slicing preset geladen: %s → %d Track(s)\n", c.name, sel))
        maybe_run_zerocross_postfix()
      end
    end
    menu_items[#menu_items+1] = "<|"
  end

  menu_items[#menu_items+1] = "|"
  menu_items[#menu_items+1] = "Help"
  actions[#actions+1] = function()
    r.MB(
      "Slicing Menu:\n\n"..
      "• Lädt FXChain Presets aus: FXChains/IFLS Workbench/Slicing_*\n"..
      "• Fade Shapes: setzt Default-Fades für ausgewählte Items\n"..
      "• ZeroCross Respect: aktiviert PostFix-Fades nach dem Preset-Load\n\n"..
      "Tipp: Für Transient-Splitting brauchst du SWS (Xenakios).",
      "IFLS Slicing", 0)
  end

  local menu = table.concat(menu_items, "|")
  local x, y = r.GetMousePosition() -- returns exactly (x,y) in screen coords
  gfx.init("IFLS_SlicingMenu", 1, 1, 0, x, y)
  local choice = gfx.showmenu(menu)
  gfx.quit()

  if choice and choice > 0 then
    local fn = actions[choice]
    if fn then fn() end
  end
end

main()
