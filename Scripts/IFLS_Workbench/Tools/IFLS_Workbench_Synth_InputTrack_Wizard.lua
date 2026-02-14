-- @description IFLS Workbench - Synth Audio-In Track Wizard (SoT + Patchbay link + Architecture Mode)
-- @version 0.112.0
-- @author IfeelLikeSnow
-- @about
--   Creates audio input tracks for synths based on Data/IFLS_Workbench/device_defaults.json (Single Source of Truth).
--   Links to Data/IFLS_Workbench/patchbay.json to show patchbay channels / notes in the UI.
--   Architecture Mode:
--     (A) Synth Tracks -> SYNTH BUS -> FXBUS -> COLOR BUS -> MASTER BUS
--     (B) Synth Tracks -> FXBUS -> COLOR BUS -> MASTER BUS
--   Buses are created only if missing (never duplicates).
--   FB-01 is created as a single stereo track if device_defaults defines input_pair.
--
--   If ReaImGui is not available, script falls back to creating ALL tracks using Architecture (A).

local r = reaper

local function join(a,b)
  if a:sub(-1)=="\\" or a:sub(-1)=="/" then return a..b end
  return a.."/"..b
end

local function read_file(path)
  local f = io.open(path,"rb"); if not f then return nil end
  local s = f:read("*all"); f:close(); return s
end

local function json_decode(str)
  local ok, res = pcall(function() return r.JSON_Parse(str) end)
  if ok and res then return res end
  return nil
end

local function get_resource_path()
  return r.GetResourcePath()
end

local function load_json_from_datadir(rel)
  local path = join(get_resource_path(), "Data/IFLS_Workbench/"..rel)
  local s = read_file(path)
  if not s then return nil, "Missing: "..path end
  local t = json_decode(s)
  if not t then return nil, "Failed to parse JSON (requires REAPER 7+ JSON_Parse): "..path end
  return t, nil
end

local function norm_name(s)
  return (s or ""):lower():gsub("%s+"," "):gsub("^%s+",""):gsub("%s+$","")
end

local function find_track_by_name(name)
  local target = norm_name(name)
  for i=0, r.CountTracks(0)-1 do
    local tr = r.GetTrack(0,i)
    local _, tn = r.GetTrackName(tr,"")
    if norm_name(tn) == target then return tr end
  end
  return nil
end

local function ensure_track(name)
  local tr = find_track_by_name(name)
  if tr then return tr, false end
  r.InsertTrackAtIndex(r.CountTracks(0), true)
  tr = r.GetTrack(0, r.CountTracks(0)-1)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  return tr, true
end

-- Inputs
local function set_track_input_mono(tr, input_index_1based)
  r.SetMediaTrackInfo_Value(tr, "I_RECINPUT", math.max(0, (input_index_1based or 1)-1))
  r.SetMediaTrackInfo_Value(tr, "I_RECMODE", 0) -- record input
  r.SetMediaTrackInfo_Value(tr, "I_RECARM", 1)
  r.SetMediaTrackInfo_Value(tr, "I_RECMON", 1)
end

local function set_track_input_stereo_pair(tr, inL_1based, inR_1based)
  local L = inL_1based or 1
  local pair_index = math.floor((L-1)/2)
  r.SetMediaTrackInfo_Value(tr, "I_RECINPUT", 1024 + pair_index)
  r.SetMediaTrackInfo_Value(tr, "I_RECMODE", 0)
  r.SetMediaTrackInfo_Value(tr, "I_RECARM", 1)
  r.SetMediaTrackInfo_Value(tr, "I_RECMON", 1)
end

local function disable_master_send(tr)
  r.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
end

local function add_send(src, dst)
  local send_idx = r.CreateTrackSend(src, dst)
  r.SetTrackSendInfo_Value(src, 0, send_idx, "D_VOL", 1.0)
  return send_idx
end

local function ensure_single_send(a,b)
  for si=0, r.GetTrackNumSends(a,0)-1 do
    local dest = r.GetTrackSendInfo_Value(a,0,si,"P_DESTTRACK")
    if dest == b then return end
  end
  add_send(a,b)
end

