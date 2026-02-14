-- IFLS MIDINetwork Lib
-- Reads Workbench/MIDINetwork/Data/midinet_profile.json and provides helper functions
-- Version: 0.73.0

local r = reaper

local M = {}

local function wb_root()
  return r.GetResourcePath().."/Scripts/IFLS_Workbench"
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*all")
  f:close()
  return d
end

local function json_decode(str)
  local ok, j = pcall(function() return r.JSON_Decode(str) end)
  if ok and j then return j end
  local ok2, dk = pcall(require, "dkjson")
  if ok2 and dk then
    return dk.decode(str)
  end
  return nil
end

function M.load_profile()
  local path = wb_root().."/Workbench/MIDINetwork/Data/midinet_profile.json"
  local raw = read_file(path)
  if not raw then return nil, "missing profile json: "..path end
  local prof = json_decode(raw)
  if not prof then return nil, "failed to parse json: "..path end
  return prof, nil
end

function M.get_device(profile, id)
  if not profile or not profile.devices then return nil end
  for _,d in ipairs(profile.devices) do
    if d.id == id then return d end
  end
  return nil
end

-- Returns default MIDI channels for a device id.
-- FB-01: returns list {1..8}; otherwise returns {default_channel} or {1}.
function M.get_default_channels(profile, id)
  local d = M.get_device(profile, id)
  if not d then return {1} end
  if d.default_channels and type(d.default_channels) == "table" then
    return d.default_channels
  end
  if d.default_channel then
    return {tonumber(d.default_channel) or 1}
  end
  return {1}
end

-- Persist recommended device defaults to ExtState so all device tools can use them.
-- out_dev is unknown at this stage; user should set it manually or via tool UI.
function M.apply_defaults_to_extstate(profile)
  local SECTION = "IFLS_WORKBENCH_DEVICES"
  local function set(k,v) r.SetExtState(SECTION, k, tostring(v), true) end

  -- Channels
  local fb = M.get_device(profile, "fb01")
  local fbch = M.get_default_channels(profile, "fb01")
  set("fb01_channels_json", r.JSON_Encode(fbch))
  set("fb01_ch_base", fbch[1] or 1)

  local pssch = M.get_default_channels(profile, "pss580")[1] or 1
  set("pss580_ch", pssch)

  local mfch = M.get_default_channels(profile, "microfreak")[1] or 1
  set("microfreak_ch", mfch)

  local neutron = M.get_default_channels(profile, "neutron")[1] or 1
  set("neutron_ch", neutron)

  local cr = M.get_default_channels(profile, "circuit_rhythm")[1] or 10
  set("circuit_rhythm_ch", cr)

  -- Policy hints
  set("policy_clock_master", "daw")
  set("policy_oxi_role", (M.get_device(profile,"oxi") and (M.get_device(profile,"oxi").clock_role or "slave")) or "slave")
end

function M.get_extstate_defaults()
  local SECTION = "IFLS_WORKBENCH_DEVICES"
  local function get(k, def)
    local v = r.GetExtState(SECTION, k)
    if v == "" then return def end
    return v
  end
  local fb_json = get("fb01_channels_json", "")
  local fbch = nil
  if fb_json ~= "" then
    local ok, t = pcall(function() return r.JSON_Decode(fb_json) end)
    if ok and type(t) == "table" then fbch = t end
  end
  return {
    fb01_channels = fbch,
    fb01_ch_base = tonumber(get("fb01_ch_base", "1")) or 1,
    pss580_ch = tonumber(get("pss580_ch", "1")) or 1,
    microfreak_ch = tonumber(get("microfreak_ch", "1")) or 1,
    neutron_ch = tonumber(get("neutron_ch", "1")) or 1,
    circuit_rhythm_ch = tonumber(get("circuit_rhythm_ch", "10")) or 10
  }
end

return M
