-- @description IFLS Workbench - Tools/IFLS_Workbench_Settings.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_Workbench_Settings.lua
-- V57: Settings panel for IFLS Workbench (data_root, diagnostics links).
--
-- Requires: ReaImGui
-- Optional: JS_ReaScriptAPI for folder browse dialog

local r = reaper
local Boot_ok, Boot = pcall(require, "IFLS_Workbench/_bootstrap")
if not Boot_ok then Boot = nil end

if not r.ImGui_CreateContext then
  r.MB("ReaImGui not found. Install ReaImGui, then rerun.", "IFLS Workbench Settings", 0)
  return
end

local ctx = r.ImGui_CreateContext("IFLS Workbench Settings")
local SECTION = (Boot and Boot.ext and Boot.ext.workbench_settings) or "IFLS_WORKBENCH_SETTINGS"

local function get_data_root()
  local v = r.GetExtState(SECTION, "data_root")
  if v and v ~= "" then return v end
  if Boot and Boot.get_data_root then return Boot.get_data_root() end
  return r.GetResourcePath().."/Scripts/IFLS_Workbench/Data"
end

local data_root = get_data_root()
local status = ""

local function browse_folder()
  if r.JS_Dialog_BrowseForFolder then
    local ok, folder = r.JS_Dialog_BrowseForFolder("Select IFLS Workbench data_root", data_root)
    if ok and folder and folder ~= "" then
      data_root = folder
      status = "Selected: "..folder
    end
  else
    r.MB("JS_ReaScriptAPI missing. Install it for a folder picker.\n\nYou can still paste a path manually.", "IFLS Workbench Settings", 0)
  end
end

local function save()
  r.SetExtState(SECTION, "data_root", data_root or "", true)
  status = "Saved data_root."
end

local function reset_default()
  r.DeleteExtState(SECTION, "data_root", true)
  data_root = get_data_root()
  status = "Reset to default."
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 620, 220, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS Workbench Settings", true)
  if visible then
    r.ImGui_Text(ctx, "data_root (where gear.json / patchbay.json live)")
    local changed, v = r.ImGui_InputText(ctx, "##data_root", data_root or "")
    if changed then data_root = v end

    if r.ImGui_Button(ctx, "Browse...") then browse_folder() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Save") then save() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Reset default") then reset_default() end

    r.ImGui_Separator(ctx)
    r.ImGui_TextWrapped(ctx, "Tip: After changing data_root, run 'IFLS_Workbench_SelfTest.lua' and 'IFLS_Workbench_Validate_Data_JSON.lua'.")
local strict = (r.GetExtState(SECTION, "validator_strict") == "1")
local changed2, strict2 = r.ImGui_Checkbox(ctx, "Validator strict mode (schema required-keys)", strict)
if changed2 then
  r.SetExtState(SECTION, "validator_strict", strict2 and "1" or "0", true)
  status = "Validator strict mode: " .. (strict2 and "ON" or "OFF")
end


    if status ~= "" then
      r.ImGui_Separator(ctx)
      r.ImGui_Text(ctx, status)
    end
    r.ImGui_End(ctx)
  end

  if open then
    r.defer(loop)
  else
    r.ImGui_DestroyContext(ctx)
  end
end

r.defer(loop)
