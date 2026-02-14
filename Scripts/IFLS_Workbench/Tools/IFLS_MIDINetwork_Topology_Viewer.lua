-- @description IFLS Workbench - MIDI Network Topology Viewer (V70)
-- @version 0.70.0
-- @author IfeelLikeSnow
local r = reaper

local function wb_root() return r.GetResourcePath().."/Scripts/IFLS_Workbench" end
local function file_exists(p) local f=io.open(p,"rb"); if f then f:close(); return true end return false end
local function read_file(p) local f=io.open(p,"rb"); if not f then return nil end local d=f:read("*all"); f:close(); return d end
local function json_decode(str)
  local ok, j = pcall(function() return r.JSON_Decode(str) end)
  if ok and j then return j end
  local ok2, dk = pcall(require, "dkjson"); if ok2 and dk then return dk.decode(str) end
  return nil
end

local prof_path = wb_root().."/Workbench/MIDINetwork/Data/midinet_profile.json"
if not file_exists(prof_path) then r.MB("Missing profile:\n"..prof_path,"MIDI Topology Viewer",0) return end
local profile = json_decode(read_file(prof_path) or "")
if not profile or not profile.routes then r.MB("Failed to parse profile JSON.","MIDI Topology Viewer",0) return end

if not r.ImGui_CreateContext then
  r.ClearConsole(); r.ShowConsoleMsg("ReaImGui missing. Profile JSON:\n"..(read_file(prof_path) or "").."\n")
  r.MB("ReaImGui not installed. Printed profile JSON to console.", "MIDI Topology Viewer", 0)
  return
end

local function dev_name(id)
  for _,d in ipairs(profile.devices or {}) do if d.id == id then return d.name end end
  return id
end
local function b(x) return x and "✓" or "—" end
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

local ctx = r.ImGui_CreateContext("IFLS MIDI Topology (V70)")
local search=""

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 1120, 620, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS MIDI Topology Viewer (V70)", true)
  if visible then
    r.ImGui_TextWrapped(ctx, "Routes + Clock/SysEx filter policy from midinet_profile.json")
    local chg, s = r.ImGui_InputText(ctx, "Search", search); if chg then search=s end
    r.ImGui_Separator(ctx)

    if r.ImGui_BeginTable(ctx, "routes", 8, r.ImGui_TableFlags_Borders()|r.ImGui_TableFlags_RowBg()|r.ImGui_TableFlags_Resizable()|r.ImGui_TableFlags_ScrollY()) then
      r.ImGui_TableSetupColumn(ctx,"Route")
      r.ImGui_TableSetupColumn(ctx,"From")
      r.ImGui_TableSetupColumn(ctx,"To")
      r.ImGui_TableSetupColumn(ctx,"Clock")
      r.ImGui_TableSetupColumn(ctx,"Transport")
      r.ImGui_TableSetupColumn(ctx,"Notes/CC")
      r.ImGui_TableSetupColumn(ctx,"PC")
      r.ImGui_TableSetupColumn(ctx,"Filters")
      r.ImGui_TableHeadersRow(ctx)

      local q=(search or ""):lower()
      for _,rt in ipairs(profile.routes) do
        local rid=rt.id or ""
        local from=dev_name(rt.from or "")
        local to=dev_name(rt.to or "")
        local flt=filters_to_text(rt.filters)
        local row=(rid.." "..from.." "..to.." "..flt):lower()
        if q=="" or row:find(q,1,true) then
          r.ImGui_TableNextRow(ctx)
          r.ImGui_TableSetColumnIndex(ctx,0); r.ImGui_Text(ctx,rid)
          r.ImGui_TableSetColumnIndex(ctx,1); r.ImGui_Text(ctx,from)
          r.ImGui_TableSetColumnIndex(ctx,2); r.ImGui_Text(ctx,to)
          r.ImGui_TableSetColumnIndex(ctx,3); r.ImGui_Text(ctx,b(rt.clock))
          r.ImGui_TableSetColumnIndex(ctx,4); r.ImGui_Text(ctx,b(rt.transport))
          r.ImGui_TableSetColumnIndex(ctx,5); r.ImGui_Text(ctx,b(rt.notes_cc))
          r.ImGui_TableSetColumnIndex(ctx,6); r.ImGui_Text(ctx,b(rt.pc))
          r.ImGui_TableSetColumnIndex(ctx,7); r.ImGui_TextWrapped(ctx,flt)
        end
      end
      r.ImGui_EndTable(ctx)
    end

    r.ImGui_Separator(ctx)
    r.ImGui_TextWrapped(ctx, "Tip: Run 'IFLS_MIDINetwork_Doctor' for loop/SysEx checks. Export wiring sheet for printing.")
    r.ImGui_End(ctx)
  end
  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
