-- @description IFLS Workbench - Hub (Smart UX: dependencies + status + quick actions)
-- @version 0.112.0
-- @author IfeelLikeSnow
--
-- Smart launcher window:
-- - Shows dependency status (ReaImGui / SWS)
-- - Disables buttons when dependencies are missing
-- - Quick actions: open docs, run doctor, run port matcher, export wiring

local r = reaper
local RP=nil
local STATUS=nil
pcall(function() STATUS=dofile(r.GetResourcePath().."/Scripts/IFLS_Workbench/Workbench/MIDINetwork/Lib/IFLS_Status.lua") end)

pcall(function() RP=dofile(r.GetResourcePath().."/Scripts/IFLS_Workbench/Workbench/MIDINetwork/Lib/IFLS_ReportPointers.lua") end)


local function wb_root()
  return r.GetResourcePath().."/Scripts/IFLS_Workbench"
end

local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

local function run_script(relpath)
  local p = wb_root().."/"..relpath
  if not file_exists(p) then
    r.MB("Missing script:\n"..p, "IFLS Hub", 0)
    return false
  end
  local ok, err = pcall(dofile, p)
  if not ok then
    r.MB("Failed to run:\n"..relpath.."\n\n"..tostring(err), "IFLS Hub", 0)
    return false
  end
  return true
end

local function has_reaimgui()
  return r.ImGui_CreateContext ~= nil
end

local function has_sws()
  -- we use CF_ShellExecute as an indicator; many other CF_ functions exist
  return r.CF_ShellExecute ~= nil
end

local function fmt_epoch(ts)
  if not ts or ts<=0 then return '(unknown)' end
  return os.date('!%Y-%m-%d %H:%M:%SZ', ts)
end

local function get_status()
  local sec = "IFLS_MIDINET_STATUS"
  local running = r.GetExtState(sec, "autodoctor_running") == "1"
  local hb = tonumber(r.GetExtState(sec, "autodoctor_heartbeat_utc") or "") or 0
  return running, hb
end

local function open_report(key, fallback_rel)
  if not has_sws() then
    r.MB("SWS is required to open files.\n(You can still open manually from Docs.)", "IFLS Hub", 0)
    return
  end
  local p = RP and RP.get and RP.get(key) or nil
  if (not p or p=="") and fallback_rel then
    p = wb_root().."/"..fallback_rel
  end
  local f = p and io.open(p, "rb") or nil
  if f then f:close(); r.CF_ShellExecute(p); return end
  r.MB("Report not found.\nGenerate it first, or check Docs.\n\nExpected: "..tostring(p), "IFLS Hub", 0)
end

local function dep_badge(ok, name)
  return (ok and "✅ " or "❌ ")..name
end

