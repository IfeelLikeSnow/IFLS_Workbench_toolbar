-- @description IFLS Workbench - PSS580/IFLS_PSS580_ImportSYX_UpdateManifest.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_PSS580_ImportSYX_UpdateManifest.lua
-- V60: Import a .syx into the PSS580 library (Banks 1-5) and update manifest.json.
-- Optional: set as Project Recall immediately.
--
-- Requires: ReaImGui
-- Optional: JS_ReaScriptAPI (file dialogs)

local r = reaper
local Lib = require("IFLS_Workbench/PSS580/IFLS_PSS580_Lib")

if not r.ImGui_CreateContext then
  r.MB("ReaImGui not found. Install ReaImGui, then rerun.", "IFLS PSS580 Import", 0)
  return
end

local ctx = r.ImGui_CreateContext("IFLS PSS580 Import SYX")

local SECTION = "IFLS_WORKBENCH_SETTINGS"
local manifest_rel = "Workbench/PSS580/Patches/manifest.json"
local syx_dir_rel = "Workbench/PSS580/Patches/syx"

local function file_copy(src, dst)
  local fi = io.open(src, "rb")
  if not fi then return false, "Cannot read: "..src end
  local data = fi:read("*all"); fi:close()
  local fo = io.open(dst, "wb")
  if not fo then return false, "Cannot write: "..dst end
  fo:write(data); fo:close()
  return true, data
end

local function sanitize_filename(s)
  s = (s or "PSS580_Patch"):gsub("[^%w%-%_%. ]", "_"):gsub("%s+", "_")
  if not s:lower():match("%.syx$") then s = s .. ".syx" end
  return s
end

local function split_tags(s)
  local out = {}
  for t in (s or ""):gmatch("[^,]+") do
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" then out[#out+1] = t end
  end
  return out
end

local function browse_open_syx()
  if r.JS_Dialog_BrowseForOpenFiles then
    local ok, files = r.JS_Dialog_BrowseForOpenFiles("Select .syx file", "", "", "SYX files\0*.syx\0", false)
    if ok and files and files ~= "" then
      return files
    end
  end
  return nil
end

local function load_manifest()
  local obj, err = Lib.load_json(manifest_rel)
  if not obj then return nil, err end
  obj.items = obj.items or {}
  return obj, nil
end

local function save_manifest(obj)
  -- Use JSON encoder if present
  local Boot_ok, Boot = pcall(require, "IFLS_Workbench/_bootstrap")
  local JSON = nil
  if Boot_ok and Boot and Boot.safe_require then
    JSON = Boot.safe_require("IFLS_Workbench/Lib/json") or Boot.safe_require("json")
  end
  if not JSON or not JSON.encode then
    return false, "JSON encoder missing"
  end

  obj.generated_utc = os.date("!%Y-%m-%dT%H:%M:%SZ")

  local txt = JSON.encode(obj, { indent = true })
  local path = Lib.get_scripts_root() .. "/" .. manifest_rel
  local f = io.open(path, "wb")
  if not f then return false, "Cannot write: "..path end
  f:write(txt); f:close()
  return true
end

-- UI state
local src_path = ""
local patch_name = ""
local patch_id = ""
local bank = 1
local tags_csv = "pad,drone"
local recommended_pc = -1
local delay_ms = 350
local set_as_recall = true
local status = ""

