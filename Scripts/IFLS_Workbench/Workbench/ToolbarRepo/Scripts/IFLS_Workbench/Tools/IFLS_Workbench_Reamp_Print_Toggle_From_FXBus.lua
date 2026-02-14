-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Reamp_Print_Toggle_From_FXBus.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench - Reamp Print Toggle (Topology Auto-Find)
-- @version 1.2.0
-- @author IFLS Workbench
-- @about
--   Topology-first auto-detection of FX/Coloring/Master buses via routing graph (sends/receives).
--   First run (ARM): creates/arms "REAMP PRINT (from FX Bus)" right after the FX bus and routes FX->REAMP post-FX.
--   Second run (FINALIZE): disarms REAMP, routes REAMP to Coloring/Master (if found), and mutes/bypasses FX + sources.
--   Safety: stores bus GUIDs on the REAMP track for reliable finalize, and aborts if detection confidence is low.
--   Tip: If your project uses folder-only routing or detection is ambiguous, select the FX bus track and run again.
-- @changelog
--   1.2.0 - Fix metaheader (@about indentation, remove accidental tag-like lines), store bus GUIDs, stronger heuristics & safety checks.
--   Implementation notes: 
--   - We never rely on current selection for finalize: GUIDs are persisted on the REAMP track.

--

local r = reaper

----------------------------
-- helpers
----------------------------
local function get_name(tr)
  local ok, name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  return ok and (name or "") or ""
end

local function set_name(tr, name)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name or "", true)
end

local function set_toggle_state(on)
  local _, _, sec, cmd = r.get_action_context()
  if cmd and cmd ~= 0 then
    r.SetToggleCommandState(sec, cmd, on and 1 or 0)
    r.RefreshToolbar2(sec, cmd)
  end
end

local function track_idx0(tr)
  local tn = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
  if not tn or tn < 1 then return nil end
  return math.floor(tn - 1 + 0.5)
end

local function get_track_by_guid(guid)
  if not guid or guid == "" then return nil end
  local n = r.CountTracks(0)
  for i=0,n-1 do
    local tr = r.GetTrack(0, i)
    if tr and r.GetTrackGUID(tr) == guid then return tr end
  end
  return nil
end

local function set_ext(tr, key, val)
  r.GetSetMediaTrackInfo_String(tr, "P_EXT:"..key, val or "", true)
end

local function get_ext(tr, key)
  local ok, v = r.GetSetMediaTrackInfo_String(tr, "P_EXT:"..key, "", false)
  return ok and v or ""
end

local function is_buslike(tr)
  local in_deg = r.GetTrackNumSends(tr, -1) -- receives
  if in_deg > 0 then return true end
  -- Folder parent fallback: treat as bus if it has children
  local depth = r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH") or 0
  if depth >= 1 then return true end
  return false
end

local function is_leaf_source(tr)
  -- leaf: no receives (not a bus)
  return r.GetTrackNumSends(tr, -1) == 0
end

