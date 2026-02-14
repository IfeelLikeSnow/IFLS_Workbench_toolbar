-- @description IFLS PSS-580 - Library Tag/Favorite (sidecar JSON index)
-- @version 1.04.0
-- @author IFLS
local r=reaper
local root = r.GetResourcePath().."/Scripts/IFLS_Workbench"
local index_path = root.."/Workbench/PSS580/library/pss_library_index.json"

local function read_all(p)
  local f=io.open(p,"rb"); if not f then return nil end
  local d=f:read("*all"); f:close(); return d
end
local function write_all(p, d)
  local f=io.open(p,"wb"); if not f then return false end
  f:write(d); f:close(); return true
end

local function json_decode(s)
  local ok, t = pcall(function() return reaper.JSON_Parse(s) end)
  if ok and t then return t end
  -- fallback minimal decoder for our structure
  local ok2, obj = pcall(function() return load("return "..s:gsub("null","nil"))() end)
  if ok2 then return obj end
  return nil
end

local function json_encode(tbl)
  if reaper.JSON_Stringify then return reaper.JSON_Stringify(tbl) end
  -- simple
  local function esc(str) return (str:gsub("\\","\\\\"):gsub('"','\"')) end
  local items=tbl.items or {}
  local parts={'{"version":"'..esc(tbl.version or "1.0")..'","items":{'}
  local first=true
  for k,v in pairs(items) do
    if not first then parts[#parts+1]="," end
    first=false
    parts[#parts+1]='"'..esc(k)..'":'..string.format('{"type":"%s","character":"%s","favorite":%s}',
      esc(v.type or ""), esc(v.character or ""), (v.favorite and "true" or "false"))
  end
  parts[#parts+1]="}}"
  return table.concat(parts,"")
end

local ok, syx = r.GetUserFileNameForRead("", "Select PSS-x80 voice .syx to tag", ".syx")
if not ok or syx=="" then return end

local raw = read_all(index_path)
local idx = raw and json_decode(raw) or {version="1.0", items={}}
idx.items = idx.items or {}

local cur = idx.items[syx] or {type="", character="", favorite=false}
local ok2, csv = r.GetUserInputs("Tag/Favorite", 3,
  "Type (bd/sd/hh/pad/lead/organ/etc),Character (lofi/bright/noisy/etc),Favorite (0/1)",
  (cur.type or "")..","..(cur.character or "")..","..((cur.favorite and "1") or "0"))
if not ok2 then return end
local t,c,f = csv:match("^([^,]*),([^,]*),([^,]*)$")
cur.type = t or ""
cur.character = c or ""
cur.favorite = (tonumber(f) or 0) == 1
idx.items[syx]=cur

write_all(index_path, json_encode(idx))
r.MB("Saved tags in\n"..index_path, "PSS Library", 0)
