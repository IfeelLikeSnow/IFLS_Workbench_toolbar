-- @description IFLS Workbench - Reamp Print Toggle (Topology Auto-Find)
-- @version 1.1.0
-- @author IFLS Workbench
-- @about
-- Topology-first auto-detection of FX/Coloring/Master buses using routing graph (sends/receives).
--
-- Run once:
--   - Detect FX Bus (graph) in the selected routing component (if a track is selected), else global.
--   - Insert "REAMP PRINT (from FX Bus)" right after FX Bus (before downstream bus if immediately next).
--   - Route FX Bus -> REAMP using post-FX send (I_SENDMODE=3) and arm REAMP for output recording:
--     record output (stereo, latency compensated) + post-FX / pre-fader.
--
-- Run again (while REAMP is armed):
--   - Finalize: disarm REAMP, route REAMP to Coloring bus if detected, else Master bus, else project master.
--   - Mute + bypass FX bus and all source tracks that feed it (its receives).
--   - Leave downstream buses active.
--
-- Notes:
--   - Graph detection uses explicit sends/receives. If your setup is folder-only routing, select the FX bus once
--     before running and it will still lock onto the correct routing component.
--
-- API notes:
--   - I_SENDMODE: 3=post-fx (2 deprecated)
--   - I_RECMODE: 3 = output (stereo, latency compensated)
--   - I_RECMODE_FLAGS &3: 2 = post-fx / pre-fader

local r = reaper

----------------------------
-- small helpers
----------------------------
local function get_name(tr)
  local ok, name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
  return ok and (name or "") or ""
end

local function track_idx0(tr)
  local tn = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
  if not tn or tn < 1 then return nil end
  return math.floor(tn - 1 + 0.5)
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

