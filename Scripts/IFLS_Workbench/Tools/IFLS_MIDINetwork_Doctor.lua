-- @description IFLS Workbench - MIDI Network Doctor (V70)
-- @version 0.70.0
-- @author IfeelLikeSnow
local r = reaper
local RP=nil
pcall(function() RP=dofile(r.GetResourcePath().."/Scripts/IFLS_Workbench/Workbench/MIDINetwork/Lib/IFLS_ReportPointers.lua") end)


local function wb_root() return r.GetResourcePath().."/Scripts/IFLS_Workbench" end
local function file_exists(p) local f=io.open(p,"rb"); if f then f:close(); return true end return false end
local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end local d=f:read("*all"); f:close(); return d end
local function write_file(p, d) local f=io.open(p,"wb"); if not f then return false end f:write(d); f:close(); return true end
local function json_decode(str)
  local ok, j = pcall(function() return r.JSON_Decode(str) end)
  if ok and j then return j end
  local ok2, dk = pcall(require,"dkjson"); if ok2 and dk then return dk.decode(str) end
  return nil
end

local prof_path = wb_root().."/Workbench/MIDINetwork/Data/midinet_profile.json"
if not file_exists(prof_path) then r.MB("Missing profile:\n"..prof_path,"MIDI Network Doctor",0) return end
local profile = json_decode(read_file(prof_path) or "")
if not profile or not profile.devices or not profile.routes then r.MB("Failed to parse profile JSON.","MIDI Network Doctor",0) return end