-- Launch items: {label, relpath, requires={reaimgui=true, sws=false}, note="..."}
local LAUNCH = {
  MIDI = {
    {"Topology Viewer", "Tools/IFLS_MIDINetwork_Topology_Viewer.lua", {reaimgui=true}, "Visual routing graph"},
    {"Run Doctor", "Tools/IFLS_MIDINetwork_Doctor.lua", {reaimgui=false}, "Checks profile consistency"},
    {"AutoDoctor Service", "Tools/IFLS_MIDINetwork_AutoDoctor_Service.lua", {reaimgui=false}, "Background watcher"},
    {"AutoDoctor Toggle", "Tools/IFLS_MIDINetwork_AutoDoctor_Toggle.lua", {reaimgui=false}, "Enable/disable service"},
    {"Apply Device Defaults", "Tools/IFLS_MIDINetwork_Apply_DeviceDefaults.lua", {reaimgui=false}, "Writes ExtState defaults"},
    {"REAPER Port Matcher", "Tools/IFLS_MIDINetwork_ReaperPortMatcher.lua", {reaimgui=false}, "Generates port match report"},
    {"Apply REAPER Port Names + Indexes", "Tools/IFLS_MIDINetwork_Apply_ReaperPortNames_And_Indexes.lua", {reaimgui=false}, "Writes exact port names into profile + ExtState port indexes"},
    {"Export Wiring Sheet", "Tools/IFLS_MIDINetwork_Export_WiringSheet.lua", {reaimgui=false}, "Exports markdown/html/pdf"},
  },
  DEVICES = {
    {"Create Synth Audio-In Tracks", "Tools/IFLS_Workbench_Synth_InputTrack_Wizard.lua", {reaimgui=true}, "Creates audio input tracks + buses (no duplicates)"},
    {"Reamp Print Toggle (from FXBUS)", "Tools/IFLS_Workbench_Reamp_Print_Toggle_From_FXBus.lua", {reaimgui=false}, "Creates/toggles REAMP print routing from FXBUS"},
    {"MicroFreak Library Browser", "Workbench/MicroFreak/IFLS_MicroFreak_LibraryBrowser.lua", {reaimgui=true}, ""},
    {"MicroFreak Recall (Project)", "Workbench/MicroFreak/IFLS_MicroFreak_ProjectRecall.lua", {reaimgui=true}, ""},
    {"PSS-580 Library Browser", "PSS580/IFLS_PSS580_LibraryBrowser.lua", {reaimgui=true}, ""},
    {"PSS-580 Project Recall", "PSS580/IFLS_PSS580_ProjectRecall.lua", {reaimgui=true}, ""},
    {"FB-01 Toolkit (current)", "Workbench/FB01/Current/IFLS_FB01_Toolkit_Current.lua", {reaimgui=true}, ""},
  },
  PATCHBAY = {
    {"Patchbay Viewer", "Tools/IFLS_Patchbay_Viewer.lua", {reaimgui=true}, ""},
    {"External Insert Wizard", "Tools/IFLS_External_Insert_Wizard.lua", {reaimgui=true}, ""},
    {"Recall Apply", "Tools/IFLS_Patchbay_Recall_Apply.lua", {reaimgui=true}, ""},
    {"Conflict View", "Tools/IFLS_Patchbay_Conflict_View.lua", {reaimgui=true}, ""},
  },
  FIELDREC_IDM = {
    {"Fieldrec IDM Template (VST)", "Tools/IFLS_Fieldrec_IDM_Template_Generator.lua", {reaimgui=false}, "Track templates + FX chains"},
    {"SmartSlice (items)", "Slicing/IFLS_SmartSlicer.lua", {reaimgui=false}, ""},
    {"RS5K Rack from Selected Items", "Slicing/IFLS_RS5K_Rack_From_Items.lua", {reaimgui=false}, ""},
  }
}

local reaimgui_ok = has_reaimgui()
local sws_ok = has_sws()

if not reaimgui_ok then
  r.ClearConsole()
  r.ShowConsoleMsg("ReaImGui missing. IFLS Hub launch list (no UI):\n\n")
  for group, items in pairs(LAUNCH) do
    r.ShowConsoleMsg("["..group.."]\n")
    for _,it in ipairs(items) do
      r.ShowConsoleMsg(" - "..it[1].." -> "..it[2].."\n")
    end
    r.ShowConsoleMsg("\n")
  end
  r.MB("ReaImGui is not installed. Printed launch list to console.\nInstall ReaImGui to use the Smart Hub UI.", "IFLS Hub", 0)
  return
end

local ctx = r.ImGui_CreateContext("IFLS Workbench Hub")
local search = ""
local show_paths = true

local function begin_disabled(disabled)
  if disabled then r.ImGui_BeginDisabled(ctx) end
end
local function end_disabled(disabled)
  if disabled then r.ImGui_EndDisabled(ctx) end
end
local function tooltip(text)
  if text and text ~= "" and r.ImGui_IsItemHovered(ctx) then
    r.ImGui_BeginTooltip(ctx)
    r.ImGui_TextWrapped(ctx, text)
    r.ImGui_EndTooltip(ctx)
  end
end

