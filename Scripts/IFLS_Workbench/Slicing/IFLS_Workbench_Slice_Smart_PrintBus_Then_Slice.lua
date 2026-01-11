-- @description IFLS Workbench: Slice Smart (print bus -> duplicate -> slice -> mute source)
-- @version 0.7.0
-- @author IfeelLikeSnow
-- @about
--   Workflow:
--     1) Render selected bus/track to stem (creates a new track)
--     2) Create a SLICE track next to it and duplicate the stem item(s) there
--     3) Split the duplicated items (transients/markers/regions)
--     4) Optional: ZeroCross PostFix
--     5) Mute the source stem track (so only slices play)

local r = reaper

-- ================= USER CONFIG =================
local MODE = "MENU"         -- "MENU" | "TRANSIENTS" | "MARKERS" | "REGIONS"
local DO_ZEROCROSS_POSTFIX = true

local FXBUS_NAME_MATCH     = "FX BUS"          -- tracks containing this substring
local MASTERBUS_NAME_MATCH = "MASTER"          -- preferred print source by name (fallback: selected track)

local NAME_SLICE_SRC = "IFLS WB - SLICE SRC"
local NAME_SLICE     = "IFLS WB - SLICE"

local AUTO_MONO_IF_ALL_SOURCES_MONO = true
local FIELDREC_NAME_MATCH = "FIELDREC"
-- ==============================================

local function get_script_dir()
  local src = debug.getinfo(1, "S").source
  return src:match("^@(.+[\\/])") or ""
end

local function track_name(tr)
  local _, name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  return name or ""
end

local function set_track_name(tr, name)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
end

local function find_track_by_name_substr(substr)
  if not substr or substr == "" then return nil, nil end
  substr = substr:lower()
  local n = r.CountTracks(0)
  for i = 0, n-1 do
    local tr = r.GetTrack(0, i)
    local nm = track_name(tr):lower()
    if nm:find(substr, 1, true) then
      return i, tr
    end
  end
  return nil, nil
end

local function unselect_all_tracks()
  for i = 0, r.CountTracks(0)-1 do
    r.SetTrackSelected(r.GetTrack(0,i), false)
  end
end

local function unselect_all_items()
  r.Main_OnCommand(40289, 0) -- Item: Unselect all items
end

local function select_all_items_on_track(tr)
  local cnt = r.CountTrackMediaItems(tr)
  for i = 0, cnt-1 do
    local it = r.GetTrackMediaItem(tr, i)
    r.SetMediaItemSelected(it, true)
  end
  return cnt
end

local function remember_track_guids()
  local t = {}
  for i = 0, r.CountTracks(0)-1 do
    local tr = r.GetTrack(0, i)
    t[r.GetTrackGUID(tr)] = true
  end
  return t
end

local function find_new_track(before_guids)
  local newest = nil
  for i = 0, r.CountTracks(0)-1 do
    local tr = r.GetTrack(0, i)
    local g = r.GetTrackGUID(tr)
    if not before_guids[g] then
      newest = tr
    end
  end
  return newest
end

local function duplicate_item_to_track(item, dest_tr)
  local new_item = r.AddMediaItemToTrack(dest_tr)
  if not new_item then return nil end

  r.SetMediaItemInfo_Value(new_item, "D_POSITION", r.GetMediaItemInfo_Value(item, "D_POSITION"))
  r.SetMediaItemInfo_Value(new_item, "D_LENGTH",   r.GetMediaItemInfo_Value(item, "D_LENGTH"))
  r.SetMediaItemInfo_Value(new_item, "D_VOL",      r.GetMediaItemInfo_Value(item, "D_VOL"))
  r.SetMediaItemInfo_Value(new_item, "D_PAN",      r.GetMediaItemInfo_Value(item, "D_PAN"))
  r.SetMediaItemInfo_Value(new_item, "B_MUTE",     r.GetMediaItemInfo_Value(item, "B_MUTE"))

  local tk = r.GetActiveTake(item)
  if tk then
    local new_tk = r.AddTakeToMediaItem(new_item)
    local src = r.GetMediaItemTake_Source(tk)
    if new_tk and src then
      r.SetMediaItemTake_Source(new_tk, src) -- shares same source
      r.SetMediaItemTakeInfo_Value(new_tk, "D_STARTOFFS", r.GetMediaItemTakeInfo_Value(tk, "D_STARTOFFS"))
      r.SetMediaItemTakeInfo_Value(new_tk, "D_PLAYRATE",  r.GetMediaItemTakeInfo_Value(tk, "D_PLAYRATE"))
      r.SetMediaItemTakeInfo_Value(new_tk, "D_PITCH",     r.GetMediaItemTakeInfo_Value(tk, "D_PITCH"))
      r.SetActiveTake(new_tk)
    end
  end

  return new_item
