-- @description IFLS Workbench - MIDINetwork REAPER Port Matcher & Validator
-- @version 0.75.0
-- @author IfeelLikeSnow
--
-- Scans REAPER MIDI inputs/outputs and tries to match them against
-- `Workbench/MIDINetwork/Data/midinet_profile.json` device hints:
--   - reaper_out_contains
--   - reaper_in_contains
--
-- Writes a report to `Scripts/IFLS_Workbench/Docs/MIDINetwork_ReaperPortMatch_Report.md`

local r = reaper
local RP=nil
pcall(function() RP=dofile(r.GetResourcePath().."/Scripts/IFLS_Workbench/Workbench/MIDINetwork/Lib/IFLS_ReportPointers.lua") end)


local function wb_root() return r.GetResourcePath().."/Scripts/IFLS_Workbench" end
local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end local d=f:read("*all"); f:close(); return d end
local function write_file(p,d) local f=io.open(p,"wb"); if not f then return false end f:write(d); f:close(); return true end
local function json_decode(str)
  local ok, j = pcall(function() return r.JSON_Decode(str) end)
  if ok and j then return j end
  local ok2, dk = pcall(require, "dkjson")
  if ok2 and dk then return dk.decode(str) end
  return nil
end

local prof_path = wb_root().."/Workbench/MIDINetwork/Data/midinet_profile.json"
local raw = read_file(prof_path)
if not raw then r.MB("Missing profile: "..prof_path, "Port Matcher", 0) return end
local profile = json_decode(raw)
if not profile or not profile.devices then r.MB("Failed to parse profile JSON.", "Port Matcher", 0) return end

local function list_midi_inputs()
  local t={}
  local n = r.GetNumMIDIInputs()
  for i=0,n-1 do
    local ok, name = r.GetMIDIInputName(i, "")
    if ok then t[#t+1]={idx=i,name=name} end
  end
  return t
end

local function list_midi_outputs()
  local t={}
  local n = r.GetNumMIDIOutputs()
  for i=0,n-1 do
    local ok, name = r.GetMIDIOutputName(i, "")
    if ok then t[#t+1]={idx=i,name=name} end
  end
  return t
end

local function find_by_substring(list, needle)
  if not needle or needle=="" then return nil end
  local n = needle:lower()
  for _,it in ipairs(list) do
    if (it.name or ""):lower():find(n, 1, true) then
      return it
    end
  end
  return nil
end

local ins = list_midi_inputs()
local outs = list_midi_outputs()

local lines={}
lines[#lines+1]="# MIDINetwork ↔ REAPER Port Match Report"
lines[#lines+1]=""
lines[#lines+1]="Profile: `Workbench/MIDINetwork/Data/midinet_profile.json`"
lines[#lines+1]=""
lines[#lines+1]="## REAPER MIDI Inputs"
for _,it in ipairs(ins) do lines[#lines+1]=("- [%d] %s"):format(it.idx, it.name) end
lines[#lines+1]=""
lines[#lines+1]="## REAPER MIDI Outputs"
for _,it in ipairs(outs) do lines[#lines+1]=("- [%d] %s"):format(it.idx, it.name) end
lines[#lines+1]=""
lines[#lines+1]="## Device matches (substring strategy)"
lines[#lines+1]=""
lines[#lines+1]="| Device | in_contains | matched IN | out_contains | matched OUT |"
lines[#lines+1]="|---|---|---|---|---|"

local mismatches=0
for _,d in ipairs(profile.devices) do
  local name=d.name or (d.id or "")
  local inc=d.reaper_in_contains or ""
  local outc=d.reaper_out_contains or ""
  local mi=find_by_substring(ins, inc)
  local mo=find_by_substring(outs, outc)
  local mi_s = mi and ("["..mi.idx.."] "..mi.name) or "—"
  local mo_s = mo and ("["..mo.idx.."] "..mo.name) or "—"
  if (inc~="" and not mi) or (outc~="" and not mo) then mismatches=mismatches+1 end
  lines[#lines+1]=("| %s | %s | %s | %s | %s |"):format(name, inc, mi_s, outc, mo_s)
end

lines[#lines+1]=""
if mismatches==0 then
  lines[#lines+1]="✅ All devices with contains-hints matched at least one REAPER port."
else
  lines[#lines+1]="⚠️ Mismatches detected. Fix by editing per-device `reaper_in_contains` / `reaper_out_contains` in the profile."
end
lines[#lines+1]=""
lines[#lines+1]="### Notes"
lines[#lines+1]="- This tool cannot change REAPER MIDI prefs; it only reports matches."
lines[#lines+1]="- For mioXM setups, matching substring `mioXM` is usually sufficient."

local report=table.concat(lines,"\n")
r.ClearConsole(); r.ShowConsoleMsg(report.."\n")

local out_path = wb_root().."/Docs/MIDINetwork_ReaperPortMatch_Report.md"
write_file(out_path, report)
r.MB("Wrote report:\n"..out_path, "Port Matcher", 0)


-- V82: set latest report pointer (best-effort)
pcall(function()
  local fixed = r.GetResourcePath().."/Scripts/IFLS_Workbench/Docs/MIDINetwork_PortMatcher_Report.md"
  local f=io.open(fixed,"rb")
  if f then f:close(); if RP and RP.set then RP.set("portmatcher", fixed) end end
end)


-- V83_DETERMINISTIC_REPORT
-- Writes a deterministic report file and updates latest pointer.

local STATUS=nil
pcall(function() STATUS=dofile(reaper.GetResourcePath().."/Scripts/IFLS_Workbench/Workbench/MIDINetwork/Lib/IFLS_Status.lua") end)

local function wb_root_v83_pm() return reaper.GetResourcePath().."/Scripts/IFLS_Workbench" end
local function write_file_v83_pm(p,d) local f=io.open(p,"wb"); if not f then return false end f:write(d); f:close(); return true end

local function build_report_v83_pm()
  local lines={}
  lines[#lines+1]="# REAPER MIDI Port Matcher Report"
  lines[#lines+1]=""
  lines[#lines+1]="Generated: "..os.date("!%Y-%m-%dT%H:%M:%SZ")
  lines[#lines+1]=""
  lines[#lines+1]="## Inputs"
  lines[#lines+1]="| idx | name |"
  lines[#lines+1]="|---:|---|"
  for i=0,reaper.GetNumMIDIInputs()-1 do
    local ok,name = reaper.GetMIDIInputName(i,"")
    if ok then lines[#lines+1]=("| %d | %s |"):format(i, name) end
  end
  lines[#lines+1]=""
  lines[#lines+1]="## Outputs"
  lines[#lines+1]="| idx | name |"
  lines[#lines+1]="|---:|---|"
  for i=0,reaper.GetNumMIDIOutputs()-1 do
    local ok,name = reaper.GetMIDIOutputName(i,"")
    if ok then lines[#lines+1]=("| %d | %s |"):format(i, name) end
  end
  return table.concat(lines,"\n")
end

pcall(function()
  local outp = wb_root_v83_pm().."/Docs/MIDINetwork_PortMatcher_Report.md"
  write_file_v83_pm(outp, build_report_v83_pm())
  local RP=nil
  pcall(function() RP=dofile(wb_root_v83_pm().."/Workbench/MIDINetwork/Lib/IFLS_ReportPointers.lua") end)
  if RP and RP.set then RP.set("portmatcher", outp) end
end)


pcall(function() if STATUS and STATUS.set then STATUS.set('portmatcher_last_run_utc', os.time(), false) end end)
