-- IFLS Report Pointers
-- Version: 0.82.0
--
-- Stores "latest report" pointers in:
--   Scripts/IFLS_Workbench/Docs/IFLS_LatestReports.json
--
-- Usage:
--   local RP = dofile(wb_root.."/Workbench/MIDINetwork/Lib/IFLS_ReportPointers.lua")
--   RP.set("doctor", abs_path)
--   local p = RP.get("doctor")

local r = reaper
local M = {}

local function wb_root() return r.GetResourcePath().."/Scripts/IFLS_Workbench" end
local function path() return wb_root().."/Docs/IFLS_LatestReports.json" end

local function read_file(p)
  local f=io.open(p,"rb"); if not f then return nil end
  local d=f:read("*all"); f:close(); return d
end
local function write_file(p,d)
  local f=io.open(p,"wb"); if not f then return false end
  f:write(d); f:close(); return true
end

local function decode(s)
  local ok,j = pcall(function() return r.JSON_Decode(s) end)
  if ok and j then return j end
  local ok2, dk = pcall(require,"dkjson")
  if ok2 and dk then return dk.decode(s) end
  return nil
end
local function encode(t)
  local ok,s = pcall(function() return r.JSON_Encode(t) end)
  if ok and s then return s end
  local ok2, dk = pcall(require,"dkjson")
  if ok2 and dk then return dk.encode(t, {indent=true}) end
  return nil
end

local function load_tbl()
  local raw = read_file(path())
  if not raw then return {updated_utc=os.time(), items={}} end
  local t = decode(raw)
  if type(t)~="table" then return {updated_utc=os.time(), items={}} end
  t.items = t.items or {}
  return t
end

function M.set(key, abs_path)
  if not key or key=="" or not abs_path or abs_path=="" then return false end
  local t = load_tbl()
  t.updated_utc = os.time()
  t.items[key] = {path=abs_path, updated_utc=os.time()}
  local enc = encode(t)
  if not enc then return false end
  return write_file(path(), enc)
end

function M.get(key)
  local t = load_tbl()
  local it = t.items and t.items[key]
  if it and it.path and it.path~="" then return it.path end
  return nil
end

function M.file_path()
  return path()
end

return M