-- Buses
local function ensure_bus_chain(arch_mode) -- "A" or "B"
  local fx = ensure_track("FXBUS")
  local color = ensure_track("COLOR BUS")
  local master = ensure_track("MASTER BUS")

  -- Explicit chain
  disable_master_send(fx)
  disable_master_send(color)
  r.SetMediaTrackInfo_Value(master, "B_MAINSEND", 1)

  ensure_single_send(fx, color)
  ensure_single_send(color, master)

  if arch_mode == "A" then
    local synthbus = ensure_track("SYNTH BUS")
    disable_master_send(synthbus)
    ensure_single_send(synthbus, fx)
    return fx, color, master, synthbus
  end

  return fx, color, master, nil
end

-- Patchbay link helper
local function load_patchbay()
  local pb, err = load_json_from_datadir("patchbay.json")
  if not pb then return nil, err end
  return pb, nil
end

local function patchbay_note_for_channels(pb, ch_list)
  if not pb or not ch_list or #ch_list==0 then return "" end
  local notes = {}
  local function add_note_from(section)
    for _,e in ipairs(pb[section] or {}) do
      local pcs = e.patchbay_channels or {}
      for _,ch in ipairs(ch_list) do
        for _,pch in ipairs(pcs) do
          if pch == ch then
            notes[#notes+1] = e.name or ""
            break
          end
        end
      end
    end
  end
  add_note_from("inputs")
  add_note_from("outputs")
  -- Dedup
  local seen, out = {}, {}
  for _,n in ipairs(notes) do
    local k = norm_name(n)
    if k ~= "" and not seen[k] then
      seen[k]=true
      out[#out+1]=n
    end
  end
  return table.concat(out, " | ")
end

local function format_channels(ch_list)
  if not ch_list or #ch_list==0 then return "" end
  if #ch_list==1 then return tostring(ch_list[1]) end
  return table.concat(ch_list, "/")
end

-- Core create
local function create_synth_track(dev_key, dev, arch_mode, pb)
  local fx, color, master, synthbus = ensure_bus_chain(arch_mode)
  local name = dev.name or dev_key
  local tr = ensure_track(name)

  -- set input
  if dev.mode == "stereo" and dev.reaper_input_pair and dev.reaper_input_pair[1] then
    set_track_input_stereo_pair(tr, dev.reaper_input_pair[1], dev.reaper_input_pair[2] or (dev.reaper_input_pair[1]+1))
  else
    set_track_input_mono(tr, dev.reaper_input or 1)
  end

  -- routing
  disable_master_send(tr)
  if arch_mode == "A" and synthbus then
    ensure_single_send(tr, synthbus)
  else
    ensure_single_send(tr, fx)
  end

  -- optional: annotate track notes with patchbay hint (non-destructive)
  local chans = {}
  if dev.mode == "stereo" and dev.reaper_input_pair and dev.reaper_input_pair[1] then
    chans = {dev.reaper_input_pair[1], dev.reaper_input_pair[2] or (dev.reaper_input_pair[1]+1)}
  else
    chans = {dev.reaper_input or 1}
  end
  local pb_note = patchbay_note_for_channels(pb, chans)
  if pb_note ~= "" then
    -- Put hint into track notes (P_NOTES)
    local _, old = r.GetSetMediaTrackInfo_String(tr, "P_NOTES", "", false)
    local tag = "[IFLS Patchbay]"
    if not old:find(tag, 1, true) then
      local new = (old or "")
      if new ~= "" and new:sub(-1) ~= "\n" then new = new .. "\n" end
      new = new .. tag .. " " .. pb_note .. "\n"
      r.GetSetMediaTrackInfo_String(tr, "P_NOTES", new, true)
    end
  end

  return tr
end

local function create_all(dd, arch_mode, pb)
  local ai = dd.audio_inputs or {}
  for k, dev in pairs(ai) do
    create_synth_track(k, dev, arch_mode, pb)
  end
end

-- UI
local function has_reaimgui()
  return r.ImGui_CreateContext ~= nil
end

local dd, err = load_json_from_datadir("device_defaults.json")
if not dd then
  r.MB("IFLS Synth Wizard:\n"..(err or "Unknown error"), "IFLS Workbench", 0)
  return
end

local pb = nil
do
  local t, e = load_patchbay()
  pb = t -- ok if nil
end

local DEFAULT_ARCH = "A" -- safer default
if not has_reaimgui() then
  create_all(dd, DEFAULT_ARCH, pb)
  r.UpdateArrange()
  return
end

local ctx = r.ImGui_CreateContext("IFLS Synth Input Tracks")
local FONT = r.ImGui_CreateFont("sans-serif", 14)
r.ImGui_Attach(ctx, FONT)

local keys = {}
do
  for k,_ in pairs(dd.audio_inputs or {}) do keys[#keys+1]=k end
  table.sort(keys)
end
local selected = 1
local arch_mode = DEFAULT_ARCH

local function device_label(k)
  local dev = (dd.audio_inputs or {})[k] or {}
  local name = dev.name or k
  local chans = {}
  if dev.mode == "stereo" and dev.reaper_input_pair and dev.reaper_input_pair[1] then
    chans = {dev.reaper_input_pair[1], dev.reaper_input_pair[2] or (dev.reaper_input_pair[1]+1)}
  else
    chans = {dev.reaper_input or 1}
  end
  local ch_txt = format_channels(chans)
  local note = patchbay_note_for_channels(pb, chans)
  local suffix = ""
  if ch_txt ~= "" then suffix = suffix .. "  [IN "..ch_txt.."]" end
  if note ~= "" then suffix = suffix .. "  •  "..note end
  return name..suffix
end

local function loop()
  r.ImGui_PushFont(ctx, FONT)
  local visible, open = r.ImGui_Begin(ctx, "IFLS Synth Input Tracks", true, r.ImGui_WindowFlags_AlwaysAutoResize())
  if visible then
    r.ImGui_Text(ctx, "Create audio input tracks (no duplicates).")
    r.ImGui_Separator(ctx)

    -- Architecture Mode
    r.ImGui_Text(ctx, "Architecture Mode:")
    local changedA; changedA, arch_mode = r.ImGui_RadioButton(ctx, "A) Synth Tracks -> SYNTH BUS -> FXBUS", arch_mode == "A"), arch_mode
    if changedA then arch_mode = "A" end
    local changedB; changedB, arch_mode = r.ImGui_RadioButton(ctx, "B) Synth Tracks -> FXBUS (direct)", arch_mode == "B"), arch_mode
    if changedB then arch_mode = "B" end

    r.ImGui_Separator(ctx)

    if #keys == 0 then
      r.ImGui_Text(ctx, "No devices in device_defaults.json")
    else
      local preview = device_label(keys[selected])
      if r.ImGui_BeginCombo(ctx, "Device", preview) then
        for i=1,#keys do
          local k = keys[i]
          local nm = device_label(k)
          local is_sel = (i==selected)
          if r.ImGui_Selectable(ctx, nm, is_sel) then selected=i end
          if is_sel then r.ImGui_SetItemDefaultFocus(ctx) end
        end
        r.ImGui_EndCombo(ctx)
      end

      if r.ImGui_Button(ctx, "Create selected") then
        local k = keys[selected]
        create_synth_track(k, dd.audio_inputs[k], arch_mode, pb)
      end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "Create ALL") then
        create_all(dd, arch_mode, pb)
      end
    end

    r.ImGui_Separator(ctx)
    if arch_mode == "A" then
      r.ImGui_Text(ctx, "Buses: SYNTH BUS -> FXBUS -> COLOR BUS -> MASTER BUS")
    else
      r.ImGui_Text(ctx, "Buses: FXBUS -> COLOR BUS -> MASTER BUS")
    end
    if pb then
      r.ImGui_Text(ctx, "Patchbay link: patchbay.json loaded (notes shown + written to track notes).")
    else
      r.ImGui_Text(ctx, "Patchbay link: patchbay.json not found/parsed (notes hidden).")
    end
    r.ImGui_End(ctx)
  end
  r.ImGui_PopFont(ctx)

  if open then
    r.defer(loop)
  else
    r.ImGui_DestroyContext(ctx)
  end
end

loop()