local function deps_ok(req)
  if not req then return true end
  if req.reaimgui and not reaimgui_ok then return false end
  if req.sws and not sws_ok then return false end
  return true
end

local function draw_group(title, items)
  if r.ImGui_CollapsingHeader(ctx, title, r.ImGui_TreeNodeFlags_DefaultOpen()) then
    for _,it in ipairs(items) do
      local label, rel, req, note = it[1], it[2], it[3] or {}, it[4] or ""
      if search ~= "" then
        local s = search:lower()
        local hay = (label.." "..rel):lower()
        if not hay:find(s, 1, true) then
          goto continue
        end
      end
      local ok = deps_ok(req)
      begin_disabled(not ok)
      if r.ImGui_Button(ctx, label, -1, 0) then
        run_script(rel)
      end
      end_disabled(not ok)

      tooltip(note ~= "" and note or nil)

      if show_paths then
        r.ImGui_SameLine(ctx)
        r.ImGui_TextDisabled(ctx, rel)
      end

      if not ok then
        r.ImGui_SameLine(ctx)
        local need = {}
        if req.reaimgui and not reaimgui_ok then need[#need+1] = "ReaImGui" end
        if req.sws and not sws_ok then need[#need+1] = "SWS" end
        r.ImGui_SameLine(ctx)
        r.ImGui_TextColored(ctx, 1, 0.5, 0.2, 1, "needs: "..table.concat(need,", "))
      end
      ::continue::
    end
  end
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 980, 720, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS Workbench Hub (V79)", true)
  if visible then
    r.ImGui_TextWrapped(ctx, "Smart launcher for IFLS Workbench. Dependencies and quick actions shown below.")
    r.ImGui_Separator(ctx)

    r.ImGui_Text(ctx, "Dependencies:")
    r.ImGui_BulletText(ctx, dep_badge(reaimgui_ok, "ReaImGui"))
    r.ImGui_BulletText(ctx, dep_badge(sws_ok, "SWS (optional, used for opening folders etc.)"))
    local running, hb = get_status()
r.ImGui_Separator(ctx)
r.ImGui_Text(ctx, "Status:")
r.ImGui_BulletText(ctx, (running and "✅ AutoDoctor running" or "❌ AutoDoctor not running"))
if hb > 0 then
  r.ImGui_BulletText(ctx, "Last AutoDoctor heartbeat (UTC epoch): "..tostring(hb))
else
  r.ImGui_BulletText(ctx, "Last AutoDoctor heartbeat: (unknown)")
end

r.ImGui_Separator(ctx)
r.ImGui_Text(ctx, "Reports:")
begin_disabled(not sws_ok)
if r.ImGui_Button(ctx, "Open latest Doctor report", -1, 0) then
  open_report("doctor", "Docs/MIDINetwork_Doctor_Report.md")
end
if r.ImGui_Button(ctx, "Open latest PortMatcher report", -1, 0) then
  open_report("portmatcher", "Docs/MIDINetwork_PortMatcher_Report.md")
end
if r.ImGui_Button(ctx, "Open latest Wiring report", -1, 0) then
  open_report("wiring", "Docs/MIDINetwork_WiringSheet.md")
end
if r.ImGui_Button(ctx, "Open latest ApplyPorts report", -1, 0) then
  open_report("apply_ports", "Docs/MIDINetwork_ApplyPorts_Report.md")
end
if r.ImGui_Button(ctx, "Open Patchbay (PX3000) Cheatsheet", -1, 0) then
  open_report(nil, "Workbench/Patchbay/Docs/PATCHBAY_PX3000_CHEATSHEET.md")
end

end_disabled(not sws_ok)
if not sws_ok then
  tooltip("Install SWS to enable opening reports directly. Reports live in: "..wb_root().."/Docs")
end

r.ImGui_Separator(ctx)

r.ImGui_Separator(ctx)

    local changed, s = r.ImGui_InputText(ctx, "Search", search)
    if changed then search = s end
    local c2, sp = r.ImGui_Checkbox(ctx, "Show paths", show_paths)
    if c2 then show_paths = sp end
    r.ImGui_Separator(ctx)

    if r.ImGui_Button(ctx, "Quick: Run Doctor", -1, 0) then
      run_script("Tools/IFLS_MIDINetwork_Doctor.lua")
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Quick: Port Matcher", -1, 0) then
      run_script("Tools/IFLS_MIDINetwork_ReaperPortMatcher.lua")
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Quick: Apply Port Names", -1, 0) then
      run_script("Tools/IFLS_MIDINetwork_Apply_ReaperPortNames_And_Indexes.lua")
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Quick: Export Wiring Sheet", -1, 0) then
      run_script("Tools/IFLS_MIDINetwork_Export_WiringSheet.lua")
    end
    r.ImGui_Separator(ctx)

    draw_group("MIDI Network", LAUNCH.MIDI)
    r.ImGui_Separator(ctx)
    draw_group("Devices", LAUNCH.DEVICES)
    r.ImGui_Separator(ctx)
    draw_group("Patchbay / Routing", LAUNCH.PATCHBAY)
    r.ImGui_Separator(ctx)
    draw_group("Field recordings / IDM", LAUNCH.FIELDREC_IDM)

    r.ImGui_Separator(ctx)
    begin_disabled(not sws_ok)
    if r.ImGui_Button(ctx, "Open Docs Folder (SWS)", -1, 0) then
      r.CF_ShellExecute(wb_root().."/Docs")
    end
    end_disabled(not sws_ok)
    if not sws_ok then
      tooltip("Requires SWS extension (CF_ShellExecute). Without SWS, open manually: "..wb_root().."/Docs")
    end
    if r.ImGui_Button(ctx, "Copy Docs Path to Clipboard", -1, 0) then
      r.ImGui_SetClipboardText(ctx, wb_root().."/Docs")
    end

    -- PSS-580 / PSS-x80
r.ImGui_Separator(ctx)
r.ImGui_Text(ctx, "PSS-580 / PSS-x80")
if r.ImGui_Button(ctx, "PSS-x80 Library Browser", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_Library_Browser.lua")
end
if r.ImGui_Button(ctx, "PSS Voice Editor (Randomize/Locks)", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_Voice_Editor.lua")
end
if r.ImGui_Button(ctx, "PSS Analyze .syx", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_Analyze_SYX_File.lua")
end
if r.ImGui_Button(ctx, "PSS Send Voice .syx", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_Send_Voice_SYX.lua")
end
if r.ImGui_Button(ctx, "PSS Safe Audition (manual backup)", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_Safe_Audition_ManualBackup.lua")
end
if r.ImGui_Button(ctx, "PSS Bank Import/Export (5 voices)", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_Bank_Import_Export.lua")
end
if r.ImGui_Button(ctx, "PSS Library Tag/Favorite", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_Library_Tag_Favorite.lua")
end
if r.ImGui_Button(ctx, "PSS Run Tests + Report", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_Run_Tests_Report.lua")
end


r.ImGui_End(ctx)
  end
  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)

if r.ImGui_Button(ctx, "PSS Doctor", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_Doctor.lua")
end
if r.ImGui_Button(ctx, "PSS Quick Setup (track)", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_QuickSetup.lua")
end

if r.ImGui_Button(ctx, "PSS Safe Audition Wizard", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_Safe_Audition_Wizard.lua")
end
if r.ImGui_Button(ctx, "PSS Bank Send Wizard", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_Bank_Send_Wizard.lua")
end
if r.ImGui_Button(ctx, "PSS Project Recall: Set", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_ProjectRecall_Set.lua")
end
if r.ImGui_Button(ctx, "PSS Project Recall: Apply", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_ProjectRecall_Apply.lua")
end
if r.ImGui_Button(ctx, "PSS Project Recall: Clear", -1, 0) then
  run_script("Workbench/PSS580/Tools/IFLS_PSS580_ProjectRecall_Clear.lua")
end