-- V75: REAPER port-matching hints (optional)
local function count_port_hints()
  local needed = { "microfreak", "pss580", "fb01", "edge", "neutron" }
  local missing = {}
  local byid = {}
  for _,d in ipairs(profile.devices or {}) do byid[d.id]=d end
  for _,id in ipairs(needed) do
    local d = byid[id]
    if d and ((d.reaper_in_contains==nil or d.reaper_in_contains=="") and (d.reaper_out_contains==nil or d.reaper_out_contains=="")) then
      missing[#missing+1]=id
    end
  end
  return missing
end
local missing_hints = count_port_hints()
if #missing_hints > 0 then
  add("LOW","Missing REAPER port matching hints (reaper_in_contains/reaper_out_contains) for: "..table.concat(missing_hints,", ")..". Run IFLS_MIDINetwork_ReaperPortMatcher after setting hints.", "")
end

local function dev_by_id(id) for _,d in ipairs(profile.devices) do if d.id==id then return d end end return nil end

local findings={}
local function add(sev,msg,route) findings[#findings+1]={sev=sev,msg=msg,route=route or ""} end

-- clock masters
local masters={}
for _,d in ipairs(profile.devices) do if d.clock_role=="master" then masters[#masters+1]=d.id end end
if #masters==0 then add("HIGH","No clock master defined. Recommended: DAW = master.","")
elseif #masters>1 then add("HIGH","Multiple clock masters: "..table.concat(masters,", ")..". Recommended: only DAW.","") end

local oxi=dev_by_id("oxi")
local oxi_is_slave = oxi and (oxi.clock_role=="slave")

for _,rt in ipairs(profile.routes) do
  local rid=rt.id or ""
  local from=rt.from or ""
  local to=rt.to or ""
  local flt=rt.filters or {}
  local rtflt=flt.realtime or {}

  if from=="oxi" and rt.clock then
    if oxi_is_slave then add("HIGH","OXI->* route sends CLOCK while OXI is SLAVE. Block clock on OXI->devices.",rid)
    else add("MED","OXI->* route sends CLOCK. Ensure OXI intended as master.",rid) end
  end

  if from=="oxi" then
    if rtflt.clock~="block" then add("MED","OXI->device missing realtime.clock=block (recommended).",rid) end
    if rtflt.start_stop~="block" then add("LOW","OXI->device missing realtime.start_stop=block (recommended).",rid) end
    if rt.sysex then add("MED","Avoid SysEx from OXI unless required.",rid) end
  end

  if rt.sysex then
    local sy=flt.sysex
    local s=tostring(sy or "")
    if s=="" or (s:lower():find("allow_only",1,true)==nil and s:lower()~="allow") then
      add("MED","SysEx route should be restrictive (allow_only_to_target).",rid)
    end
    if rt.clock or rt.transport then add("LOW","Prefer SysEx-only route (no clock/transport).",rid) end
  end

  if from=="daw" and to=="oxi" then
    if not rt.clock then add("MED","DAW->OXI should carry clock (DAW master).",rid) end
    if not rt.transport then add("LOW","DAW->OXI should carry transport if desired.",rid) end
    if rt.sysex then add("LOW","DAW->OXI should generally block SysEx.",rid) end
  end
end

table.sort(findings,function(a,b)
  local o={HIGH=1,MED=2,LOW=3}; return (o[a.sev] or 9)<(o[b.sev] or 9)
end)

local lines={}
lines[#lines+1]="# MIDI Network Doctor Report (V70)"
lines[#lines+1]=""
lines[#lines+1]="Profile: `Workbench/MIDINetwork/Data/midinet_profile.json`"
lines[#lines+1]=""
lines[#lines+1]="## Findings"
lines[#lines+1]=""
if #findings==0 then
  lines[#lines+1]="- ✅ No issues detected by heuristic checks."
else
  for _,f in ipairs(findings) do
    local where = (f.route~="" and (" (route: "..f.route..")") or "")
    lines[#lines+1]="- **"..f.sev.."**: "..f.msg..where
  end
end
lines[#lines+1]=""
lines[#lines+1]="## Baseline policy"
lines[#lines+1]="- DAW = only clock master"
lines[#lines+1]="- OXI = clock slave, do not forward clock/start/stop to devices unless required"
lines[#lines+1]="- SysEx only on dedicated routes to the target device"
lines[#lines+1]=""

local report=table.concat(lines,"\n")
r.ClearConsole(); r.ShowConsoleMsg(report.."\n")
local out_path=wb_root().."/Docs/MIDINetwork_Doctor_Report.md"
write_file(out_path, report)
r.MB("Doctor report written to:\n"..out_path.."\n\nAlso printed to console.","MIDI Network Doctor",0)


-- V82: Offer fix for missing exact port names / missing defaults
pcall(function()
  local wb = r.GetResourcePath().."/Scripts/IFLS_Workbench"
  local prof = wb.."/Workbench/MIDINetwork/Data/midinet_profile.json"
  local raw=nil; local f=io.open(prof,'rb'); if f then raw=f:read('*all'); f:close() end
  if not raw then return end
  local ok,j = pcall(function() return r.JSON_Decode(raw) end)
  if not ok or type(j)~='table' or type(j.devices)~='table' then return end
  local missing=0
  for _,d in ipairs(j.devices) do
    if d and d.id and (d.reaper_out_contains or d.reaper_in_contains) then
      local ex_in = d.reaper_in_exact or ''
      local ex_out = d.reaper_out_exact or ''
      if ex_in=='' or ex_out=='' then missing = missing + 1 end
    end
  end
  if missing > 0 then
    local ret = r.MB('Doctor note: '..missing..' device(s) have missing reaper_*_exact names.\n\nFix: set profile port names now?\n(runs: Apply REAPER Port Names + Indexes)', 'MIDINetwork Doctor', 4)
    if ret == 6 then
      local p = wb..'/Tools/IFLS_MIDINetwork_Apply_ReaperPortNames_And_Indexes.lua'
      pcall(dofile, p)
    end
  end
end)

-- V82: set doctor report pointer (best-effort)
pcall(function()
  local fixed = r.GetResourcePath().."/Scripts/IFLS_Workbench/Docs/MIDINetwork_Doctor_Report.md"
  local f=io.open(fixed,'rb')
  if f then f:close(); if RP and RP.set then RP.set('doctor', fixed) end end
end)


-- V83_ENHANCED_FIX_FLOW
-- Adds:
-- - deterministic doctor report path
-- - fix prompt for missing reaper_*_exact
-- - optional auto-run of ApplyPorts tool and re-run doctor

local STATUS=nil
pcall(function() STATUS=dofile(reaper.GetResourcePath().."/Scripts/IFLS_Workbench/Workbench/MIDINetwork/Lib/IFLS_Status.lua") end)

local function wb_root_v83()
  return reaper.GetResourcePath().."/Scripts/IFLS_Workbench"
end

local function read_file_v83(p)
  local f=io.open(p,"rb"); if not f then return nil end
  local d=f:read("*all"); f:close(); return d
end

local function write_file_v83(p,d)
  local f=io.open(p,"wb"); if not f then return false end
  f:write(d); f:close(); return true
end

local function json_decode_v83(s)
  local ok,j = pcall(function() return reaper.JSON_Decode(s) end)
  if ok and j then return j end
  local ok2, dk = pcall(require,"dkjson")
  if ok2 and dk then return dk.decode(s) end
  return nil
end

local function list_missing_exact_v83(profile)
  local miss={}
  if type(profile)~="table" or type(profile.devices)~="table" then return miss end
  for _,d in ipairs(profile.devices) do
    local id=d.id or ""
    local in_contains=d.reaper_in_contains or ""
    local out_contains=d.reaper_out_contains or ""
    local in_exact=d.reaper_in_exact or ""
    local out_exact=d.reaper_out_exact or ""
    -- Only care if contains exists but exact is empty (so we can upgrade)
    if id~="" then
      local need_in = (in_contains~="" and in_exact=="")
      local need_out = (out_contains~="" and out_exact=="")
      if need_in or need_out then
        miss[#miss+1] = {id=id, need_in=need_in, need_out=need_out, in_contains=in_contains, out_contains=out_contains}
      end
    end
  end
  return miss
end

local function run_applyports_v83()
  local p = wb_root_v83().."/Tools/IFLS_MIDINetwork_Apply_ReaperPortNames_And_Indexes.lua"
  local f=io.open(p,"rb")
  if not f then
    reaper.MB("Missing Apply tool:\n"..p, "Doctor Fix", 0)
    return false
  end
  f:close()
  local ok,err = pcall(dofile, p)
  if not ok then
    reaper.MB("Apply tool failed:\n"..tostring(err), "Doctor Fix", 0)
    return false
  end
  return true
end

local function set_doctor_report_pointer_v83(abs_report)
  local RP=nil
  pcall(function()
    RP=dofile(wb_root_v83().."/Workbench/MIDINetwork/Lib/IFLS_ReportPointers.lua")
  end)
  if RP and RP.set then
    RP.set("doctor", abs_report)
  end
end

local function write_doctor_summary_report_v83(missing)
  local outp = wb_root_v83().."/Docs/MIDINetwork_Doctor_Report.md"
  local lines={}
  lines[#lines+1]="# MIDINetwork Doctor Report"
  lines[#lines+1]=""
  lines[#lines+1]="Generated: "..os.date("!%Y-%m-%dT%H:%M:%SZ")
  lines[#lines+1]=""
  if #missing==0 then
    lines[#lines+1]="✅ No missing `reaper_*_exact` fields detected (for devices with contains hints)."
  else
    lines[#lines+1]="⚠️ Missing `reaper_*_exact` fields detected (upgrade recommended)."
    lines[#lines+1]=""
    lines[#lines+1]="| device | need_in_exact | need_out_exact | in_contains | out_contains |"
    lines[#lines+1]="|---|---:|---:|---|---|"
    for _,m in ipairs(missing) do
      lines[#lines+1]=("| %s | %s | %s | %s | %s |"):format(
        m.id,
        m.need_in and "yes" or "no",
        m.need_out and "yes" or "no",
        m.in_contains or "",
        m.out_contains or ""
      )
    end
    lines[#lines+1]=""
    lines[#lines+1]="## Fix"
    lines[#lines+1]="Run: `Tools/IFLS_MIDINetwork_Apply_ReaperPortNames_And_Indexes.lua`"
  end
  write_file_v83(outp, table.concat(lines,"\n"))
  set_doctor_report_pointer_v83(outp)
  return outp
end

local function doctor_fix_flow_v83()
  local profp = wb_root_v83().."/Workbench/MIDINetwork/Data/midinet_profile.json"
  local raw = read_file_v83(profp)
  if not raw then return end
  local prof = json_decode_v83(raw)
  if not prof then return end
  local missing = list_missing_exact_v83(prof)
  local report_path = write_doctor_summary_report_v83(missing)
  -- If missing exists, offer fix
  if #missing > 0 then
    local msg = "Doctor found devices missing stable REAPER port names (reaper_*_exact).\n\n"..
                "Fix now by running:\nApply REAPER Port Names + Indexes\n\n"..
                "This will also write ExtState port indexes for device tools.\n\n"..
                "After applying, Doctor will re-run.\n\nProceed?"
    if reaper.MB(msg, "MIDINetwork Doctor", 4) == 6 then
      if run_applyports_v83() then
        reaper.MB("ApplyPorts finished. Re-running Doctor now.", "MIDINetwork Doctor", 0)
        -- Re-run doctor script (this file)
        pcall(function() dofile(reaper.GetResourcePath().."/Scripts/IFLS_Workbench/Tools/IFLS_MIDINetwork_Doctor.lua") end)
      end
    else
      reaper.MB("No changes applied. Report written:\n"..report_path, "MIDINetwork Doctor", 0)
    end
  end
end

-- Run fix flow after normal Doctor run
pcall(doctor_fix_flow_v83)


-- V84_TELEMETRY
pcall(function()
  if STATUS and STATUS.set then
    STATUS.set('doctor_last_run_utc', os.time(), false)
    STATUS.set('doctor_last_ok', '1', false)
    STATUS.set('doctor_last_err', '', false)
  end
end)


-- V85_TELEMETRY_RICH
-- Mark doctor_last_ok=0 if missing exact fields exist, otherwise ok=1.
pcall(function()
  local STATUS=nil
  pcall(function() STATUS=dofile(reaper.GetResourcePath().."/Scripts/IFLS_Workbench/Workbench/MIDINetwork/Lib/IFLS_Status.lua") end)
  if not STATUS or not STATUS.set then return end

  -- parse latest doctor report summary quickly (missing table is computed in doctor_fix_flow_v83)
  local wb = reaper.GetResourcePath().."/Scripts/IFLS_Workbench"
  local profp = wb.."/Workbench/MIDINetwork/Data/midinet_profile.json"
  local f=io.open(profp,"rb"); if not f then return end
  local raw=f:read("*all"); f:close()
  local ok,j = pcall(function() return reaper.JSON_Decode(raw) end)
  if not ok or type(j)~="table" or type(j.devices)~="table" then return end
  local missing=0
  for _,d in ipairs(j.devices) do
    local in_contains=d.reaper_in_contains or ""
    local out_contains=d.reaper_out_contains or ""
    local in_exact=d.reaper_in_exact or ""
    local out_exact=d.reaper_out_exact or ""
    if (in_contains~="" and in_exact=="") or (out_contains~="" and out_exact=="") then
      missing = missing + 1
    end
  end

  STATUS.set("doctor_last_run_utc", os.time(), false)
  if missing > 0 then
    STATUS.set("doctor_last_ok", "0", false)
    STATUS.set("doctor_last_err", "Missing reaper_*_exact for "..tostring(missing).." device(s) (run ApplyPorts)", false)
  else
    STATUS.set("doctor_last_ok", "1", false)
    STATUS.set("doctor_last_err", "", false)
  end
end)
