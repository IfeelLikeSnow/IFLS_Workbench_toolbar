-- IFLS Status Helpers
-- Version: 0.84.0
--
-- Stores lightweight telemetry in ExtState:
-- Section: IFLS_MIDINET_STATUS
--
-- Keys:
--   autodoctor_running (0/1)
--   autodoctor_heartbeat_utc (epoch)
--   doctor_last_run_utc (epoch)
--   doctor_last_ok (0/1)
--   doctor_last_err (string)
--   wiring_last_run_utc (epoch)
--   portmatcher_last_run_utc (epoch)
--   autodoctor_last_run_utc (epoch)
--   autodoctor_last_ok (0/1)
--   autodoctor_last_err (string)

local r = reaper
local M = {}

M.SECTION = "IFLS_MIDINET_STATUS"

function M.set(key, val, persist)
  r.SetExtState(M.SECTION, key, tostring(val or ""), persist or false)
end

function M.get(key)
  return r.GetExtState(M.SECTION, key)
end

function M.get_num(key)
  return tonumber(M.get(key) or "") or 0
end

function M.get_bool(key)
  return (M.get(key) == "1")
end

function M.touch(key)
  M.set(key, os.time(), false)
end

return M
