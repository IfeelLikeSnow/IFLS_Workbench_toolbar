-- @description IFLS Workbench - Export MIDI Wiring Sheet (MD/HTML) (V70)
-- @version 0.70.0
-- @author IfeelLikeSnow
local r=reaper

local function wb_root() return r.GetResourcePath().."/Scripts/IFLS_Workbench" end
local function file_exists(p) local f=io.open(p,"rb"); if f then f:close(); return true end return false end
local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end local d=f:read("*all"); f:close(); return d end
local function write_file(p,d) local f=io.open(p,"wb"); if not f then return false end f:write(d); f:close(); return true end
local function json_decode(str)
  local ok,j=pcall(function() return r.JSON_Decode(str) end)
  if ok and j then return j end
  local ok2,dk=pcall(require,"dkjson"); if ok2 and dk then return dk.decode(str) end
  return nil
end

local prof_path=wb_root().."/Workbench/MIDINetwork/Data/midinet_profile.json"
if not file_exists(prof_path) then r.MB("Missing profile:\n"..prof_path,"Export Wiring Sheet",0) return end
local profile=json_decode(read_file(prof_path) or "")
if not profile or not profile.devices or not profile.routes then r.MB("Failed to parse profile JSON.","Export Wiring Sheet",0) return end

local function dev_name(id)
  for _,d in ipairs(profile.devices) do if d.id==id then return d.name end end
  return id
end

local function filters_to_text(f)
  if not f then return "" end
  local parts={}
  if f.sysex then parts[#parts+1]="SysEx="..tostring(f.sysex) end
  if f.active_sensing then parts[#parts+1]="AS="..tostring(f.active_sensing) end
  if f.realtime then
    if f.realtime.clock then parts[#parts+1]="Clock="..tostring(f.realtime.clock) end
    if f.realtime.start_stop then parts[#parts+1]="StartStop="..tostring(f.realtime.start_stop) end
  end
  return table.concat(parts,", ")
end

local md={}
md[#md+1]="# MIDI Wiring Sheet"
md[#md+1]=""
md[#md+1]="Source profile: `Workbench/MIDINetwork/Data/midinet_profile.json`"
md[#md+1]=""
md[#md+1]="## Devices"
for _,d in ipairs(profile.devices) do
  md[#md+1]="- **"..(d.name or d.id).."** ("..(d.id or "?")..") | clock_role="..tostring(d.clock_role or "n/a")
end
md[#md+1]=""
md[#md+1]="## Routes"
md[#md+1]=""
md[#md+1]="| Route | From | To | Clock | Transport | Notes/CC | PC | SysEx | Filters |"
md[#md+1]="|---|---|---:|:---:|:---:|:---:|:---:|:---:|---|"
for _,rt in ipairs(profile.routes) do
  local function b(x) return x and "✓" or "—" end
  md[#md+1]=string.format("| %s | %s | %s | %s | %s | %s | %s | %s | %s |",
    rt.id or "",
    dev_name(rt.from or ""),
    dev_name(rt.to or ""),
    b(rt.clock), b(rt.transport), b(rt.notes_cc), b(rt.pc), b(rt.sysex),
    filters_to_text(rt.filters)
  )
end
md[#md+1]=""
md[#md+1]="Print: open HTML file and print to PDF."
md[#md+1]=""

local md_out=wb_root().."/Docs/MIDINetwork_Wiring_Sheet.md"
write_file(md_out, table.concat(md,"\n"))

local html={}
html[#html+1]="<html><head><meta charset=\"utf-8\"><title>MIDI Wiring Sheet</title>"
html[#html+1]="<style>body{font-family:sans-serif;margin:24px} table{border-collapse:collapse;width:100%} td,th{border:1px solid #ccc;padding:6px} th{background:#f3f3f3}</style>"
html[#html+1]="</head><body><h1>MIDI Wiring Sheet</h1>"
html[#html+1]="<p>Source: <code>Workbench/MIDINetwork/Data/midinet_profile.json</code></p>"
html[#html+1]="<h2>Devices</h2><ul>"
for _,d in ipairs(profile.devices) do
  html[#html+1]="<li><b>"..(d.name or d.id).."</b> ("..(d.id or "?")..") - clock_role="..tostring(d.clock_role or "n/a").."</li>"
end
html[#html+1]="</ul><h2>Routes</h2>"
html[#html+1]="<table><tr><th>Route</th><th>From</th><th>To</th><th>Clock</th><th>Transport</th><th>Notes/CC</th><th>PC</th><th>SysEx</th><th>Filters</th></tr>"
for _,rt in ipairs(profile.routes) do
  local function b(x) return x and "✓" or "—" end
  html[#html+1]="<tr><td>"..(rt.id or "").."</td><td>"..dev_name(rt.from or "").."</td><td>"..dev_name(rt.to or "").."</td><td>"..b(rt.clock)..
    "</td><td>"..b(rt.transport).."</td><td>"..b(rt.notes_cc).."</td><td>"..b(rt.pc).."</td><td>"..b(rt.sysex).."</td><td>"..filters_to_text(rt.filters).."</td></tr>"
end
html[#html+1]="</table><p>Print this page to PDF from your browser.</p></body></html>"

local html_out=wb_root().."/Docs/MIDINetwork_Wiring_Sheet.html"
write_file(html_out, table.concat(html,"\n"))
r.CF_ShellExecute(wb_root().."/Docs")
r.MB("Exported:\n- "..md_out.."\n- "..html_out.."\n\nPrint HTML to PDF.","Export Wiring Sheet",0)


-- V82: set latest report pointer (best-effort)
pcall(function()
  local fixed = r.GetResourcePath().."/Scripts/IFLS_Workbench/Docs/MIDINetwork_WiringSheet.md"
  local f=io.open(fixed,"rb")
  if f then f:close(); if RP and RP.set then RP.set("wiring", fixed) end end
end)


-- V83_POINTER_SET
-- Ensure latest pointer is set if wiring report exists.
pcall(function()
  local wb = reaper.GetResourcePath().."/Scripts/IFLS_Workbench"
  local outp = wb.."/Docs/MIDINetwork_WiringSheet.md"
  local f=io.open(outp,"rb")
  if f then f:close()
    local RP=nil
    pcall(function() RP=dofile(wb.."/Workbench/MIDINetwork/Lib/IFLS_ReportPointers.lua") end)
    if RP and RP.set then RP.set("wiring", outp) end
  end
end)


pcall(function() if STATUS and STATUS.set then STATUS.set('wiring_last_run_utc', os.time(), false) end end)


-- V85_DETERMINISTIC_WIRING
-- If the wiring sheet file is missing after run, write a minimal deterministic one.
pcall(function()
  local wb = reaper.GetResourcePath().."/Scripts/IFLS_Workbench"
  local outp = wb.."/Docs/MIDINetwork_WiringSheet.md"
  local f=io.open(outp,"rb")
  if f then f:close(); return end
  local lines={}
  lines[#lines+1]="# MIDINetwork Wiring Sheet"
  lines[#lines+1]=""
  lines[#lines+1]="Generated: "..os.date("!%Y-%m-%dT%H:%M:%SZ")
  lines[#lines+1]=""
  lines[#lines+1]="This file is a deterministic placeholder. If your wiring exporter generates a richer file, it will overwrite this."
  local wf=io.open(outp,"wb")
  if wf then wf:write(table.concat(lines,"\n")); wf:close() end
end)
