-- @description IFLS Workbench - PSS580/IFLS_PSS580_Lib.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_PSS580_Lib.lua
-- Shared helpers for PSS-580 SysEx patch workflows (Library + Project Recall)
--
-- Dependencies:
-- - SWS for SNM_SendSysEx (send)
-- - ReaImGui for browser UI (optional)
-- - IFLS bootstrap for paths/utilities (optional)

local r = reaper

local M = {}

-- Device port defaults (from MIDINetwork ExtState)
local DevPorts = nil
pcall(function()
  DevPorts = dofile((reaper.GetResourcePath().."/Scripts/IFLS_Workbench").."/Workbench/MIDINetwork/Lib/IFLS_DevicePortDefaults.lua")
end)

local Boot_ok, Boot = pcall(require, "IFLS_Workbench/_bootstrap")
if not Boot_ok then Boot = nil end

local SafeApply = nil
do
  local ok, mod = pcall(require, "IFLS_Workbench/Engine/IFLS_SafeApply")
  if ok then SafeApply = mod end
end

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

local function to_hex(bytes)
  return (bytes:gsub(".", function(c) return string.format("%02X", string.byte(c)) end))
end

local function from_hex(hex)
  hex = hex:gsub("%s+", "")
  if (#hex % 2) ~= 0 then return nil, "hex length must be even" end
  local out = {}
  for i = 1, #hex, 2 do
    local b = tonumber(hex:sub(i,i+1), 16)
    if not b then return nil, "bad hex at "..i end
    out[#out+1] = string.char(b)
  end
  return table.concat(out)
end

local function ensure_f0f7(payload, include_f0f7)
  if not payload then return nil end
  if not include_f0f7 then
    -- strip if present
    if #payload >= 2 and payload:byte(1) == 0xF0 and payload:byte(#payload) == 0xF7 then
      return payload:sub(2, #payload-1)
    end
    return payload
  end

  if #payload >= 2 and payload:byte(1) == 0xF0 and payload:byte(#payload) == 0xF7 then
    return payload
  end
  return string.char(0xF0) .. payload .. string.char(0xF7)
end

M.file_exists = file_exists
M.read_file = read_file
M.to_hex = to_hex
M.from_hex = from_hex
M.ensure_f0f7 = ensure_f0f7

function M.get_scripts_root()
  if Boot and Boot.scripts_root then return Boot.scripts_root end
  return r.GetResourcePath().."/Scripts"
end

function M.load_json(relpath)
  local scripts_root = M.get_scripts_root()
  local path = scripts_root .. "/" .. relpath
  if not file_exists(path) then return nil, "missing: "..path end

  local txt = read_file(path)
  if not txt then return nil, "cannot read: "..path end

  -- try to decode via existing JSON module (Workbench validator uses one too)
  local JSON = nil
  if Boot and Boot.safe_require then
    JSON = Boot.safe_require("IFLS_Workbench/Lib/json") or Boot.safe_require("json")
  end
  if not JSON or not JSON.decode then return nil, "JSON decoder missing (install json module shipped with Workbench)" end

  local ok, obj = pcall(JSON.decode, txt)
  if not ok then return nil, obj end
  return obj, nil
end

-- Sends a .syx file via SWS SNM_SendSysEx.
-- include_f0f7: if true and file lacks F0/F7, wrap.
-- delay_ms: optional short delay after send (device busy)
function M.send_syx_file(device_out, abs_path, include_f0f7, delay_ms)
  if device_out == nil and DevPorts and DevPorts.get_out_idx then
    device_out = DevPorts.get_out_idx("pss580")
  end
  if not r.SNM_SendSysEx then
    return false, "SWS missing (SNM_SendSysEx unavailable). Install SWS."
  end
  if not abs_path or abs_path == "" then return false, "syx path empty" end
  if not file_exists(abs_path) then return false, "missing file: "..abs_path end

  local payload = read_file(abs_path)
  if not payload then return false, "read failed: "..abs_path end

  payload = ensure_f0f7(payload, include_f0f7)

  -- SNM_SendSysEx expects a string of bytes
  local ok = r.SNM_SendSysEx(device_out, payload)
  if not ok then return false, "SNM_SendSysEx failed" end

  if delay_ms and delay_ms > 0 then
    r.Sleep(delay_ms)
  end
  return true
end

-- Project recall storage (ExtState).
-- We store:
-- - recall_id (manifest item id)
-- - syx_hex (sysex bytes hex, so project is portable)
local PROJ_NS = "IFLS_PSS580"

function M.set_project_recall(id, syx_bytes)
  if not r.SetProjExtState then return false, "REAPER too old (SetProjExtState missing)" end
  local proj = 0

  local ok = r.SetProjExtState(proj, PROJ_NS, "recall_id", id or "")
  if ok == 0 then return false, "SetProjExtState failed" end

  if syx_bytes and #syx_bytes > 0 then
    local hex = to_hex(syx_bytes)
    r.SetProjExtState(proj, PROJ_NS, "recall_syx_hex", hex)
  else
    r.SetProjExtState(proj, PROJ_NS, "recall_syx_hex", "")
  end
  return true
end

function M.get_project_recall()
  if not r.GetProjExtState then return nil end
  local proj = 0
  local _, id = r.GetProjExtState(proj, PROJ_NS, "recall_id")
  local _, hex = r.GetProjExtState(proj, PROJ_NS, "recall_syx_hex")
  id = id or ""
  hex = hex or ""
  if hex == "" then return {id=id, syx=nil} end
  local bytes, err = from_hex(hex)
  return {id=id, syx=bytes, err=err}
end

-- Ensure recall track exists and contains a small "marker" MIDI item for human visibility.
function M.ensure_recall_track()
  local name = "PSS580 SYSEx RECALL (SEND)"
  local tr = nil
  for i = 0, r.CountTracks(0)-1 do
    local t = r.GetTrack(0, i)
    local _, tn = r.GetTrackName(t)
    if tn == name then tr = t; break end
  end

  if tr then return tr, false end

  r.InsertTrackAtIndex(r.CountTracks(0), true)
  tr = r.GetTrack(0, r.CountTracks(0)-1)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
  return tr, true
end

-- Create/replace a tiny MIDI item at project start that tells user which recall is set.
function M.write_recall_marker_item(track, label)
  if not track then return false end
  -- remove existing items on track (optional)
  local item_count = r.CountTrackMediaItems(track)
  for i = item_count-1, 0, -1 do
    r.DeleteTrackMediaItem(track, r.GetTrackMediaItem(track, i))
  end
  local item = r.AddMediaItemToTrack(track)
  r.SetMediaItemInfo_Value(item, "D_POSITION", 0.0)
  r.SetMediaItemInfo_Value(item, "D_LENGTH", 1.0)
  local take = r.AddTakeToMediaItem(item)
  r.GetSetMediaItemTakeInfo_String(take, "P_NAME", label or "PSS580 Recall", true)

  -- Insert a TEXT event with recall id (not SysEx) so the item is self-describing.
  -- type: 1 for text event
  local ppq = r.MIDI_GetPPQPosFromProjTime(take, 0.0)
  r.MIDI_InsertTextSysexEvt(take, false, false, ppq, 1, "IFLS_PSS580_RECALL_MARKER")
  r.MIDI_Sort(take)
  return true
end

-- Wrap project modifications safely if SafeApply exists.
function M.safe_run(undo_name, fn)
  if SafeApply and SafeApply.run then
    return SafeApply.run(undo_name, fn)
  end
  -- fallback
  r.Undo_BeginBlock()
  local ok, err = pcall(fn)
  r.Undo_EndBlock(undo_name or "IFLS PSS580", -1)
  if not ok then return false, err end
  return true
end

return M
