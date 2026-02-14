-- @description IFLS Workbench - Tools/IFLS_Workbench_Validate_Data_JSON.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_Workbench_Validate_Data_JSON.lua
-- V56: Local data validation (best-effort) without external tools.
--
-- Validates presence + minimal structure for:
-- - Workbench Data JSONs referenced by bootstrap (gear.json, patchbay.json)
-- - FB-01 patch manifest (PatchLibrary/Patches/manifest.json)
--
-- If a JSON decoder is available (IFLS json lib or a 'json' module), performs decode.
-- Then runs lightweight schema checks (required keys + types), mirroring the repo schemas.

local r = reaper
local Boot_ok, Boot = pcall(require, "IFLS_Workbench/_bootstrap")
if not Boot_ok then Boot = nil end

local function mb(t) r.MB(tostring(t), "IFLS Validate JSON", 0) end
local function log(t) r.ShowConsoleMsg(tostring(t).."\n") end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*all"); f:close(); return d
end

local function get_json_decoder()
  if Boot and Boot.safe_require then
    local j = Boot.safe_require("IFLS_Workbench/Lib/json") or Boot.safe_require("json")
    if j and j.decode then return j end
  end
  -- no decoder
  return nil
end

local JSON = get_json_decoder()

local strict_mode = (r.GetExtState("IFLS_WORKBENCH_SETTINGS","validator_strict") == "1")

local function load_schema(relpath)
  local base = r.GetResourcePath().."/Scripts"
  local path = base.."/"..relpath
  local t = read_file(path)
  if not t then return nil end
  local obj, err = decode_json(t)
  if not obj then return nil end
  return obj
end

local function validate_required_recursive(schema, obj, path)
  if type(schema) ~= "table" or type(obj) ~= "table" then return true end
  if schema.required and type(schema.required)=="table" then
    for _,k in ipairs(schema.required) do
      if obj[k] == nil then
        return false, (path..": missing required key '"..tostring(k).."'")
      end
    end
  end
  -- descend into properties for objects
  if schema.properties and type(schema.properties)=="table" then
    for k,sub in pairs(schema.properties) do
      if obj[k] ~= nil then
        local ok, err = validate_required_recursive(sub, obj[k], path.."."..tostring(k))
        if not ok then return ok, err end
      end
    end
  end
  -- arrays (items)
  if schema.items and type(obj)=="table" and (#obj>0) then
    -- validate first few items only
    for i=1,math.min(#obj, 5) do
      local ok, err = validate_required_recursive(schema.items, obj[i], path.."["..i.."]")
      if not ok then return ok, err end
    end
  end
  return true
end


local function decode_json(txt)
  if not JSON then return nil, "No JSON decoder module found." end
  local ok, res = pcall(JSON.decode, txt)
  if ok then return res end
  return nil, res
end

local function type_is(v, t) return type(v) == t end

local function check_required(obj, req)
  for _,k in ipairs(req) do
    if obj[k] == nil then return false, "missing key: "..k end
  end
  return true
end

local function validate_patch_manifest(obj)
  local ok, err = check_required(obj, {"generated_utc","count","items"})
  if not ok then return false, err end
  if not type_is(obj.count, "number") then return false, "count must be number" end
  if not type_is(obj.items, "table") then return false, "items must be array/table" end
  return true
end

local function validate_gear(obj)
  if type(obj) ~= "table" then return false, "gear.json must decode to table" end

  local devices = obj.devices or obj
  if type(devices) ~= "table" then return false, "devices array/table not found" end

  -- If it's an array-like table, ensure at least one element or allow empty.
  -- Validate first few entries for common keys when present.
  local checked = 0
  for k,v in pairs(devices) do
    if type(k) == "number" and type(v) == "table" then
      checked = checked + 1
      if v.name == nil and v.model == nil and v.brand == nil then
        -- not fatal: many schemas exist; but warn-like failure because chains depend on identifiers
        return false, "device entry missing any of {name, model, brand}"
      end
      if v.type ~= nil and type(v.type) ~= "string" then
        return false, "device.type must be string when present"
      end
      if checked >= 5 then break end
    end
  end
  return true
end

local function validate_patchbay(obj)
  if type(obj) ~= "table" then return false, "patchbay.json must decode to table" end

  -- Accept either top-level routes/rows or nested.
  local rows = obj.rows or obj.matrix or obj.routes or obj
  if type(rows) ~= "table" then return false, "patchbay rows/matrix not found" end

  -- Validate that there is at least some notion of channels or endpoints if present.
  if obj.legend and type(obj.legend) ~= "table" then
    return false, "legend must be table when present"
  end

  return true
end

local function validate_one(name, path, fn, schema_rel)
  local txt = read_file(path)
  if not txt then return false, "missing file" end
  if not JSON then return false, "no json decoder (install included json module)" end
  local obj, err = decode_json(txt)
  if not obj then return false, "decode failed: "..tostring(err) end
  local ok, e = fn(obj)
  if ok and strict_mode and schema_rel then
    local schema = load_schema(schema_rel)
    if schema then
      local ok2, e2 = validate_required_recursive(schema, obj, name)
      if not ok2 then return false, "schema(required) failed: "..tostring(e2) end
    end
  end
  if ok then return true, "ok" end
  return false, e
end

local data_root = (Boot and Boot.get_data_root and Boot.get_data_root()) or (r.GetResourcePath().."/Scripts/IFLS_Workbench/Data")

local gear_path = data_root .. "/gear.json"
local patchbay_path = data_root .. "/patchbay.json"
local manifest_path = r.GetResourcePath().."/Scripts/IFLS_Workbench/Workbench/FB01/PatchLibrary/Patches/manifest.json"

log("")
log("=== IFLS Validate JSON (V56) ===")
log("data_root: "..data_root)

local results = {}

local ok1, msg1 = validate_one("gear.json", gear_path, validate_gear, "Docs/schemas/ifls_workbench_data.schema.json")
results[#results+1] = {"gear.json", ok1, msg1, gear_path}

local ok2, msg2 = validate_one("patchbay.json", patchbay_path, validate_patchbay, "Docs/schemas/ifls_workbench_data.schema.json")
results[#results+1] = {"patchbay.json", ok2, msg2, patchbay_path}

-- manifest is optional; if missing, just warn
local txtm = read_file(manifest_path)
if not txtm then
  results[#results+1] = {"fb01 manifest", false, "missing (optional)", manifest_path}
else
  local obj, err = decode_json(txtm)
  if not obj then
    results[#results+1] = {"fb01 manifest", false, "decode failed: "..tostring(err), manifest_path}
  else
    local okm, em = validate_patch_manifest(obj)
    results[#results+1] = {"fb01 manifest", okm, okm and "ok" or em, manifest_path}
  end
end

for _,r0 in ipairs(results) do
  log(string.format("%-14s  %s  %s", r0[1], r0[2] and "OK" or "FAIL", r0[3]))
end

local fails = {}
for _,r0 in ipairs(results) do
  if not r0[2] and r0[3] ~= "missing (optional)" then
    fails[#fails+1] = r0[1]..": "..r0[3]
  end
end

if #fails == 0 then
  mb("Validation OK.\n\nSee console for details.")
else
  mb("Validation FAILED:\n- "..table.concat(fails, "\n- ").."\n\nSee console for details.")
end
