-- @description IFLS Workbench - Apply REAPER MIDI Port Names (exact) + write device port indexes (ExtState)
-- @version 0.80.0
-- @author IfeelLikeSnow
--
-- Reads MIDINetwork profile, matches REAPER ports, then:
-- 1) Writes `reaper_in_exact` / `reaper_out_exact` into midinet_profile.json (if uniquely matched)
-- 2) Writes port indexes into ExtState section `IFLS_WORKBENCH_DEVICES`:
--    - <device_id>_midi_in_idx
--    - <device_id>_midi_out_idx
--
-- Safe behavior:
-- - Only writes exact names when contains-match is UNIQUE.
-- - Never overwrites non-empty exact names unless user confirms.

local r = reaper
local SECTION = "IFLS_WORKBENCH_DEVICES"

local function wb_root() return r.GetResourcePath().."/Scripts/IFLS_Workbench" end

local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end local d=f:read("*all"); f:close(); return d end
local function write_file(p,d) local f=io.open(p,"wb"); if not f then return false end f:write(d); f:close(); return true end
local function json_decode(str)
  local ok,j = pcall(function() return r.JSON_Decode(str) end)
  if ok and j then return j end
  local ok2, dk = pcall(require,"dkjson")
  if ok2 and dk then return dk.decode(str) end
  return nil
end
local function json_encode(tbl)
  local ok,s = pcall(function() return r.JSON_Encode(tbl) end)
  if ok and s then return s end
  local ok2, dk = pcall(require,"dkjson")
  if ok2 and dk then return dk.encode(tbl, {indent=true}) end
  return nil
end

local resolver_path = wb_root().."/Workbench/MIDINetwork/Lib/IFLS_ReaperPortResolver.lua"
local RP=nil
pcall(function() RP=dofile(wb_root().."/Workbench/MIDINetwork/Lib/IFLS_ReportPointers.lua") end)
local ok_res, R = pcall(dofile, resolver_path)
if not ok_res or not R then
  r.MB("Failed to load resolver lib:\n"..tostring(R), "Apply Port Names", 0)
  return
end

local prof_path = wb_root().."/Workbench/MIDINetwork/Data/midinet_profile.json"
local raw = read_file(prof_path)
if not raw then r.MB("Missing profile:\n"..prof_path, "Apply Port Names", 0) return end
local profile = json_decode(raw)
if not profile or not profile.devices then r.MB("Failed to parse profile json.", "Apply Port Names", 0) return end

local overwrite = (r.MB("Overwrite non-empty exact names if found?\n\nYes = overwrite\nNo = keep existing exact strings", "Apply Port Names", 4) == 6)

local lines={}
lines[#lines+1]="# Apply REAPER Port Names + Indexes"
lines[#lines+1]=""
lines[#lines+1]="Profile: `Workbench/MIDINetwork/Data/midinet_profile.json`"
lines[#lines+1]=""
lines[#lines+1]="| Device | in_exact(before→after) | in_match | out_exact(before→after) | out_match | out_idx |"
lines[#lines+1]="|---|---|---|---|---:|---:|"

local changed=false

for _,d in ipairs(profile.devices) do
  local id=d.id or ""
  if id=="" then goto continue end

  local in_exact_before = d.reaper_in_exact or ""
  local out_exact_before = d.reaper_out_exact or ""
  local in_contains = d.reaper_in_contains or ""
  local out_contains = d.reaper_out_contains or ""

  local in_hit,in_mode,in_count = R.match_input(in_exact_before, in_contains)
  local out_hit,out_mode,out_count = R.match_output(out_exact_before, out_contains)

  if in_hit then r.SetExtState(SECTION, id.."_midi_in_idx", tostring(in_hit.idx), true) end
  if out_hit then r.SetExtState(SECTION, id.."_midi_out_idx", tostring(out_hit.idx), true) end

  local in_after = in_exact_before
  local out_after = out_exact_before

  if in_hit and (in_mode=="exact" or in_count==1) then
    if overwrite or in_exact_before=="" then
      in_after = in_hit.name
      if in_after ~= in_exact_before then d.reaper_in_exact=in_after; changed=true end
    end
  end

  if out_hit and (out_mode=="exact" or out_count==1) then
    if overwrite or out_exact_before=="" then
      out_after = out_hit.name
      if out_after ~= out_exact_before then d.reaper_out_exact=out_after; changed=true end
    end
  end

  local out_idx = out_hit and out_hit.idx or ""
  lines[#lines+1]=("| %s | %s→%s | %s(%d) | %s→%s | %s(%d) | %s |"):format(
    id,
    in_exact_before, in_after, in_mode, in_count,
    out_exact_before, out_after, out_mode, out_count,
    tostring(out_idx)
  )

  ::continue::
end

local report = table.concat(lines,"\n")
r.ClearConsole(); r.ShowConsoleMsg(report.."\n")

local out_report = wb_root().."/Docs/MIDINetwork_ApplyPorts_Report.md"
write_file(out_report, report)
if RP and RP.set then RP.set("apply_ports", out_report) end

if changed then
  local encoded = json_encode(profile)
  if not encoded then
    r.MB("Matched ports but failed to encode JSON. Report written:\n"..out_report, "Apply Port Names", 0)
    return
  end
  if not write_file(prof_path, encoded) then
    r.MB("Failed to write profile. Report written:\n"..out_report, "Apply Port Names", 0)
    return
  end
  r.MB("Updated profile with exact port names (where safe) and wrote ExtState port indexes.\n\nReport:\n"..out_report, "Apply Port Names", 0)
else
  r.MB("No profile changes were needed. ExtState indexes may still have been updated.\n\nReport:\n"..out_report, "Apply Port Names", 0)
end
