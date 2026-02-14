-- @description IFLS PSS-580 - Doctor (Dependencies + Routing Hints)
-- @version 1.06.0
-- @author IFLS

local r=reaper
if not r.ImGui_CreateContext then r.MB("ReaImGui required to run this doctor UI.", "PSS Doctor", 0); return end

local root = r.GetResourcePath().."/Scripts/IFLS_Workbench"
local ctx = r.ImGui_CreateContext("IFLS PSS-x80 Doctor")

local function can_write_reports()
  local test_path = root.."/Docs/Reports/_write_test.tmp"
  local f=io.open(test_path,"wb")
  if not f then return false end
  f:write("ok"); f:close()
  os.remove(test_path)
  return true
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 780, 440, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS PSS-x80 Doctor", true)
  if visible then
    local ok_sws = r.SNM_SendSysEx ~= nil
    local ok_js = r.JS_Dialog_BrowseForFolder ~= nil
    local ok_write = can_write_reports()

    r.ImGui_Text(ctx, "Checks")
    r.ImGui_Separator(ctx)

    local function row(label, ok, fix)
      r.ImGui_Text(ctx, (ok and "OK  " or "FAIL").."  "..label)
      if (not ok) and fix then
        r.ImGui_TextWrapped(ctx, "  Fix: "..fix)
      end
    end

    row("SWS SysEx send available (SNM_SendSysEx)", ok_sws, "Install SWS extensions.")
    row("JS extension available (optional)", ok_js, "Install js_ReaScriptAPI for nicer dialogs (optional).")
    row("Can write to Docs/Reports", ok_write, "Check permissions for REAPER resource path.")

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Routing hints (Variant 1: REAPER is clock master)")
    r.ImGui_TextWrapped(ctx,
      "- In REAPER: enable 'Send clock' ONLY on one mioXM output port.
"..
      "- In mioXM: distribute that clock to devices; avoid clock loopback.
"..
      "- For SysEx: ensure mioXM routes ALLOW SysEx (no SysEx filter).
"..
      "- Capture: arm a track with MIDI input set to the PSS port, then trigger PSS dump."
    )

    r.ImGui_Separator(ctx)
    if r.ImGui_Button(ctx, "Open Safe Audition Wizard", 260, 0) then
      dofile(root.."/Workbench/PSS580/Tools/IFLS_PSS580_Safe_Audition_Wizard.lua")
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Open Voice Editor", 260, 0) then
      dofile(root.."/Workbench/PSS580/Tools/IFLS_PSS580_Voice_Editor.lua")
    end

    r.ImGui_End(ctx)
  end
  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
