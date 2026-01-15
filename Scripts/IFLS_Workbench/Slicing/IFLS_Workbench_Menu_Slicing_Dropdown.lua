
-- @description IFLS Workbench: Slicing Dropdown (auto-categories + fades)
-- @version 1.0
-- @about Scannt FXChains/IFLS_Workbench/Slicing_* und baut Menü automatisch. Enthält Fade-Submenü & Help.
local r = reaper
local sep = package.config:sub(1,1)
local res = r.GetResourcePath()

local function showmenu(str)
  local _, _, x, y = r.GetMousePosition()
  gfx.init("IFLS_SlicingMenu", 1, 1, 0, x, y)
  local sel = gfx.showmenu(str)
  gfx.quit()
  return sel
end

local function help_once()
  local _, seen = r.GetProjExtState(0, "IFLS_UI", "SLICE_HELP_SEEN")
  if seen ~= "1" then
    r.ShowConsoleMsg([[
[IFLS] Slicing Dropdown – Hilfe
• Linksklick: Kategorien → Presets laden
• Fade-Submenü: Linear/Slow/Fast/AutoFromPreset
• ExtState: IFLS_SLICING CATEGORY/PRESET steuert Auto-Fade
• Mehr in Data/IFLS_Workbench/... (optional)
]])
    r.SetProjExtState(0, "IFLS_UI", "SLICE_HELP_SEEN", "1")
  end
end

local function list_dirs(base)
  local t, i = {}, 0
  local d = r.EnumerateSubdirectories(base, i)
  while d do
    t[#t+1] = base .. sep .. d
    i = i + 1
    d = r.EnumerateSubdirectories(base, i)
  end
  return t
end

local function list_chains(dir)
  local out, i = {}, 0
  local f = r.EnumerateFiles(dir, i)
  while f do
    if f:lower():match("%.rfxchain$") then out[#out+1] = {name=f, path=dir..sep..f} end
    i=i+1; f = r.EnumerateFiles(dir, i)
  end
  table.sort(out, function(a,b) return (a.name or "") < (b.name or "") end)
  return out
end

-- discover slicing roots
local roots = {
  res..sep.."FXChains"..sep.."IFLS_Workbench"..sep.."Slicing_IDM",
  res..sep.."FXChains"..sep.."IFLS_Workbench"..sep.."Slicing_Euclid",
  res..sep.."FXChains"..sep.."IFLS_Workbench"..sep.."Slicing_Artists_Granular"
}

local cats = {}
for _,root in ipairs(roots) do
  local dirs = list_dirs(root)
  for _,d in ipairs(dirs) do
    local cname = d:match("([^"..sep.."]+)$") or d
    cats[cname] = cats[cname] or {}
    cats[cname].dir = d
    cats[cname].chains = list_chains(d)
  end
end


-- build menu
local function naturalsort(a,b)
  local function pad(s) return s:lower():gsub("(%d+)", function(n) return string.format("%09d", tonumber(n)) end) end
  return pad(a) < pad(b)
end

local ordered_categories = {}
for cname,_ in pairs(cats) do ordered_categories[#ordered_categories+1]=cname end
table.sort(ordered_categories, function(a,b)
  -- preferred category priority: Artists, IDM/Glitch, Euclid, Generative, else alpha
  local priority = {["Artists"]=1, ["IDM"]=2, ["IDM/Glitch"]=2, ["Euclid"]=3, ["Generative"]=4}
  local pa = priority[a] or 9
  local pb = priority[b] or 9
  if pa ~= pb then return pa < pb end
  return a < b
end)

local function build_menu_spec()
  local cats_order = ordered_categories
  local parts = {}
  parts[#parts+1] = ">Fade Shapes|Linear|Slow|Fast|Auto from Preset<|"
  for _,cname in ipairs(cats_order) do local info = cats[cname]
    if #info.chains > 0 then
      parts[#parts+1] = ">"..cname
      for _,c in ipairs(info.chains) do
        parts[#parts+1] = c.name
      end
      parts[#parts+1] = "<|"
    end
  end
  if #parts == 1 then
    return "Fade Shapes|Linear|Slow|Fast|Auto from Preset" -- fallback only
  end
  return table.concat(parts, "|")
end

local menu = build_menu_spec()
help_once()
local choice = showmenu(menu)
if choice <= 0 then return end

-- resolve selection
local index, current = 0, ""
local function dispatch()
  -- first block is Fade submenu (5 entries: open, 3 options, close), then categories
  -- we iterate tokens similarly as we built it
  local tokens = {}
  for token in menu:gmatch("[^|]+") do tokens[#tokens+1] = token end
  for _,tk in ipairs(tokens) do
    if tk:sub(1,1) == ">" or tk:sub(-1) == "<" then
      -- submenu marker: skip index
    else
      index = index + 1
      if index == choice then current = tk break end
    end
  end

  -- handle fades
  if current == "Linear" then
    dofile((res.."/Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_FadeShape_Set_Linear.lua"):gsub("\\","/")); return
  elseif current == "Slow" then
    dofile((res.."/Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_FadeShape_Set_Slow.lua"):gsub("\\","/")); return
  elseif current == "Fast" then
    dofile((res.."/Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_FadeShape_Set_Fast.lua"):gsub("\\","/")); return
  elseif current == "Auto from Preset" then
    dofile((res.."/Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_FadeShape_Set_Linear.lua"):gsub("\\","/")); return
  end

  -- otherwise: it's a chain under a category; find path
  for _,cname in ipairs(cats_order) do local info = cats[cname]
    for _,c in ipairs(info.chains or {}) do
      if c.name == current then
        -- set ExtState for AutoFromPreset
        r.SetProjExtState(0, "IFLS_SLICING", "CATEGORY", cname)
        r.SetProjExtState(0, "IFLS_SLICING", "PRESET", c.name:gsub("%.rfxchain$",""))
        -- load chain to all selected tracks
        local sel = r.CountSelectedTracks(0)
        if sel == 0 then
          r.ShowMessageBox("Keine Tracks ausgewählt. Bitte Zielspuren markieren.", "IFLS Workbench Slicing", 0)
          return
        end
        for i=0,sel-1 do
          local tr = r.GetSelectedTrack(0,i)
          r.TrackFX_AddByName(tr, c.path, false, 1) -- add from .rfxchain
        end
        r.ShowConsoleMsg(string.format("[IFLS] Slicing preset geladen: %s → %d Tracks\n", c.name, sel))
-- optional ZeroCross PostFix (if enabled)
local zc_flag = ({r.GetProjExtState(0,"IFLS_SLICING","ZC_RESPECT")})[2]
if zc_flag == "1" then
  dofile((res.."/Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_ZeroCross_PostFix.lua"):gsub("\\","/"))
end
return
      end
    end
  end
end

dispatch()
