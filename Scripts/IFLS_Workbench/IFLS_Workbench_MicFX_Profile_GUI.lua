-- @description IFLS Workbench - MicFX Profile GUI (FXChain-aware .fxlist loader)
-- @version 0.1.0
-- @author IFLS (ported from DF95)
-- @about
--   Kleine GUI zum Laden von MicFXâ€‘Profilen.
--   Erwartet .fxlistâ€‘Dateien unter Scripts/IFLS/MicFX
--   sowie optionale METAâ€‘Tags in FXChains/IFLS_Workbench/Mic/*.rfxchain.
--

--   Workflow:
--     1. Mic auswÃ¤hlen (z.B. B1, NTG4+, XM8500, Geofon, Ether ...).
--     2. Script lÃ¤dt die zugehÃ¶rige .fxlist und instanziiert die FX
--        auf allen selektierten Tracks.
--
--   Hinweis:
--     Dies ist CPUâ€‘light und arbeitet im selben Spirit wie
--     DF95_MicFX_Manager.lua, nur mit expliziter Profilâ€‘Auswahl.

local r = reaper
local sep = package.config:sub(1,1)

local function get_resource_path()
  return r.GetResourcePath()
end

local function get_micfx_base()
  local res = get_resource_path()
  return res .. sep .. "Scripts" .. sep .. "IFLS_Workbench" .. sep .. "MicFX" .. sep
end

local MICS = {
  "NTG4+",
  "C2",
  "Cortado MK3",
  "Geofon",
  "B1",
  "XM8500",
  "TG-V35S",
  "MD400",
  "CM300",
  "SOMA Ether V2",
  "MCM Telecoil",
}

local function load_fxlist_for_mic(mic_name)
  local base = get_micfx_base()
  local path = base .. mic_name .. ".fxlist"
  local f = io.open(path, "r")
  if not f then
    r.ShowMessageBox("Keine .fxlist fÃ¼r Mic '" .. mic_name .. "' gefunden:\n" .. path, "IFLS Workbench MicFX", 0)
    return nil
  end
  local list = {}
  for line in f:lines() do
    line = line:gsub("^%s+", ""):gsub("%s+$", "")
    if line ~= "" and not line:match("^//") then
      list[#list+1] = line
    end
  end
  f:close()
  if #list == 0 then
    r.ShowMessageBox("Leere .fxlist fÃ¼r Mic '" .. mic_name .. "'", "IFLS Workbench MicFX", 0)
    return nil
  end
  return list
end

local function add_chain_to_track(tr, mic_name, fxlist)
  if not tr or not fxlist then return end
  r.Undo_BeginBlock()
  for _, fxname in ipairs(fxlist) do
    -- genau wie DF95_MicFX_Manager: TrackFX_AddByName mit FXâ€‘Namen (z.B. "VST: ReaEQ (Cockos)")
    r.TrackFX_AddByName(tr, fxname, false, -1)
  end
  r.Undo_EndBlock("IFLS Workbench MicFX: " .. mic_name, -1)
end

local function show_menu()
  local items = {"||IFLS Workbench MicFX Profile GUI:"}
  for _, m in ipairs(MICS) do
    items[#items+1] = m
  end
  local menu_str = table.concat(items, "|")
  -- GFXâ€‘basierte MenÃ¼â€‘Anzeige (kontextsensitiv, an Mausposition)
  gfx.init("IFLS Workbench MicFX", 0, 0)
  gfx.x, gfx.y = gfx.mouse_x, gfx.mouse_y
  local idx = gfx.showmenu(menu_str)
  gfx.quit()
  if idx <= 1 then return nil end -- 1 = Titelzeile
  local mic = MICS[idx-1]
  return mic
end

-- main
local sel_mic = show_menu()
if not sel_mic then return end

local fxlist = load_fxlist_for_mic(sel_mic)
if not fxlist then return end

local num_sel = r.CountSelectedTracks(0)
if num_sel == 0 then
  -- Wenn keine Tracks selektiert: Master
  local tr = r.GetMasterTrack(0)
  add_chain_to_track(tr, sel_mic, fxlist)
else
  r.Undo_BeginBlock()
  for i = 0, num_sel-1 do
    local tr = r.GetSelectedTrack(0, i)
    for _, fxname in ipairs(fxlist) do
      r.TrackFX_AddByName(tr, fxname, false, -1)
    end
  end
  r.Undo_EndBlock("IFLS Workbench MicFX: " .. sel_mic, -1)
end
