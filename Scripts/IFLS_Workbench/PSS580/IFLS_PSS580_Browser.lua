-- @description IFLS Workbench - PSS580/IFLS_PSS580_Browser.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_PSS580_Browser.lua
-- ReaImGui patch browser for Yamaha PSS-580 (Banks 1-5), with Preview Send + Copy into Project Recall.

local r = reaper
local Lib = require("IFLS_Workbench/PSS580/IFLS_PSS580_Lib")

if not r.ImGui_CreateContext then
  r.MB("ReaImGui not found. Install ReaImGui, then rerun.", "IFLS PSS580 Browser", 0)
  return
end

local ctx = r.ImGui_CreateContext("IFLS PSS580 Patch Browser")

-- Settings
local SECTION = "IFLS_WORKBENCH_SETTINGS"
local function get_midi_out_dev()
  local v = r.GetExtState(SECTION, "pss580_midi_out_dev")
  local n = tonumber(v or "")
  return n or 0 -- default: device 0
end

local function set_midi_out_dev(n)
  r.SetExtState(SECTION, "pss580_midi_out_dev", tostring(n), true)
end

local function get_include_f0f7()
  return (r.GetExtState(SECTION, "pss580_include_f0f7") ~= "0")
end
local function set_include_f0f7(v)
  r.SetExtState(SECTION, "pss580_include_f0f7", v and "1" or "0", true)
end

local function get_default_delay()
  local v = tonumber(r.GetExtState(SECTION, "pss580_default_delay_ms") or "")
  return v or 350
end
local function set_default_delay(ms)
  r.SetExtState(SECTION, "pss580_default_delay_ms", tostring(ms), true)
end

local function scripts_root()
  return Lib.get_scripts_root()
end

local manifest_rel = "Workbench/PSS580/Patches/manifest.json"
local manifest = nil
local load_err = nil

local search = ""
local bank_filter = 0 -- 0=all, 1..5 specific
local status = ""

local function load_manifest()
  local obj, err = Lib.load_json(manifest_rel)
  manifest = obj
  load_err = err
end

load_manifest()

local function item_matches(it)
  if bank_filter ~= 0 and tonumber(it.bank) ~= bank_filter then return false end
  if search == "" then return true end
  local s = search:lower()
  local hay = ((it.name or "").." "..(it.id or "").." "..table.concat(it.tags or {}, " ")):lower()
  return hay:find(s, 1, true) ~= nil
end

local function abs_syx_path(it)
  -- manifest stores repo-relative path from scripts_root
  local rel = it.syx_path or ""
  if rel == "" then return "" end
  return scripts_root() .. "/" .. rel
end

local function preview_send(it)
  local dev = get_midi_out_dev()
  local include_f0f7 = get_include_f0f7()
  local delay = tonumber(it.send_delay_ms or "") or get_default_delay()
  local path = abs_syx_path(it)
  local ok, err = Lib.send_syx_file(dev, path, include_f0f7, delay)
  status = ok and ("Sent: "..(it.name or it.id)) or ("Send failed: "..tostring(err))
end

local function copy_into_project(it)
  local path = abs_syx_path(it)
  local bytes = Lib.read_file(path) or ""
  local label = ("PSS580 Recall: %s (Bank %d)"):format(it.name or it.id, tonumber(it.bank) or 0)

  return Lib.safe_run("IFLS: PSS580 Copy Recall", function()
    -- store recall in project extstate (portable)
    Lib.set_project_recall(it.id or "", bytes)

    -- create/ensure recall track and write marker item (human visible)
    local tr = Lib.ensure_recall_track()
    Lib.write_recall_marker_item(tr, label)

    status = "Copied into Project Recall: "..(it.name or it.id)
  end)
end

local function draw_settings()
  r.ImGui_SeparatorText(ctx, "Settings")
  local dev = get_midi_out_dev()
  local changed, v = r.ImGui_InputInt(ctx, "MIDI OUT device index", dev)
  if changed then
    if v < 0 then v = 0 end
    set_midi_out_dev(v)
  end

  local inc = get_include_f0f7()
  local ch2, v2 = r.ImGui_Checkbox(ctx, "Include F0/F7 when sending (recommended)", inc)
  if ch2 then set_include_f0f7(v2) end

  local d = get_default_delay()
  local ch3, d2 = r.ImGui_InputInt(ctx, "Default post-send delay (ms)", d)
  if ch3 then
    if d2 < 0 then d2 = 0 end
    if d2 > 5000 then d2 = 5000 end
    set_default_delay(d2)
  end

  r.ImGui_TextWrapped(ctx, "Tip: if sending fails, check MIDI device index and that SWS is installed (SNM_SendSysEx).")
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 780, 520, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS PSS580 Patch Browser", true)
  if visible then
    if load_err then
      r.ImGui_TextWrapped(ctx, "Manifest load error: "..tostring(load_err))
      if r.ImGui_Button(ctx, "Reload manifest") then load_manifest() end
      r.ImGui_End(ctx)
      if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
      return
    end

    r.ImGui_SeparatorText(ctx, "Library")
    local chs, s2 = r.ImGui_InputText(ctx, "Search", search)
    if chs then search = s2 end

    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Reload") then load_manifest(); status="Reloaded." end

    r.ImGui_SameLine(ctx)
    r.ImGui_Text(ctx, "Bank:")
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "All") then bank_filter = 0 end
    for b=1,5 do
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, tostring(b)) then bank_filter = b end
    end

    r.ImGui_Separator(ctx)

    if r.ImGui_BeginTable(ctx, "tbl", 5, r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_RowBg() | r.ImGui_TableFlags_Resizable()) then
      r.ImGui_TableSetupColumn(ctx, "Bank", r.ImGui_TableColumnFlags_WidthFixed(), 50)
      r.ImGui_TableSetupColumn(ctx, "Name", r.ImGui_TableColumnFlags_WidthStretch())
      r.ImGui_TableSetupColumn(ctx, "Tags", r.ImGui_TableColumnFlags_WidthStretch())
      r.ImGui_TableSetupColumn(ctx, "Preview", r.ImGui_TableColumnFlags_WidthFixed(), 90)
      r.ImGui_TableSetupColumn(ctx, "Project", r.ImGui_TableColumnFlags_WidthFixed(), 140)
      r.ImGui_TableHeadersRow(ctx)

      for _,it in ipairs(manifest.items or {}) do
        if item_matches(it) then
          r.ImGui_TableNextRow(ctx)
          r.ImGui_TableSetColumnIndex(ctx, 0)
          r.ImGui_Text(ctx, tostring(it.bank or ""))
          r.ImGui_TableSetColumnIndex(ctx, 1)
          r.ImGui_Text(ctx, it.name or it.id or "")
          r.ImGui_TableSetColumnIndex(ctx, 2)
          r.ImGui_Text(ctx, table.concat(it.tags or {}, ", "))
          r.ImGui_TableSetColumnIndex(ctx, 3)
          if r.ImGui_Button(ctx, "Send##"..tostring(it.id)) then preview_send(it) end
          r.ImGui_TableSetColumnIndex(ctx, 4)
          if r.ImGui_Button(ctx, "Copy as Recall##"..tostring(it.id)) then copy_into_project(it) end
        end
      end

      r.ImGui_EndTable(ctx)
    end

    draw_settings()

    r.ImGui_Separator(ctx)
    if status ~= "" then r.ImGui_TextWrapped(ctx, status) end

    r.ImGui_End(ctx)
  end

  if open then
    r.defer(loop)
  else
    r.ImGui_DestroyContext(ctx)
  end
end

r.defer(loop)
