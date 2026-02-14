-- @description IFLS Workbench - Workbench/Scripts/IFLS_Workbench_Repo_Diagnostics.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_Workbench_Repo_Diagnostics.lua
-- V52: Scans all loaded scripts for dependencies, missing extensions, and common pitfalls.
-- Outputs a report to REAPER console.

local r = reaper

local function msg(s) r.ShowConsoleMsg(tostring(s).."\n") end

msg("")
msg("=== IFLS Workbench Repo Diagnostics (V52) ===")

local resource = r.GetResourcePath()
local scripts_root = resource .. "/Scripts"

local deps = {
  {name="SWS", check=function() return r.SNM_SendSysEx~=nil end},
  {name="ReaImGui", check=function() return r.ImGui_CreateContext~=nil end},
  {name="JS_ReaScriptAPI", check=function() return r.JS_Dialog_BrowseForOpenFiles~=nil end},
}

for _,d in ipairs(deps) do
  msg(string.format("%-18s : %s", d.name, d.check() and "OK" or "MISSING"))
end

msg("")
msg("Scanning Lua scripts for known patterns...")

local issues = 0
for file in io.popen('dir "'..scripts_root..'" /s /b'):lines() do
  if file:match("%.lua$") then
    local f = io.open(file, "r")
    if f then
      local txt = f:read("*all")
      f:close()

      if txt:match("^\\") then
        msg("ERROR: leading backslash -> "..file)
        issues=issues+1
      end
      if txt:match("MIDI_GetTextSysexEvt%(") and txt:match(",%s*false") then
        msg("WARN: legacy MIDI_GetTextSysexEvt signature -> "..file)
        issues=issues+1
      end
      if txt:match("SNM_SendSysEx") and not txt:match("SWS") then
        msg("INFO: uses SNM_SendSysEx -> "..file)
      end
    end
  end
end

msg("")
msg("Diagnostics finished. Issues flagged: "..issues)
msg("=== end ===")
