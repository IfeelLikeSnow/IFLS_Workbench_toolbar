-- @description IFLS Workbench - JSFX Menu (compact launcher)
-- @version 0.7.9
-- @author IfeelLikeSnow
-- @about
--   Scans REAPER's resource Effects/IFLS_Workbench folder for JSFX and lets you insert them from a single menu.
--   Intended to replace many toolbar buttons with one "JSFX" button (menu).
--
--   Targets:
--     - Track FX: first selected track, else last-touched track, else master.
--     - Take FX: active take of first selected item (if any).
--
--   Notes:
--     - FX name is taken from the JSFX "desc:" line when available.
--     - Insertion uses TrackFX_AddByName / TakeFX_AddByName with "JS: <name>".
--
--   No external dependencies.

local r = reaper

-- -------------------------
-- Helpers
-- -------------------------
local function script_dir()
  local _, p = r.get_action_context()
  return (p or ""):match("^(.*)[\\/].-$") or ""
end

local function join(a, b)
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then return a .. b end
  return a .. package.config:sub(1,1) .. b
end

local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close() return true end
  return false
end

local function read_jsfx_desc(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local desc = nil
  for _=1, 80 do
    local line = f:read("*l")
    if not line then break end
    -- strip UTF-8 BOM if present
    line = line:gsub("^\239\187\191", "")
    local d = line:match("^%s*desc:%s*(.+)%s*$")
    if d and #d > 0 then desc = d break end
  end
  f:close()
  return desc
end

local function list_dir_recursive(root_dir, rel, out)
  out = out or {}
  rel = rel or ""
  local i = 0
  while true do
    local sub = r.EnumerateSubdirectories(root_dir, i)
    if not sub then break end
    list_dir_recursive(root_dir, join(rel, sub), out)
    i = i + 1
  end

  local j = 0
  while true do
    local fn = r.EnumerateFiles(root_dir, j)
    if not fn then break end
    local lower = fn:lower()
    if lower:match("%.jsfx$") or lower:match("%.txt$") then
      local full = join(root_dir, fn)
      -- only keep real files
      if file_exists(full) then
        out[#out+1] = { full = full, rel = join(rel, fn) }
      end
    end
    j = j + 1
  end
  return out
end

local function fx_sort(a, b)
  return (a.display or a.name) < (b.display or b.name)
end

local function get_targets()
  local tr = r.GetSelectedTrack(0, 0)
  if not tr then tr = r.GetLastTouchedTrack() end
  if not tr then tr = r.GetMasterTrack(0) end

  local item = r.GetSelectedMediaItem(0, 0)
  local take = item and r.GetActiveTake(item) or nil
  return tr, take
end

local function add_track_fx(track, fxname)
  local idx = r.TrackFX_AddByName(track, "JS: " .. fxname, false, -1)
  return idx
end

local function add_take_fx(take, fxname)
  local idx = r.TakeFX_AddByName(take, "JS: " .. fxname, -1)
  return idx
end

-- -------------------------
-- Build IFLS Workbench JSFX list
-- -------------------------
local resource = r.GetResourcePath()
local effects_root = join(resource, "Effects")
local ifls_root = join(effects_root, "IFLS_Workbench")

local scan_root = ifls_root
if not file_exists(ifls_root) and not r.EnumerateFiles(ifls_root, 0) then
  -- fallback: scan entire Effects folder if IFLS_Workbench folder not present
  scan_root = effects_root
end

local raw = list_dir_recursive(scan_root, "", {})
local fx = {}

for _, it in ipairs(raw) do
  local base = it.rel:gsub("^.*[\\/]", ""):gsub("%..+$", "")
  local desc = read_jsfx_desc(it.full)
  local display = desc or base

  -- If we had to scan Effects/ (fallback), keep only likely IFLS Workbench JSFX
  if scan_root ~= ifls_root then
    local low = (display .. " " .. base .. " " .. it.rel):lower()
    if not (low:find("ifls_workbench", 1, true) or low:find("ifls workbench", 1, true) or low:find("iflswb", 1, true)) then
      goto continue
    end
  end

  -- Category by relative folder (first folder)
  local cat = it.rel:match("^([^\\/]+)[\\/].+$") or "All"
  fx[#fx+1] = {
    full = it.full,
    rel = it.rel,
    name = base,
    display = display,
    cat = cat
  }
  ::continue::
end

table.sort(fx, fx_sort)

if #fx == 0 then
  r.ShowMessageBox("No IFLS Workbench JSFX found.\n\nExpected folder:\n" .. ifls_root .. "\n\nIf you installed manually, ensure Effects/IFLS_Workbench/*.jsfx exists.", "IFLS JSFX Menu", 0)
  return
end

-- -------------------------
-- Build menu
-- -------------------------
local function menu_build()
  local cats = {}
  for _, e in ipairs(fx) do
    cats[e.cat] = cats[e.cat] or {}
    table.insert(cats[e.cat], e)
  end

  local ordered_cats = {}
  for c,_ in pairs(cats) do ordered_cats[#ordered_cats+1] = c end
  table.sort(ordered_cats)

  local items = {}   -- mapping: index -> {kind="track"/"take"/"util", fxname=...}
  local parts = {}

  local function add_item(label, payload)
    parts[#parts+1] = label
    items[#items+1] = payload
  end

  -- Track submenu
  parts[#parts+1] = ">Insert as Track FX"
  for _, c in ipairs(ordered_cats) do
    parts[#parts+1] = ">" .. c
    table.sort(cats[c], fx_sort)
    for _, e in ipairs(cats[c]) do
      add_item(e.display, { kind="track", fx=e })
    end
    parts[#parts+1] = "<"
  end
  parts[#parts+1] = "<"

  -- Take submenu
  parts[#parts+1] = ">Insert as Take FX"
  for _, c in ipairs(ordered_cats) do
    parts[#parts+1] = ">" .. c
    table.sort(cats[c], fx_sort)
    for _, e in ipairs(cats[c]) do
      add_item(e.display, { kind="take", fx=e })
    end
    parts[#parts+1] = "<"
  end
  parts[#parts+1] = "<"

  -- Utilities
  parts[#parts+1] = ""
  add_item("Open Effects/IFLS_Workbench folder", { kind="open_folder", path=ifls_root })

  return table.concat(parts, "|"), items
end

local menu_str, map = menu_build()

-- -------------------------
-- Show menu & execute
-- -------------------------
local mx, my = r.GetMousePosition()
gfx.init("IFLS JSFX Menu", 0, 0, 0, mx, my)
local sel = gfx.showmenu(menu_str)
gfx.quit()

if sel <= 0 then return end

local choice = map[sel]
if not choice then return end

local track, take = get_targets()

local function try_insert_track(entry)
  local fxname = entry.display
  local idx = add_track_fx(track, fxname)
  if idx < 0 then
    idx = add_track_fx(track, entry.name)
  end
  return idx
end

local function try_insert_take(entry)
  if not take then return -1, "No selected item/take." end
  local fxname = entry.display
  local idx = add_take_fx(take, fxname)
  if idx < 0 then
    idx = add_take_fx(take, entry.name)
  end
  return idx
end

if choice.kind == "track" then
  r.Undo_BeginBlock()
  local idx = try_insert_track(choice.fx)
  r.Undo_EndBlock("IFLS: Insert JSFX (Track FX): " .. (choice.fx.display or choice.fx.name), -1)
  if idx < 0 then
    r.ShowMessageBox("Couldn't insert JSFX on track.\nTried:\n  JS: " .. (choice.fx.display or "") .. "\n  JS: " .. (choice.fx.name or ""), "IFLS JSFX Menu", 0)
  end
elseif choice.kind == "take" then
  r.Undo_BeginBlock()
  local idx, err = try_insert_take(choice.fx)
  r.Undo_EndBlock("IFLS: Insert JSFX (Take FX): " .. (choice.fx.display or choice.fx.name), -1)
  if idx < 0 then
    r.ShowMessageBox("Couldn't insert JSFX on take.\n" .. (err or "") .. "\nTried:\n  JS: " .. (choice.fx.display or "") .. "\n  JS: " .. (choice.fx.name or ""), "IFLS JSFX Menu", 0)
  end
elseif choice.kind == "open_folder" then
  local p = choice.path
  if not p or p == "" then return end
  if r.CF_ShellExecute then
    r.CF_ShellExecute(p)
  else
    -- Windows/macOS/Linux fallback
    local sep = package.config:sub(1,1)
    if sep == "\\" then
      os.execute('start "" "' .. p .. '"')
    else
      os.execute('open "' .. p .. '" 2>/dev/null || xdg-open "' .. p .. '" 2>/dev/null &')
    end
  end
end