local function is_leaf_source(tr)
  -- "leaf" meaning: no receives (doesn't look like a bus)
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
  if idx == nil then
    idx = r.CreateTrackSend(src, dest)
  end
  if idx and idx >= 0 then
    if sendmode ~= nil then
      r.SetTrackSendInfo_Value(src, 0, idx, "I_SENDMODE", sendmode)
    end
    r.SetTrackSendInfo_Value(src, 0, idx, "D_VOL", 1.0)
    r.SetTrackSendInfo_Value(src, 0, idx, "D_PAN", 0.0)
  end
  return idx
end

local function set_output_rec_mode(tr)
  -- record output (stereo, latency compensated)
  r.SetMediaTrackInfo_Value(tr, "I_RECMODE", 3)

  -- post-FX / pre-fader
  local flags = r.GetMediaTrackInfo_Value(tr, "I_RECMODE_FLAGS") or 0
  flags = math.floor(flags + 0.5)
  flags = flags - (flags % 4)  -- clear lower 2 bits
  flags = flags + 2           -- 2 = post-fx / pre-fader
  r.SetMediaTrackInfo_Value(tr, "I_RECMODE_FLAGS", flags)
end

local function find_reamp_track_near(fx_bus)
  local fx_i = track_idx0(fx_bus)
  if not fx_i then return nil end
  local n = r.CountTracks(0)
  for i=math.max(0, fx_i-2), math.min(n-1, fx_i+5) do
    local tr = r.GetTrack(0,i)
    local ok, v = r.GetSetMediaTrackInfo_String(tr, "P_EXT:IFLSWB_REAMP_PRINT", "", false)
    if ok and v == "1" then return tr end
    local nm = (get_name(tr) or ""):lower()
    if nm:find("reamp") and (nm:find("print") or nm:find("render") or nm:find("rec")) then
      return tr
    end
  end
  return nil
end

----------------------------
-- routing-graph topology find
----------------------------
local function build_component(seed_tr)
  local n = r.CountTracks(0)
  local idx_of = {}
  local tracks = {}
  for i=0,n-1 do
    local tr = r.GetTrack(0,i)
    tracks[i+1] = tr
    idx_of[tr] = i
  end

  -- undirected adjacency via receive edges
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

  local in_comp = {}
  local q = {}
  if seed_tr and idx_of[seed_tr] ~= nil then
    q[1] = idx_of[seed_tr]
  else
    -- nil seed means whole project as component
    for i=0,n-1 do in_comp[i]=true end
    return in_comp, idx_of
  end

  local head = 1
  in_comp[q[1]] = true
  while head <= #q do
    local v = q[head]; head = head + 1
    for nb,_ in pairs(adj[v]) do
      if not in_comp[nb] then
        in_comp[nb] = true
        q[#q+1] = nb
      end
    end
  end

  return in_comp, idx_of
end

local function score_fx_candidate(tr)
  local recv_srcs = get_receives(tr)
  local in_deg = #recv_srcs
  if in_deg == 0 then return -1e9 end

  local leaf = 0
  local bus_src = 0
  for _,src in ipairs(recv_srcs) do
    if is_leaf_source(src) then leaf = leaf + 1 else bus_src = bus_src + 1 end
  end

  local sends = get_sends(tr)
  local out_deg = #sends
  local mainsend = r.GetMediaTrackInfo_Value(tr, "B_MAINSEND") or 0

  -- bus-like:
  -- prefer: multiple leaf sources feeding it + has an output somewhere
  local score = 0
  score = score + in_deg * 12
  score = score + leaf * 10
  score = score + out_deg * 4
  score = score + (mainsend > 0 and 2 or 0)
  score = score - bus_src * 3  -- receives from other buses can be less "FX bus"-like

  return score
end

local function pick_best_send_dest(send_list)
  if #send_list == 0 then return nil end
  table.sort(send_list, function(a,b)
    if a.vol == b.vol then
      -- tie-break by dest receives (more bus-like)
      local ar = r.GetTrackNumSends(a.dest, -1)
      local br = r.GetTrackNumSends(b.dest, -1)
      return ar > br
    end
    return a.vol > b.vol
  end)
  return send_list[1].dest
end

local function find_buses_topology()
  local sel = r.GetSelectedTrack(0,0)
  local comp, idx_of = build_component(sel)

  local n = r.CountTracks(0)
  local best_fx, best_score = nil, -1e18

  for i=0,n-1 do
    if comp[i] then
      local tr = r.GetTrack(0,i)
      local sc = score_fx_candidate(tr)
      if sc > best_score then
        best_fx, best_score = tr, sc
      end
    end
  end

  -- Fallback to name heuristics if nothing bus-like
  if not best_fx or best_score < 0 then
    for i=0,n-1 do
      if comp[i] then
        local tr = r.GetTrack(0,i)
        local nm = (get_name(tr) or ""):lower()
        if nm:find("fx") and nm:find("bus") then best_fx = tr break end
      end
    end
  end

  if not best_fx then return nil, nil, nil end

  local fx_sends = get_sends(best_fx)
  local coloring = pick_best_send_dest(fx_sends)

  local master_bus = nil
  if coloring then
    local col_sends = get_sends(coloring)
    master_bus = pick_best_send_dest(col_sends)
  end

  return best_fx, coloring, master_bus
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
    if d_i and d_i == fx_i + 1 then
      insert_i = d_i -- insert between FX and downstream bus
    end
  end

  r.InsertTrackAtIndex(insert_i, true)
  local reamp = r.GetTrack(0, insert_i)
  if not reamp then return nil, "Failed to create REAMP track" end

  set_name(reamp, "REAMP PRINT (from FX Bus)")
  r.GetSetMediaTrackInfo_String(reamp, "P_EXT:IFLSWB_REAMP_PRINT", "1", true)

  ensure_send(fx_bus, reamp, 3) -- post-fx

  r.SetMediaTrackInfo_Value(reamp, "B_MAINSEND", 0)
  r.SetMediaTrackInfo_Value(reamp, "I_RECMON", 0)

  r.SetMediaTrackInfo_Value(reamp, "I_RECARM", 1)
  set_output_rec_mode(reamp)

  r.SetOnlyTrackSelected(reamp)
  return reamp, nil
end

local function finalize(fx_bus, reamp, coloring_bus, master_bus)
  -- route REAMP to coloring/master if possible
  if coloring_bus then
    ensure_send(reamp, coloring_bus, 0) -- post-fader
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
  r.SetMediaTrackInfo_Value(fx_bus, "B_MUTE", 1)
  r.SetMediaTrackInfo_Value(fx_bus, "I_FXEN", 0)

  -- mute+bypass all sources feeding FX bus (receives)
  local nrecv = r.GetTrackNumSends(fx_bus, -1)
  for i=0,nrecv-1 do
    local src = r.GetTrackSendInfo_Value(fx_bus, -1, i, "P_SRCTRACK")
    if src and src ~= reamp then
      r.SetMediaTrackInfo_Value(src, "B_MUTE", 1)
      r.SetMediaTrackInfo_Value(src, "I_FXEN", 0)
      r.SetMediaTrackInfo_Value(src, "I_RECARM", 0)
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

  local fx_bus, coloring_bus, master_bus = find_buses_topology()
  if not fx_bus then
    r.MB("No FX bus could be detected via routing topology.\n\nTip: Select your FX Bus track and run again.", "IFLSWB Reamp Print", 0)
    set_toggle_state(false)
    r.Undo_EndBlock("IFLSWB: Reamp Print Toggle (FX bus not found)", -1)
    return
  end

  local reamp = find_reamp_track_near(fx_bus)

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
      -- exists but not armed -> arm again
      r.SetOnlyTrackSelected(reamp)
      r.SetMediaTrackInfo_Value(reamp, "B_MAINSEND", 0)
      r.SetMediaTrackInfo_Value(reamp, "I_RECMON", 0)
      r.SetMediaTrackInfo_Value(reamp, "I_RECARM", 1)
      set_output_rec_mode(reamp)
      ensure_send(fx_bus, reamp, 3)
    end
    set_toggle_state(true)
    r.Undo_EndBlock("IFLSWB: Reamp Print Toggle (Create/Arm)", -1)
  end

  r.UpdateArrange()
end

main()
