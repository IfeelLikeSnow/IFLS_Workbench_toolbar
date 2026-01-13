-- @description IFLS Workbench - Smart Slice (Print bus -> Auto slice -> Close gaps)
-- @author IFLS / DF95
-- @version 0.7.6
-- @changelog
--   + Fix: insert Slices track directly before each new stem track (off-by-one index)
--   + Fix: keep script header/version in sync with repo
--   + Safety: more robust selection restore and no-op if nothing to slice
--
-- @about
--   Workflow for IDM/glitch from field recordings:
--     1) Select the track(s) you want to print (bus or group).
--     2) Run this script.
--   It renders ("prints") the selection to a new stem track, mutes originals (render action does this),
--   then creates a Slices track and performs slicing + gap removal on the printed audio.

local r = reaper

local function msg(s) r.ShowConsoleMsg(tostring(s) .. "\n") end

local function get_script_dir()
  local _, _, _, _, _, script_path = r.get_action_context()
  return script_path:match("^(.*)[/\\]") or ""
end

local function path_join(a,b)
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then return a .. b end
  return a .. "/" .. b
end

local function get_selected_tracks()
  local t = {}
  local n = r.CountSelectedTracks(0)
  for i=0,n-1 do t[#t+1] = r.GetSelectedTrack(0,i) end
  return t
end

local function track_ptr_set(tracks)
  local set = {}
  for _,tr in ipairs(tracks) do set[tr] = true end
  return set
end

local function selection_has_nonunity_playrate(eps)
  eps = eps or 1e-9
  local n = r.CountSelectedMediaItems(0)
  for i=0,n-1 do
    local it = r.GetSelectedMediaItem(0,i)
    if it then
      local take = r.GetActiveTake(it)
      if take and not r.TakeIsMIDI(take) then
        local pr = r.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE") or 1.0
        if math.abs(pr - 1.0) > eps then return true end
      end
    end
  end
  return false
end

local function is_all_sources_mono(tracks)
  -- Scan items on the selected tracks. If any take source has >1 channel => not all mono.
  for _,tr in ipairs(tracks) do
    local item_cnt = r.CountTrackMediaItems(tr)
    for i=0,item_cnt-1 do
      local item = r.GetTrackMediaItem(tr,i)
      local take = r.GetActiveTake(item)
      if take then
        local src = r.GetMediaItemTake_Source(take)
        if src then
          local ch = r.GetMediaSourceNumChannels(src)
          if ch and ch > 1 then return false end
        end
      end
    end
  end
  return true
end

local function try_main_cmd(cmd)
  if cmd and cmd > 0 then
    r.Main_OnCommand(cmd, 0)
    return true
  end
  return false
end

local function try_named_cmd(named)
  local cmd = r.NamedCommandLookup(named)
  if cmd and cmd > 0 then
    r.Main_OnCommand(cmd, 0)
    return true
  end
  return false
end

local function render_to_stem(all_mono)
  -- Prefer modern action IDs (REAPER 7.x action list):
  -- 40788: Render selected tracks to mono stem tracks (and mute originals)
  -- 40789: Render selected tracks to stereo stem tracks (and mute originals)
  local ok = false
  if all_mono then
    ok = try_main_cmd(40788) or try_main_cmd(40537)
  else
    ok = try_main_cmd(40789) or try_main_cmd(40538)
  end
  return ok
end

local function get_new_selected_tracks(pre_sel_set)
  local new = {}
  local n = r.CountSelectedTracks(0)
  for i=0,n-1 do
    local tr = r.GetSelectedTrack(0,i)
    if tr and not pre_sel_set[tr] then new[#new+1] = tr end
  end
  return new
end

local function select_only_track(tr)
  r.Main_OnCommand(40297,0) -- Unselect all tracks
  r.SetTrackSelected(tr, true)
end

local function select_only_items_on_track(tr)
  r.Main_OnCommand(40289,0) -- Unselect all items
  local cnt = r.CountTrackMediaItems(tr)
  for i=0,cnt-1 do
    local it = r.GetTrackMediaItem(tr,i)
    r.SetMediaItemSelected(it, true)
  end
end

local function insert_track_before(tr)
  local idx = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER") -- 1-based
  if not idx then return nil end
  local ins = math.max(0, idx-1) -- insert BEFORE this track (0-based index)
  r.InsertTrackAtIndex(ins, true)
  local new_tr = r.GetTrack(0, ins)
  return new_tr
end

local function set_track_name(tr, name)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
end

local function move_items(from_tr, to_tr)
  local cnt = r.CountTrackMediaItems(from_tr)
  -- iterate backwards because moving changes indexing
  for i=cnt-1,0,-1 do
    local it = r.GetTrackMediaItem(from_tr, i)
    r.MoveMediaItemToTrack(it, to_tr)
  end
end

local function compute_peaks_metrics(item)
  -- Lightweight analysis: crest factor + transient-ish count
  local take = r.GetActiveTake(item)
  if not take or not r.new_array or not r.APIExists("GetMediaItemTake_Peaks") then
    return nil
  end

  local src = r.GetMediaItemTake_Source(take)
  if not src then return nil end
  local ch = r.GetMediaSourceNumChannels(src)
  if not ch or ch < 1 then ch = 1 end
  ch = math.min(ch, 2)

  local samples = 2048
  local buf = r.new_array(ch * samples * 2) -- max + min
  local peakrate = 1000.0
  local starttime = 0.0
  local want_extra = 0

  local retval = r.GetMediaItemTake_Peaks(take, peakrate, starttime, ch, samples, want_extra, buf)
  if not retval or retval == 0 then return nil end

  local returned = retval & 0xFFFFF
  if returned < 16 then return nil end

  local peak = 0.0
  local sum = 0.0
  local count = 0

  -- maxima block first: [0 .. ch*samples-1]
  local maxN = ch * returned
  for i=1,maxN do
    local v = math.abs(buf[i])
    if v > peak then peak = v end
    sum = sum + v
    count = count + 1
  end
  if count == 0 then return nil end
  local mean = sum / count
  if mean <= 1e-9 then return nil end
  local crest = peak / mean

  -- transient-ish count: count of points above 70% peak with simple local maxima check (mono'd)
  local thr = peak * 0.70
  local trans = 0
  for s=2,returned-1 do
    local v = math.abs(buf[s]) -- first channel only
    local prev = math.abs(buf[s-1])
    local nxt = math.abs(buf[s+1])
    if v > thr and v >= prev and v >= nxt then
      trans = trans + 1
    end
  end

  return {crest=crest, trans=trans, returned=returned}
end


local function close_gaps_fallback()
  -- Pure Lua gap closing: pack selected items on the same track so there is no space between them.
  local n = r.CountSelectedMediaItems(0)
  if n < 2 then return end

  -- collect
  local items = {}
  for i=0,n-1 do
    local it = r.GetSelectedMediaItem(0,i)
    local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
    local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
    items[#items+1] = {it=it, pos=pos, len=len}
  end
  table.sort(items, function(a,b) return a.pos < b.pos end)

  local cur = items[1].pos + items[1].len
  for i=2,#items do
    local it = items[i].it
    r.SetMediaItemInfo_Value(it, "D_POSITION", cur)
    cur = cur + items[i].len
  end
end

local function do_slicing_on_selected_items()
  -- 1) Optional split at transients (SWS Xenakios)
  local did_trans = try_named_cmd("_XENAKIOS_SPLIT_ITEMSATRANSIENTS")

  -- 2) Remove-silence split (native). Uses last settings if you previously opened the dialog.
  --    Action: "Item: Auto trim/split items (remove silence)..." = 40315
  try_main_cmd(40315)

  -- 3) Close gaps (SWS)
  local did_fill = try_named_cmd("_SWS_AWFILLGAPSQUICK")
  if not did_fill then close_gaps_fallback() end

  return did_trans, did_fill
end

local function maybe_run_zerocross_postfix()
  -- uses the existing IFLS toggle script state, if present
  local _, on = r.GetProjExtState(0, "IFLS_SLICING", "ZC_RESPECT")
  if on == "1" then
    local dir = get_script_dir()
    local postfix = path_join(dir, "IFLS_Workbench_Slicing_ZeroCross_PostFix.lua")
    if r.file_exists and r.file_exists(postfix) then
      dofile(postfix)
    else
      -- fallback: try relative to Slicing folder
      local alt = path_join(dir, "Slicing/IFLS_Workbench_Slicing_ZeroCross_PostFix.lua")
      if r.file_exists and r.file_exists(alt) then dofile(alt) end
    end
  end
end

local function main()
  local pre_sel = get_selected_tracks()
  if #pre_sel == 0 then
    r.MB("Select the track(s) you want to print/slice first.", "IFLS Smart Slice", 0)
    return
  end

  local pre_set = track_ptr_set(pre_sel)
  local mono = is_all_sources_mono(pre_sel)

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local ok = render_to_stem(mono)
  if not ok then
    r.PreventUIRefresh(-1)
    r.Undo_EndBlock("IFLS Smart Slice - failed (render action not found)", -1)
    r.MB("Couldn't render stem track (render action not found?).\n\nTry:\n- REAPER 7.5+ (for 40788/40789)\n- Or customize render action IDs in the script.", "IFLS Smart Slice", 0)
    return
  end

  -- new stem track(s) should be selected after render
  local new_stems = get_new_selected_tracks(pre_set)
  if #new_stems == 0 then
    r.PreventUIRefresh(-1)
    r.Undo_EndBlock("IFLS Smart Slice - failed (no new stem track detected)", -1)
    r.MB("Rendered, but couldn't detect the new stem track.\n\nTry selecting ONLY the source tracks and re-run.", "IFLS Smart Slice", 0)
    return
  end

  -- For each stem track: create slices track right above it, move items, then slice
  for _,stem_tr in ipairs(new_stems) do
    local slices_tr = insert_track_before(stem_tr)
    if slices_tr then
      set_track_name(slices_tr, "IFLS Slices")
      move_items(stem_tr, slices_tr)

      -- keep stem track muted (it should already be empty now, but safe)
      r.SetMediaTrackInfo_Value(stem_tr, "B_MUTE", 1)

      select_only_track(slices_tr)
      select_only_items_on_track(slices_tr)

      -- analyze first selected item to decide if transient split is worth it (optional)
      local first_item = r.GetSelectedMediaItem(0,0)
      local m = first_item and compute_peaks_metrics(first_item) or nil
      if m and (m.crest >= 6.0 or m.trans >= 8) then
        -- do transients + silence trim
        do_slicing_on_selected_items()
      else
        -- just silence trim + fill gaps
        try_main_cmd(40315)
        local did_fill2 = false
        if not selection_has_nonunity_playrate() then
          did_fill2 = try_named_cmd("_SWS_AWFILLGAPSQUICK")
        end
        if not did_fill2 then close_gaps_fallback() end
      end

      maybe_run_zerocross_postfix()
    end
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS Smart Slice (print -> slice -> close gaps)", -1)
end

main()