local function get_receives(tr)
  local n = r.GetTrackNumSends(tr, -1)
  local srcs = {}
  for i=0,n-1 do
    local src = r.GetTrackSendInfo_Value(tr, -1, i, "P_SRCTRACK")
    if src then srcs[#srcs+1] = src end
  end
  return srcs
end

local function get_sends(tr)
  local n = r.GetTrackNumSends(tr, 0)
  local dests = {}
  for i=0,n-1 do
    local dest = r.GetTrackSendInfo_Value(tr, 0, i, "P_DESTTRACK")
    if dest then
      local vol = r.GetTrackSendInfo_Value(tr, 0, i, "D_VOL") or 1.0
      dests[#dests+1] = {dest=dest, send_idx=i, vol=vol}
    end
  end
  return dests
end

local function ensure_send(src, dest, sendmode)
  local ns = r.GetTrackNumSends(src, 0)
  local idx = nil
  for i=0,ns-1 do
    local d = r.GetTrackSendInfo_Value(src, 0, i, "P_DESTTRACK")
    if d == dest then idx = i break end
  end
  if idx == nil then idx = r.CreateTrackSend(src, dest) end
  if idx and idx >= 0 then
    if sendmode ~= nil then r.SetTrackSendInfo_Value(src, 0, idx, "I_SENDMODE", sendmode) end
    r.SetTrackSendInfo_Value(src, 0, idx, "D_VOL", 1.0)
    r.SetTrackSendInfo_Value(src, 0, idx, "D_PAN", 0.0)
  end
  return idx
end

local function set_output_rec_mode(tr)
  -- record output (stereo, latency compensated)
  r.SetMediaTrackInfo_Value(tr, "I_RECMODE", 3)

  -- post-FX / pre-fader (lowest 2 bits = 2)
  local flags = r.GetMediaTrackInfo_Value(tr, "I_RECMODE_FLAGS") or 0
  flags = math.floor(flags + 0.5)
  flags = flags - (flags % 4)
  flags = flags + 2
  r.SetMediaTrackInfo_Value(tr, "I_RECMODE_FLAGS", flags)
end

local function collect_receive_sources_recursive(bus_tr)
  local sources = {}
  local seen = {}
  local function rec(tr)
    local n = r.GetTrackNumSends(tr, -1)
    for i=0,n-1 do
      local src = r.GetTrackSendInfo_Value(tr, -1, i, "P_SRCTRACK")
      if src and not seen[src] then
        seen[src] = true
        sources[#sources+1] = src
        rec(src)
      end
    end
  end
  rec(bus_tr)
  return sources
end

local function find_reamp_track_near(fx_bus)
  local fx_i = track_idx0(fx_bus)
  if not fx_i then return nil end
  local n = r.CountTracks(0)
  for i=math.max(0, fx_i-3), math.min(n-1, fx_i+8) do
    local tr = r.GetTrack(0,i)
    if get_ext(tr, "IFLSWB_REAMP_PRINT") == "1" then return tr end
    local nm = (get_name(tr) or ""):lower()
    if nm:find("reamp") and (nm:find("print") or nm:find("render") or nm:find("rec")) then return tr end
  end
  return nil
end

----------------------------
-- topology detection
----------------------------
local function build_component(seed_tr)
  local n = r.CountTracks(0)
  local idx_of = {}
  for i=0,n-1 do idx_of[r.GetTrack(0,i)] = i end

  if not seed_tr then
    local comp = {}
    for i=0,n-1 do comp[i] = true end
    return comp
  end

  local seed_i = idx_of[seed_tr]
  if seed_i == nil then
    local comp = {}
    for i=0,n-1 do comp[i] = true end
    return comp
  end

  -- undirected adjacency from receive edges
  local adj = {}
  for i=0,n-1 do adj[i] = {} end
  for i=0,n-1 do
    local tr = r.GetTrack(0,i)
    local srcs = get_receives(tr)
    for _,src in ipairs(srcs) do
      local si = idx_of[src]
      if si ~= nil then
        adj[i][si] = true
        adj[si][i] = true
      end
    end
  end

  local comp = {}
  local q = {seed_i}
  comp[seed_i] = true
  local head = 1
  while head <= #q do
    local v = q[head]; head = head + 1
    for nb,_ in pairs(adj[v]) do
      if not comp[nb] then
        comp[nb] = true
        q[#q+1] = nb
      end
    end
  end
  return comp
end

local function score_fx_candidate(tr)
  local recv_srcs = get_receives(tr)
  local in_deg = #recv_srcs
  if in_deg == 0 then return -1e9 end

  local leaf = 0
  local strong_leaf = 0
  for _,src in ipairs(recv_srcs) do
    if is_leaf_source(src) then
      leaf = leaf + 1
      -- "strong leaf" = it only sends to this bus (common explode topology)
      local ns = r.GetTrackNumSends(src, 0)
      if ns == 1 then
        local d = r.GetTrackSendInfo_Value(src, 0, 0, "P_DESTTRACK")
        if d == tr then strong_leaf = strong_leaf + 1 end
      end
    end
  end

  local sends = get_sends(tr)
  local out_deg = #sends
  local mainsend = r.GetMediaTrackInfo_Value(tr, "B_MAINSEND") or 0
  local fxcount = r.TrackFX_GetCount(tr) or 0

  local score = 0
  score = score + in_deg * 10
  score = score + leaf * 18
  score = score + strong_leaf * 22
  score = score + out_deg * 6
  score = score + (mainsend > 0 and 2 or 0)
  score = score + (fxcount > 0 and 6 or 0)
  return score
end

local function pick_primary_dest(bus_tr)
  local sends = get_sends(bus_tr)
  if #sends == 0 then return nil end
  table.sort(sends, function(a,b)
    if a.vol == b.vol then
      local ar = r.GetTrackNumSends(a.dest, -1)
      local br = r.GetTrackNumSends(b.dest, -1)
      return ar > br
    end
    return a.vol > b.vol
  end)
  -- prefer a buslike destination if possible
  for _,s in ipairs(sends) do
    if is_buslike(s.dest) then return s.dest end
  end
  return sends[1].dest
end

local function find_buses_topology()
  local sel = r.GetSelectedTrack(0,0)
  -- override: if selection looks buslike, trust it as FX bus
  if sel and is_buslike(sel) then
    local fx = sel
    local col = pick_primary_dest(fx)
    local mas = col and pick_primary_dest(col) or nil
    return fx, col, mas, 9999 -- high confidence
  end

  local comp = build_component(sel)
  local n = r.CountTracks(0)

  local candidates = {}
  for i=0,n-1 do
    if comp[i] then
      local tr = r.GetTrack(0,i)
      local sc = score_fx_candidate(tr)
      if sc > -1e8 then
        candidates[#candidates+1] = {tr=tr, score=sc}
      end
    end
  end
  table.sort(candidates, function(a,b) return a.score > b.score end)

  local fx = candidates[1] and candidates[1].tr or nil
  local best = candidates[1] and candidates[1].score or -1e9
  local second = candidates[2] and candidates[2].score or -1e9
  local confidence = best - second

  -- name fallback if nothing
  if not fx then
    for i=0,n-1 do
      if comp[i] then
        local tr = r.GetTrack(0,i)
        local nm = (get_name(tr) or ""):lower()
        if nm:find("fx") and (nm:find("bus") or nm:find("sum")) then
          fx = tr
          confidence = 0
          break
        end
      end
    end
  end

  if not fx then return nil, nil, nil, 0 end

  local col = pick_primary_dest(fx)
  local mas = col and pick_primary_dest(col) or nil
  return fx, col, mas, confidence
end

----------------------------
-- create/arm + finalize
----------------------------
local function create_and_arm(fx_bus, downstream_bus)
  local fx_i = track_idx0(fx_bus)
  if not fx_i then return nil, "FX bus index not found" end

  local insert_i = fx_i + 1
  if downstream_bus then
    local d_i = track_idx0(downstream_bus)
    if d_i and d_i == fx_i + 1 then insert_i = d_i end
  end

  r.InsertTrackAtIndex(insert_i, true)
  local reamp = r.GetTrack(0, insert_i)
  if not reamp then return nil, "Failed to create REAMP track" end

  set_name(reamp, "REAMP PRINT (from FX Bus)")
  set_ext(reamp, "IFLSWB_REAMP_PRINT", "1")
  set_ext(reamp, "IFLSWB_REAMP_FXGUID", r.GetTrackGUID(fx_bus))
  set_ext(reamp, "IFLSWB_REAMP_COLGUID", downstream_bus and r.GetTrackGUID(downstream_bus) or "")
  -- master guid will be filled on finalize if detected then

  ensure_send(fx_bus, reamp, 3) -- post-FX

  r.SetMediaTrackInfo_Value(reamp, "B_MAINSEND", 0)
  r.SetMediaTrackInfo_Value(reamp, "I_RECMON", 0)
  r.SetMediaTrackInfo_Value(reamp, "I_RECARM", 1)
  set_output_rec_mode(reamp)

  r.SetOnlyTrackSelected(reamp)
  return reamp, nil
end

local function finalize(fx_bus, reamp, coloring_bus, master_bus)
  -- persist GUIDs (for later runs)
  if fx_bus then set_ext(reamp, "IFLSWB_REAMP_FXGUID", r.GetTrackGUID(fx_bus)) end
  if coloring_bus then set_ext(reamp, "IFLSWB_REAMP_COLGUID", r.GetTrackGUID(coloring_bus)) end
  if master_bus then set_ext(reamp, "IFLSWB_REAMP_MASGUID", r.GetTrackGUID(master_bus)) end

  -- route REAMP to coloring/master if possible
  if coloring_bus then
    ensure_send(reamp, coloring_bus, 0)
    r.SetMediaTrackInfo_Value(reamp, "B_MAINSEND", 0)
  elseif master_bus then
    ensure_send(reamp, master_bus, 0)
    r.SetMediaTrackInfo_Value(reamp, "B_MAINSEND", 0)
  else
    r.SetMediaTrackInfo_Value(reamp, "B_MAINSEND", 1)
  end

  r.SetMediaTrackInfo_Value(reamp, "I_RECARM", 0)
  r.SetMediaTrackInfo_Value(reamp, "I_RECMON", 0)
  r.SetMediaTrackInfo_Value(reamp, "B_MUTE", 0)

  -- mute+bypass FX bus
  if fx_bus then
    r.SetMediaTrackInfo_Value(fx_bus, "B_MUTE", 1)
    r.SetMediaTrackInfo_Value(fx_bus, "I_FXEN", 0)

    -- mute+bypass all upstream sources feeding FX bus (recursive)
    local ups = collect_receive_sources_recursive(fx_bus)
    for _,src in ipairs(ups) do
      if src and src ~= reamp and src ~= coloring_bus and src ~= master_bus then
        r.SetMediaTrackInfo_Value(src, "B_MUTE", 1)
        r.SetMediaTrackInfo_Value(src, "I_FXEN", 0)
        r.SetMediaTrackInfo_Value(src, "I_RECARM", 0)
      end
    end
  end

  -- keep downstream buses active
  if coloring_bus then
    r.SetMediaTrackInfo_Value(coloring_bus, "B_MUTE", 0)
    r.SetMediaTrackInfo_Value(coloring_bus, "I_FXEN", 1)
  end
  if master_bus then
    r.SetMediaTrackInfo_Value(master_bus, "B_MUTE", 0)
    r.SetMediaTrackInfo_Value(master_bus, "I_FXEN", 1)
  end

  r.SetOnlyTrackSelected(reamp)
end

----------------------------
-- main
----------------------------
local function main()
  r.Undo_BeginBlock()

  -- try: if a REAMP track exists and has stored FX guid, use it
  local fx_bus, coloring_bus, master_bus, conf = find_buses_topology()

  local reamp = fx_bus and find_reamp_track_near(fx_bus) or nil
  if not reamp then
    -- global search by ext if fx detection failed
    local n = r.CountTracks(0)
    for i=0,n-1 do
      local tr = r.GetTrack(0,i)
      if get_ext(tr, "IFLSWB_REAMP_PRINT") == "1" then
        reamp = tr
        break
      end
    end
  end

  if reamp then
    local fxg = get_ext(reamp, "IFLSWB_REAMP_FXGUID")
    local colg = get_ext(reamp, "IFLSWB_REAMP_COLGUID")
    local masg = get_ext(reamp, "IFLSWB_REAMP_MASGUID")

    local fx2 = get_track_by_guid(fxg)
    local col2 = get_track_by_guid(colg)
    local mas2 = get_track_by_guid(masg)

    -- prefer GUID-based buses if available
    fx_bus = fx2 or fx_bus
    coloring_bus = col2 or coloring_bus
    master_bus = mas2 or master_bus
  end

  if not fx_bus then
    r.MB("No FX bus could be detected via routing topology.\n\nTip: Select your FX bus track and run again.", "IFLSWB Reamp Print", 0)
    set_toggle_state(false)
    r.Undo_EndBlock("IFLSWB: Reamp Print Toggle (FX bus not found)", -1)
    return
  end

  -- safety: if confidence is low and no selection override, abort
  if conf ~= 9999 and conf < 8 then
    local msg =
      "FX bus detection is ambiguous (low confidence).\n\n"..
      "Please SELECT your FX bus track and run again.\n\n"..
      "Detected candidate: "..get_name(fx_bus)
    r.MB(msg, "IFLSWB Reamp Print (Safety)", 0)
    set_toggle_state(false)
    r.Undo_EndBlock("IFLSWB: Reamp Print Toggle (Ambiguous)", -1)
    return
  end

  -- decide toggle direction by record-arm state
  if reamp and (r.GetMediaTrackInfo_Value(reamp, "I_RECARM") or 0) > 0 then
    finalize(fx_bus, reamp, coloring_bus, master_bus)
    set_toggle_state(false)
    r.Undo_EndBlock("IFLSWB: Reamp Print Toggle (Finalize)", -1)
  else
    if not reamp then
      local newtr, err = create_and_arm(fx_bus, coloring_bus or master_bus)
      if not newtr then
        r.MB("Failed to create REAMP PRINT track.\n\n"..tostring(err), "IFLSWB Reamp Print", 0)
        set_toggle_state(false)
        r.Undo_EndBlock("IFLSWB: Reamp Print Toggle (Create failed)", -1)
        return
      end
      reamp = newtr
    else
      -- exists but not armed -> re-arm
      r.SetOnlyTrackSelected(reamp)
      r.SetMediaTrackInfo_Value(reamp, "B_MAINSEND", 0)
      r.SetMediaTrackInfo_Value(reamp, "I_RECMON", 0)
      r.SetMediaTrackInfo_Value(reamp, "I_RECARM", 1)
      set_output_rec_mode(reamp)
      ensure_send(fx_bus, reamp, 3)

      set_ext(reamp, "IFLSWB_REAMP_PRINT", "1")
      set_ext(reamp, "IFLSWB_REAMP_FXGUID", r.GetTrackGUID(fx_bus))
      set_ext(reamp, "IFLSWB_REAMP_COLGUID", (coloring_bus and r.GetTrackGUID(coloring_bus)) or "")
      set_ext(reamp, "IFLSWB_REAMP_MASGUID", (master_bus and r.GetTrackGUID(master_bus)) or "")
    end
    set_toggle_state(true)
    r.Undo_EndBlock("IFLSWB: Reamp Print Toggle (Create/Arm)", -1)
  end

  r.UpdateArrange()
end

main()
