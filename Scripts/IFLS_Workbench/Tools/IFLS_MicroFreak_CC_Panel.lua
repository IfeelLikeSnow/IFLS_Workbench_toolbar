-- @description IFLS Workbench - MicroFreak CC Panel (ReaImGui)
-- @version 0.67.0
-- @author IfeelLikeSnow

-- CC Panel for Arturia MicroFreak: sends CC to selected MIDI output device.
-- Reads CC map from: Scripts/IFLS_Workbench/Workbench/MicroFreak/Data/microfreak_cc_map.json
-- Requires ReaImGui for GUI.

local r = reaper
local Lib = require("IFLS_Workbench/Workbench/MicroFreak/IFLS_MicroFreak_Lib")

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*all"); f:close()
  return d
end

local function json_decode(str)
  local ok, j = pcall(function() return r.JSON_Decode(str) end)
  if ok and j then return j end
  -- fallback: use dkjson if present
  local ok2, dk = pcall(require, "dkjson")
  if ok2 and dk then
    local obj, pos, err = dk.decode(str, 1, nil)
    if obj then return obj end
  end
  return nil
end

local function wb_root()
  return r.GetResourcePath().."/Scripts/IFLS_Workbench"
end

local map_path = wb_root().."/Workbench/MicroFreak/Data/microfreak_cc_map.json"
if not file_exists(map_path) then
  r.MB("Missing CC map:\n"..map_path, "MicroFreak CC Panel", 0)
  return
end

local map = json_decode(read_file(map_path) or "")
if not map or not map.cc then
  r.MB("Failed to parse CC map JSON.", "MicroFreak CC Panel", 0)
  return
end

if not r.ImGui_CreateContext then
  r.MB("ReaImGui not installed. Install ReaImGui to use this panel.", "MicroFreak CC Panel", 0)
  return
end

-- MIDI output device selection
local function list_midi_outputs()
  local out = {}
  local n = r.GetNumMIDIOutputs()
  for i = 0, n-1 do
    local rv, name = r.GetMIDIOutputName(i, "")
    if rv then out[#out+1] = {id=i, name=name} end
  end
  return out
end

local midi_outs = list_midi_outputs()
local out_index = 1
local channel = (map.midi and map.midi.channel_default) or 1
if channel < 1 then channel = 1 end
if channel > 16 then channel = 16 end

local out_handle = nil
local function open_out()
  if out_handle then r.CloseMIDIOutput(out_handle); out_handle=nil end
  if #midi_outs == 0 then return end
  local dev = midi_outs[out_index]
  if not dev then return end
  out_handle = r.CreateMIDIOutput(dev.id, false)
end
open_out()

local function send_cc(cc, val)
  if not out_handle then return end
  if val < 0 then val = 0 end
  if val > 127 then val = 127 end
  local status = 0xB0 + ((channel-1) & 0x0F)
  local msg = status | (cc << 8) | (val << 16)
  r.SendMsgToMIDIOutput(out_handle, msg)
end

-- UI state
local ctx = r.ImGui_CreateContext("MicroFreak CC Panel")
local search = ""
local last_vals = {}
for _,p in ipairs(map.cc) do
  last_vals[p.name] = 0
end

local function group_params()
  local groups = {}
  for _,p in ipairs(map.cc) do
    local g = p.group or "Other"
    groups[g] = groups[g] or {}
    table.insert(groups[g], p)
  end
  return groups
end
local groups = group_params()

local function combo_items(list)
  local s = ""
  for i,item in ipairs(list) do
    s = s .. item.name
    if i < #list then s = s .. "\0" end
  end
  return s .. "\0"
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 980, 640, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS MicroFreak CC Panel", true)
  if visible then
    r.ImGui_TextWrapped(ctx, "Select MIDI Output + Channel, then tweak parameters. Values are sent as MIDI CC to the chosen output.")
    r.ImGui_Separator(ctx)

    -- Output selection
    if #midi_outs == 0 then
      r.ImGui_Text(ctx, "No MIDI outputs found in REAPER Preferences.")
    else
      local names = {}
      for _,d in ipairs(midi_outs) do names[#names+1] = {name=d.name} end
      local items = combo_items(names)
      local changed, idx = r.ImGui_Combo(ctx, "MIDI Output", out_index-1, items)
      if changed then
        out_index = idx+1
        open_out()
      end
    end

    local ch_changed, ch_val = r.ImGui_SliderInt(ctx, "MIDI Channel", channel, 1, 16)
    if ch_changed then channel = ch_val end

    local s_changed, s_val = r.ImGui_InputText(ctx, "Search", search)
    if s_changed then search = s_val end

    r.ImGui_Separator(ctx)

    local q = (search or ""):lower()

    for gname, plist in pairs(groups) do
      r.ImGui_SeparatorText(ctx, gname)
      for _,p in ipairs(plist) do
        local pname = p.name or ("CC "..tostring(p.cc))
        local hit = (q == "") or (pname:lower():find(q,1,true) ~= nil) or (gname:lower():find(q,1,true) ~= nil)
        if hit then
          local v0 = last_vals[pname] or 0
          local changed, v = r.ImGui_SliderInt(ctx, pname.."  (CC "..tostring(p.cc)..")", v0, 0, 127)
          if changed then
            last_vals[pname] = v
            send_cc(tonumber(p.cc), tonumber(v))
          end
        end
      end
    end

r.ImGui_Separator(ctx)
if r.ImGui_Button(ctx, "Save CC snapshot as Project Recall") then
  local out_dev = (#midi_outs>0 and midi_outs[out_index] and midi_outs[out_index].id) or nil
  local snap = { channel = channel, values = {} }
  for _,p in ipairs(map.cc) do
    local cc = tonumber(p.cc)
    local v = tonumber(last_vals[p.name] or 0)
    snap.values[cc] = v
  end
  Lib.set_proj_recall(0, nil, snap, channel, out_dev)
  r.MB("Saved CC snapshot into Project Recall.", "MicroFreak CC Panel", 0)
end
r.ImGui_SameLine(ctx)
if r.ImGui_Button(ctx, "Load & Send Recall CC snapshot") then
  local rec = Lib.get_proj_recall(0)
  local out_dev = rec.out_dev or ((#midi_outs>0 and midi_outs[out_index] and midi_outs[out_index].id) or nil)
  local ch = rec.channel or channel
  if not rec.cc then
    r.MB("No CC snapshot stored in Project Recall.", "MicroFreak CC Panel", 0)
  else
    for cc,val in pairs(rec.cc.values or {}) do
      for _,p in ipairs(map.cc) do
        if tonumber(p.cc) == tonumber(cc) then
          last_vals[p.name] = tonumber(val) or 0
        end
      end
    end
    local ok, info = Lib.send_cc_snapshot(out_dev, ch, rec.cc)
    r.MB(ok and "Sent CC snapshot." or ("Failed: "..tostring(info)), "MicroFreak CC Panel", 0)
  end
end

    r.ImGui_TextWrapped(ctx, "Tip: Record automation by routing this output to the MicroFreak track, or use ReaControlMIDI if you prefer CC lanes.")
    r.ImGui_End(ctx)
  end

  if open then
    r.defer(loop)
  else
    if out_handle then r.CloseMIDIOutput(out_handle) end
    r.ImGui_DestroyContext(ctx)
  end
end

r.defer(loop)