end

local function split_selected_items_at_regions()
  local _, num_markers, num_regions = r.CountProjectMarkers(0)
  local total = num_markers + num_regions
  if total <= 0 then return 0 end

  local boundaries = {}
  for i = 0, total-1 do
    local rv, isrgn, pos, rgnend = r.EnumProjectMarkers(i)
    if rv and isrgn then
      boundaries[#boundaries+1] = pos
      boundaries[#boundaries+1] = rgnend
    end
  end
  table.sort(boundaries)

  local sel_cnt = r.CountSelectedMediaItems(0)
  if sel_cnt <= 0 then return 0 end

  local splits_done = 0
  for si = 0, sel_cnt-1 do
    local it = r.GetSelectedMediaItem(0, si)
    local it_pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
    local it_end = it_pos + r.GetMediaItemInfo_Value(it, "D_LENGTH")

    local pts = {}
    for _, b in ipairs(boundaries) do
      if b > it_pos and b < it_end then pts[#pts+1] = b end
    end
    table.sort(pts)

    local cur = it
    for _, p in ipairs(pts) do
      local cpos = r.GetMediaItemInfo_Value(cur, "D_POSITION")
      local cend = cpos + r.GetMediaItemInfo_Value(cur, "D_LENGTH")
      if p > cpos and p < cend then
        local right = r.SplitMediaItem(cur, p)
        if right then
          splits_done = splits_done + 1
          cur = right
        end
      end
    end
  end

  return splits_done
end

local function run_split_mode(mode)
  if mode == "MARKERS" then
    r.Main_OnCommand(40931, 0) -- Item: Split items at project markers
    return true
  elseif mode == "TRANSIENTS" then
    local cmd = r.NamedCommandLookup("_XENAKIOS_SPLIT_ITEMSATRANSIENTS") -- SWS
    if cmd == 0 then
      r.ShowMessageBox("SWS transient split action not found.\nInstall/enable SWS or use MARKERS/REGIONS mode.", "IFLS Slice Smart", 0)
      return false
    end
    r.Main_OnCommand(cmd, 0)
    return true
  elseif mode == "REGIONS" then
    split_selected_items_at_regions()
    return true
  end
  return false
end

local function choose_mode_menu()
  gfx.init("", 0, 0, 0, 0, 0)
  local choice = gfx.showmenu("Split at transients (SWS)|Split at project markers|Split at regions (boundaries)||Cancel")
  gfx.quit()
  if choice == 1 then return "TRANSIENTS"
  elseif choice == 2 then return "MARKERS"
  elseif choice == 3 then return "REGIONS"
  end
  return nil
end

local function run_zerocross_postfix_if_available()
  if not DO_ZEROCROSS_POSTFIX then return end
  local dir = get_script_dir()
  local zc = dir .. "IFLS_Workbench_Slicing_ZeroCross_PostFix.lua"
  local ok = pcall(dofile, zc)
  if not ok then
    -- optional step, ignore
  end
end

local function decide_print_mono()
  if not AUTO_MONO_IF_ALL_SOURCES_MONO then return false end
  local idx, tr = find_track_by_name_substr(FIELDREC_NAME_MATCH)
  if not tr then return false end

  local maxch = 0
  local function scan_track(t)
    local ic = r.CountTrackMediaItems(t)
    for j = 0, ic-1 do
      local it = r.GetTrackMediaItem(t, j)
      local tk = r.GetActiveTake(it)
      if tk then
        local src = r.GetMediaItemTake_Source(tk)
        if src then
          local ch = r.GetMediaSourceNumChannels(src)
          if ch and ch > maxch then maxch = ch end
        end
      end
    end
  end

  scan_track(tr)

  local depth = r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
  if depth > 0 then
    local cur_depth = 1
    local i = idx + 1
    while i < r.CountTracks(0) and cur_depth > 0 do
      local t = r.GetTrack(0, i)
      scan_track(t)
      cur_depth = cur_depth + r.GetMediaTrackInfo_Value(t, "I_FOLDERDEPTH")
      i = i + 1
    end
  end

  if maxch <= 0 then return false end
  return maxch <= 1
end

-- ================= MAIN =================
r.Undo_BeginBlock()
r.PreventUIRefresh(1)

local fx_idx = (find_track_by_name_substr(FXBUS_NAME_MATCH))
if not fx_idx then fx_idx = r.CountTracks(0) end

local _, master_tr = find_track_by_name_substr(MASTERBUS_NAME_MATCH)
if not master_tr then master_tr = r.GetSelectedTrack(0, 0) end
if not master_tr then
  r.PreventUIRefresh(-1)
  r.ShowMessageBox("No MASTER bus found and no track selected.\nSelect the bus/track you want to print, then run again.", "IFLS Slice Smart", 0)
  r.Undo_EndBlock("IFLS Slice Smart: abort (no master)", -1)
  return
end

local old_mute = r.GetMediaTrackInfo_Value(master_tr, "B_MUTE")

local before = remember_track_guids()
unselect_all_tracks()
r.SetTrackSelected(master_tr, true)

local do_mono = decide_print_mono()
local render_cmd = do_mono and 40789 or 40788 -- Render tracks to stereo/mono stem tracks (and mute originals)
r.Main_OnCommand(render_cmd, 0)

-- restore mute state (render mutes originals)
r.SetMediaTrackInfo_Value(master_tr, "B_MUTE", old_mute)

local stem_tr = find_new_track(before)
if not stem_tr then
  r.PreventUIRefresh(-1)
  r.ShowMessageBox("Render did not create a new stem track.\nTry running the render-to-stem action manually, then run Slice Direct.", "IFLS Slice Smart", 0)
  r.Undo_EndBlock("IFLS Slice Smart: abort (render failed)", -1)
  return
end

set_track_name(stem_tr, NAME_SLICE_SRC)

-- Create slice track right after stem
local stem_idx = math.floor(r.GetMediaTrackInfo_Value(stem_tr, "IP_TRACKNUMBER") - 1)
r.InsertTrackAtIndex(stem_idx + 1, true)
local slice_tr = r.GetTrack(0, stem_idx + 1)
set_track_name(slice_tr, NAME_SLICE)

-- Move SRC+SLICE before FX BUS
fx_idx = (find_track_by_name_substr(FXBUS_NAME_MATCH)) or fx_idx
unselect_all_tracks()
r.SetTrackSelected(stem_tr, true)
r.SetTrackSelected(slice_tr, true)
r.ReorderSelectedTracks(fx_idx, 0)

-- Duplicate stem items to slice track
local stem_item_cnt = r.CountTrackMediaItems(stem_tr)
if stem_item_cnt <= 0 then
  r.PreventUIRefresh(-1)
  r.ShowMessageBox("Stem track has no items after render.", "IFLS Slice Smart", 0)
  r.Undo_EndBlock("IFLS Slice Smart: abort (no stem items)", -1)
  return
end

local new_items = {}
for i = 0, stem_item_cnt-1 do
  local it = r.GetTrackMediaItem(stem_tr, i)
  local dup = duplicate_item_to_track(it, slice_tr)
  if dup then new_items[#new_items+1] = dup end
end

-- Select duplicates, then split
unselect_all_items()
for _, it in ipairs(new_items) do
  r.SetMediaItemSelected(it, true)
end
r.UpdateArrange()

local mode = MODE
if mode == "MENU" then
  mode = choose_mode_menu()
  if not mode then
    r.PreventUIRefresh(-1)
    r.Undo_EndBlock("IFLS Slice Smart: canceled", -1)
    return
  end
end

local ok = run_split_mode(mode)

-- Select all slices on slice track for postfix
unselect_all_items()
select_all_items_on_track(slice_tr)
if ok then
  run_zerocross_postfix_if_available()
end

-- Mute source stem
r.SetMediaTrackInfo_Value(stem_tr, "B_MUTE", 1)

-- Focus selection on SLICE track
unselect_all_tracks()
r.SetTrackSelected(slice_tr, true)

r.UpdateArrange()
r.PreventUIRefresh(-1)
r.Undo_EndBlock("IFLS Slice Smart: print -> slice (" .. tostring(mode) .. ")", -1)
