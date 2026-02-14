-- IFLS_MicroFreak_Lib.lua
local M = {}
local r = reaper

M.SECTION = "IFLS_WORKBENCH_MICROFREAK"

function M.wb_root()
  return r.GetResourcePath().."/Scripts/IFLS_Workbench"
end

-- Device port defaults (from MIDINetwork ExtState)
local DevPorts = nil
pcall(function()
  DevPorts = dofile(M.wb_root().."/Workbench/MIDINetwork/Lib/IFLS_DevicePortDefaults.lua")
end)

function M.mf_root()
  return M.wb_root().."/Workbench/MicroFreak"
end

function M.manifest_path()
  return M.mf_root().."/Patches/manifest.json"
end

function M.syx_dir()
  return M.mf_root().."/Patches/syx"
end

function M.file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

function M.read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*all"); f:close()
  return d
end

function M.write_file(path, data)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(data); f:close()
  return true
end

function M.json_decode(str)
  local ok, j = pcall(function() return r.JSON_Decode(str) end)
  if ok and j then return j end
  local ok2, dk = pcall(require, "dkjson")
  if ok2 and dk then
    local obj = dk.decode(str)
    return obj
  end
  return nil
end

function M.json_encode(obj)
  local ok, s = pcall(function() return r.JSON_Encode(obj) end)
  if ok and s then return s end
  local ok2, dk = pcall(require, "dkjson")
  if ok2 and dk then
    return dk.encode(obj, { indent = true })
  end
  return nil
end

function M.set_proj_recall(proj, syx_path, cc_table, channel, out_dev)
  proj = proj or 0
  if syx_path then r.SetProjExtState(proj, M.SECTION, "recall_syx", syx_path) end
  if channel then r.SetProjExtState(proj, M.SECTION, "recall_channel", tostring(channel)) end
  if out_dev ~= nil then r.SetProjExtState(proj, M.SECTION, "recall_out_dev", tostring(out_dev)) end
  if cc_table then
    local s = M.json_encode(cc_table) or ""
    r.SetProjExtState(proj, M.SECTION, "recall_cc_json", s)
  end
end

function M.get_proj_recall(proj)
  proj = proj or 0
  local _, syx = r.GetProjExtState(proj, M.SECTION, "recall_syx")
  local _, ccj = r.GetProjExtState(proj, M.SECTION, "recall_cc_json")
  local _, ch  = r.GetProjExtState(proj, M.SECTION, "recall_channel")
  local _, out = r.GetProjExtState(proj, M.SECTION, "recall_out_dev")
  local cc = nil
  if ccj and ccj ~= "" then cc = M.json_decode(ccj) end
  return {
    syx = (syx ~= "" and syx) or nil,
    cc = cc,
    channel = tonumber(ch or "") or nil,
    out_dev = tonumber(out or "") or nil
  }
end

function M.resolve_syx_path(syx_path)
  if not syx_path or syx_path == "" then return nil end
  local p = syx_path:gsub("\\","/")
  if M.file_exists(p) then return p end
  local libp = M.syx_dir().."/"..p
  if M.file_exists(libp) then return libp end
  local libp2 = M.mf_root().."/"..p
  if M.file_exists(libp2) then return libp2 end
  return nil
end

function M.send_syx_file(out_dev, syx_path)
  if not r.SNM_SendSysEx then
    return false, "SWS missing (SNM_SendSysEx)"
  end
  if out_dev == nil and DevPorts and DevPorts.get_out_idx then
    out_dev = DevPorts.get_out_idx("microfreak")
  end
  if out_dev == nil then
    return false, "No MIDI output device selected (set defaults via Apply Port Names + Indexes)"
  end
  local abs = M.resolve_syx_path(syx_path)
  if not abs then
    return false, "SysEx file not found: "..tostring(syx_path)
  end
  local ok = r.SNM_SendSysEx(out_dev, abs)
  if ok == 0 or ok == false then
    return false, "SNM_SendSysEx failed"
  end
  return true, abs
end

function M.send_cc_snapshot(out_dev, channel, cc_snapshot)
  if not out_dev and DevPorts and DevPorts.get_out_idx then out_dev = DevPorts.get_out_idx("microfreak") end
  if not out_dev or not cc_snapshot then return false, "Missing out_dev or cc_snapshot (set defaults via Apply Port Names + Indexes)" end
  local h = r.CreateMIDIOutput(out_dev, false)
  if not h then return false, "Failed to open MIDI output" end
  channel = channel or cc_snapshot.channel or 1
  local ch0 = ((channel-1) & 0x0F)
  for cc, val in pairs(cc_snapshot.values or {}) do
    local status = 0xB0 + ch0
    local msg = status | ((tonumber(cc) & 0x7F) << 8) | ((tonumber(val) & 0x7F) << 16)
    r.SendMsgToMIDIOutput(h, msg)
  end
  r.CloseMIDIOutput(h)
  return true
end

return M
