-- @description IFLS Workbench - Tools/IFLS_Workbench_SelfTest.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_Workbench_SelfTest.lua
-- V53: Offline self-tests for IFLS Workbench (no hardware needed).
--
-- Tests:
-- - bootstrap loads
-- - JSON data files exist and parse (best effort)
-- - routing engine module loads
-- - safeapply module loads
--
-- Output: REAPER Console + summary dialog.

local r = reaper

local function msg(s) r.ShowConsoleMsg(tostring(s).."\n") end
local function ok(b) return b and "OK" or "FAIL" end

r.ShowConsoleMsg("")
msg("=== IFLS Workbench SelfTest (V53) ===")

local pass_all = true
local failures = {}

local function require_or_fail(mod)
  local okk, res = pcall(require, mod)
  if okk then return res end
  pass_all = false
  failures[#failures+1] = "require("..mod..") -> "..tostring(res)
  return nil
end

local Boot = require_or_fail("IFLS_Workbench/_bootstrap")
local SafeApply = require_or_fail("IFLS_Workbench/Engine/IFLS_SafeApply")
local Routing = require_or_fail("IFLS_Workbench/Engine/IFLS_Patchbay_RoutingEngine")

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*all"); f:close(); return d
end

local function try_json_decode(txt)
  local j = nil
  if Boot then
    j = Boot.safe_require("IFLS_Workbench/Lib/json") or Boot.safe_require("json")
  end
  if j and j.decode then
    local okk, res = pcall(j.decode, txt)
    if okk then return true, res end
    return false, res
  end
  -- minimal fallback: only checks it looks like JSON
  txt = (txt or ""):gsub("%s+","")
  if txt:sub(1,1) == "{" or txt:sub(1,1) == "[" then
    return true, nil
  end
  return false, "No JSON decoder found and file doesn't look like JSON."
end

local function test_json(name, path)
  local d = read_file(path)
  if not d then
    pass_all = false
    failures[#failures+1] = name..": missing file at "..path
    msg(name..": "..ok(false).." (missing)")
    return
  end
  local okk, res = try_json_decode(d)
  msg(name..": "..ok(okk).." ("..tostring(path)..")")
  if not okk then
    pass_all = false
    failures[#failures+1] = name..": JSON parse failed -> "..tostring(res)
  end
end

if Boot then
  msg("Bootstrap: "..ok(true).." data_root="..tostring(Boot.get_data_root()))
  test_json("gear.json", Boot.data_path("gear.json"))
  test_json("patchbay.json", Boot.data_path("patchbay.json"))
else
  msg("Bootstrap: "..ok(false))
end

msg("SafeApply module: "..ok(SafeApply ~= nil))
msg("RoutingEngine module: "..ok(Routing ~= nil))
msg("Tip: Run IFLS_Workbench_Validate_Data_JSON.lua for deeper local JSON checks.")
msg("=== end ===")

local summary
if pass_all then
  summary = "SelfTest passed."
else
  summary = "SelfTest FAILED:\n- "..table.concat(failures, "\n- ")
end

r.MB(summary.."\n\nSee REAPER Console for details.", "IFLS Workbench SelfTest", 0)