local function import_now()
  if src_path == "" then status = "Select a .syx file first."; return end
  if not Lib.file_exists(src_path) then status = "File not found: "..src_path; return end

  local filename = sanitize_filename((patch_name ~= "" and patch_name or patch_id ~= "" and patch_id or "Bank"..tostring(bank).."_Patch"))
  local dst_abs = Lib.get_scripts_root() .. "/" .. syx_dir_rel .. "/" .. filename
  local ok, data_or_err = file_copy(src_path, dst_abs)
  if not ok then status = data_or_err; return end

  local manifest, err = load_manifest()
  if not manifest then status = "Manifest error: "..tostring(err); return end

  local id = patch_id
  if id == "" then
    id = ("bank%d_%s"):format(bank, filename:gsub("%.syx$", ""):lower())
  end

  -- upsert
  local found = false
  for _,it in ipairs(manifest.items) do
    if it.id == id then
      it.name = (patch_name ~= "" and patch_name or it.name)
      it.bank = bank
      it.syx_path = syx_dir_rel .. "/" .. filename
      it.tags = split_tags(tags_csv)
      it.recommended_pc = (recommended_pc >= 0 and recommended_pc or nil)
      it.send_delay_ms = delay_ms
      it.sha1 = nil -- optional (can be filled by external tools later)
      found = true
      break
    end
  end
  if not found then
    table.insert(manifest.items, {
      id = id,
      name = (patch_name ~= "" and patch_name or id),
      bank = bank,
      syx_path = syx_dir_rel .. "/" .. filename,
      tags = split_tags(tags_csv),
      recommended_pc = (recommended_pc >= 0 and recommended_pc or nil),
      send_delay_ms = delay_ms,
      sha1 = nil,
      notes = nil
    })
  end

  local ok2, err2 = save_manifest(manifest)
  if not ok2 then status = "Save manifest failed: "..tostring(err2); return end

  if set_as_recall then
    Lib.safe_run("IFLS: PSS580 Import + Set Recall", function()
      Lib.set_project_recall(id, data_or_err)
      local tr = Lib.ensure_recall_track()
      Lib.write_recall_marker_item(tr, ("PSS580 Recall: %s (Bank %d)"):format(patch_name ~= "" and patch_name or id, bank))
    end)
  end

  status = "Imported: "..filename.."  (id="..id..")"
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 720, 420, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS PSS580 Import SYX", true)
  if visible then
    r.ImGui_TextWrapped(ctx, "Import a .syx into Workbench/PSS580/Patches/syx and update manifest.json. Optionally set it as Project Recall.")
    r.ImGui_Separator(ctx)

    local ch, v = r.ImGui_InputText(ctx, "SYX file path", src_path)
    if ch then src_path = v end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Browse...") then
      local p = browse_open_syx()
      if p then src_path = p end
    end

    local ch2, v2 = r.ImGui_InputText(ctx, "Patch name", patch_name)
    if ch2 then patch_name = v2 end

    local ch3, v3 = r.ImGui_InputText(ctx, "Patch id (optional)", patch_id)
    if ch3 then patch_id = v3 end

    local ch4, v4 = r.ImGui_SliderInt(ctx, "Bank (1-5)", bank, 1, 5)
    if ch4 then bank = v4 end

    local ch5, v5 = r.ImGui_InputText(ctx, "Tags (comma)", tags_csv)
    if ch5 then tags_csv = v5 end

    local ch6, v6 = r.ImGui_InputInt(ctx, "Recommended Program Change (-1 = none)", recommended_pc)
    if ch6 then
      if v6 < -1 then v6 = -1 end
      if v6 > 127 then v6 = 127 end
      recommended_pc = v6
    end

    local ch7, v7 = r.ImGui_InputInt(ctx, "Post-send delay (ms)", delay_ms)
    if ch7 then
      if v7 < 0 then v7 = 0 end
      if v7 > 5000 then v7 = 5000 end
      delay_ms = v7
    end

    local ch8, v8 = r.ImGui_Checkbox(ctx, "Set as Project Recall after import", set_as_recall)
    if ch8 then set_as_recall = v8 end

    r.ImGui_Separator(ctx)
    if r.ImGui_Button(ctx, "Import now") then import_now() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Open Patch Browser") then
      local p = Lib.get_scripts_root().."/Scripts/IFLS_Workbench/PSS580/IFLS_PSS580_Browser.lua"
      dofile(p)
    end

    if status ~= "" then
      r.ImGui_Separator(ctx)
      r.ImGui_TextWrapped(ctx, status)
    end

    r.ImGui_End(ctx)
  end
  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
