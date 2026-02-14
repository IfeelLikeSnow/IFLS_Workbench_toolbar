-- @description IFLS PSS-580 - Analyze .SYX file (PSS-x80 voice dumps)
-- @version 1.01.0
-- @author IFLS
local r=reaper
local root = r.GetResourcePath().."/Scripts/IFLS_Workbench"
local Syx = dofile(root.."/Workbench/PSS580/Core/ifls_pss580_sysex.lua")

local function read_all(p)
  local f=io.open(p,"rb"); if not f then return nil end
  local d=f:read("*all"); f:close(); return d
end

local function hex_prefix(msg,n)
  n=n or 16
  local t={}
  for i=1, math.min(#msg,n) do t[#t+1]=string.format("%02X", msg:byte(i)) end
  return table.concat(t," ")
end

local ok, path = r.GetUserFileNameForRead("", "Analyze PSS-x80 .syx", ".syx")
if not ok or path=="" then return end
local blob = read_all(path)
if not blob then r.MB("Cannot read file.", "PSS Analyze", 0); return end

local msgs = Syx.split_sysex(blob)
r.ShowConsoleMsg("=== IFLS PSS-x80 SYX Analyze ===\n")
r.ShowConsoleMsg("File: "..path.."\nBytes: "..#blob.."\nMessages: "..#msgs.."\n\n")
for i,m in ipairs(msgs) do
  local okv = Syx.is_pss_voice_dump(m)
  r.ShowConsoleMsg(string.format("#%d len=%d voice72=%s head=%s\n", i, #m, tostring(okv), hex_prefix(m, 12)))
  if okv then
    local vmem, cs = Syx.unpack_vmem_from_voice_dump(m)
    local cs2 = Syx.checksum_vmem(vmem)
    r.ShowConsoleMsg("  checksum file="..cs.." calc="..cs2.." match="..tostring(cs==cs2).."\n")
  end
end
