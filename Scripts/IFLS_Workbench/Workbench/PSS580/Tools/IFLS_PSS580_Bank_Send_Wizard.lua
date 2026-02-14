-- @description IFLS PSS-580 - Bank Send Wizard (optional safe backup)
-- @version 1.05.0
-- @author IFLS
-- @about
--  Sends a multi-message bank .syx (or single voice .syx) to the PSS.
--  Optional: opens Safe Audition Wizard for backup first.

local r=reaper
if not r.ImGui_CreateContext then r.MB("ReaImGui required.", "PSS Bank Send", 0); return end
if not r.SNM_SendSysEx then r.MB("SWS required (SNM_SendSysEx).", "PSS Bank Send", 0); return end

local root = r.GetResourcePath().."/Scripts/IFLS_Workbench"
local ctx = r.ImGui_CreateContext("IFLS PSS-x80 Bank Send Wizard")
local path = ""
local status = ""

local function read_all(p)
  local f=io.open(p,"rb"); if not f then return nil end
  local d=f:read("*all"); f:close(); return d
end

local function pick()
  local ok, p = r.GetUserFileNameForRead("", "Select .syx to send (bank or voice)", ".syx")
  if ok and p and p~="" then path=p; status="Ready." end
end

local function send()
  if path=="" then status="No file selected."; return end
  local blob=read_all(path)
  if not blob then status="Cannot read file."; return end
  r.SNM_SendSysEx(blob)
  status="Sent: "..path
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 720, 260, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS PSS-x80 Bank Send Wizard", true)
  if visible then
    r.ImGui_Text(ctx, "File:")
    r.ImGui_TextWrapped(ctx, path~="" and path or "(none)")
    r.ImGui_Separator(ctx)

    if r.ImGui_Button(ctx, "Choose .syx", 160, 0) then pick() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Send now", 160, 0) then send() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Open Safe Audition Wizard", 220, 0) then
      dofile(root.."/Workbench/PSS580/Tools/IFLS_PSS580_Safe_Audition_Wizard.lua")
    end

    r.ImGui_Separator(ctx)
    if status~="" then r.ImGui_TextWrapped(ctx, "Status: "..status) end
    r.ImGui_End(ctx)
  end
  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
