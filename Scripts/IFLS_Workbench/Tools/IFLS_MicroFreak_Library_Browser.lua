-- @description IFLS Workbench - MicroFreak Library Browser (SysEx + Project Recall)
-- @version 0.68.0
-- @author IfeelLikeSnow

local r = reaper
local Lib = require("IFLS_Workbench/Workbench/MicroFreak/IFLS_MicroFreak_Lib")

if not r.ImGui_CreateContext then
  r.MB("ReaImGui not installed. Install ReaImGui to use this browser.", "MicroFreak Library Browser", 0)
  return
end

local function list_midi_outputs()
  local out = {}
  local n = r.GetNumMIDIOutputs()
  for i = 0, n-1 do
    local rv, name = r.GetMIDIOutputName(i, "")
    if rv then out[#out+1] = {id=i, name=name} end
  end
  return out
end

local function combo_items(list)
  local s = ""
  for i,item in ipairs(list) do
    s = s .. item.name
    if i < #list then s = s .. "\0" end
  end
  return s .. "\0"
end

local function load_manifest()
  local p = Lib.manifest_path()
  if not Lib.file_exists(p) then
    return {schema_version="1.0.0", device="Arturia MicroFreak", items={}}
  end
  local obj = Lib.json_decode(Lib.read_file(p) or "") or {items={}}
  obj.items = obj.items or {}
  return obj
end

local function save_manifest(m)
  local s = Lib.json_encode(m)
  if not s then return false end
  return Lib.write_file(Lib.manifest_path(), s)
end

local function import_syx()
  local path = nil
  if r.JS_Dialog_BrowseForOpenFiles then
    local rv, files = r.JS_Dialog_BrowseForOpenFiles("Import MicroFreak .syx", "", "", "SysEx (*.syx)\0*.syx\0", false)
    if rv and files and files ~= "" then path = files:match("^[^;]+") end
  end
  if not path then
    local ok, p = r.GetUserFileNameForRead("", "Import MicroFreak .syx", ".syx")
    if ok then path = p end
  end
  if not path then return nil end
  if not Lib.file_exists(path) then
    r.MB("File not found:\n"..path, "MicroFreak Library Browser", 0)
    return nil
  end
  local name = path:gsub("\\","/"):match("([^/]+)$") or ("import_"..tostring(os.time())..".syx")
  local target = Lib.syx_dir().."/"..name
  local data = Lib.read_file(path)
  if not data then
    r.MB("Failed to read file.", "MicroFreak Library Browser", 0)
    return nil
  end
  if not Lib.write_file(target, data) then
    r.MB("Failed to write into library:\n"..target, "MicroFreak Library Browser", 0)
    return nil
  end
  return {filename=name, abs=target}
end

local function add_manifest_item(m, filename, display, tags)
  local id = ("mf_"..tostring(os.time()).."_"..tostring(math.random(1000,9999)))
  m.items[#m.items+1] = {
    id = id,
    name = display or filename,
    file = filename,
    tags = tags or "",
    added_utc = os.date("!%Y-%m-%dT%H:%M:%SZ")
  }
  return id
end

local ctx = r.ImGui_CreateContext("MicroFreak Library Browser")
local manifest = load_manifest()
local midi_outs = list_midi_outputs()
local out_index, channel = 1, 1
local search = ""
local selected = nil
local tag_edit, name_edit = "", ""

local recall = Lib.get_proj_recall(0)
if recall.channel then channel = recall.channel end
if recall.out_dev then
  for i,d in ipairs(midi_outs) do if d.id == recall.out_dev then out_index = i break end end
end

local function draw_row(it)
  local line = it.name or it.file or it.id
  local q = (search or ""):lower()
  local match = (q == "") or (line:lower():find(q,1,true) ~= nil) or ((it.tags or ""):lower():find(q,1,true) ~= nil)
  if not match then return end
  local is_sel = (selected and selected.id == it.id)
  if r.ImGui_Selectable(ctx, line, is_sel) then
    selected = it
    name_edit = it.name or ""
    tag_edit = it.tags or ""
  end
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 1000, 640, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS MicroFreak Library Browser", true)
  if visible then
    r.ImGui_TextWrapped(ctx, "Browse MicroFreak .syx presets/banks (MCC exports). Preview send, set Project Recall, and import new .syx into the library.")
    r.ImGui_Separator(ctx)

    if #midi_outs == 0 then
      r.ImGui_Text(ctx, "No MIDI outputs found (Preferences -> MIDI Devices).")
    else
      local items = combo_items(midi_outs)
      local changed, idx = r.ImGui_Combo(ctx, "MIDI Output", out_index-1, items)
      if changed then out_index = idx+1 end
    end
    local chg, ch = r.ImGui_SliderInt(ctx, "MIDI Channel", channel, 1, 16)
    if chg then channel = ch end
    local schg, s = r.ImGui_InputText(ctx, "Search", search)
    if schg then search = s end

    if r.ImGui_Button(ctx, "Reload manifest") then
      manifest = load_manifest()
      selected = nil
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Import .syx into library") then
      local imp = import_syx()
      if imp then
        local ok, disp = r.GetUserInputs("Add to MicroFreak library", 2, "Display name,Tags", imp.filename..",")
        if ok then
          local a,b = disp:match("^(.-),(.*)$")
          local id = add_manifest_item(manifest, imp.filename, a, b)
          save_manifest(manifest)
          for _,it in ipairs(manifest.items) do if it.id == id then selected = it end end
        end
      end
    end

    r.ImGui_Separator(ctx)

    if r.ImGui_BeginChild(ctx, "list", 530, 450, true) then
      for _,it in ipairs(manifest.items) do draw_row(it) end
      r.ImGui_EndChild(ctx)
    end

    r.ImGui_SameLine(ctx)

    if r.ImGui_BeginChild(ctx, "details", 440, 450, true) then
      if not selected then
        r.ImGui_TextWrapped(ctx, "Select an item to see details.")
      else
        r.ImGui_Text(ctx, "ID: "..tostring(selected.id))
        r.ImGui_Text(ctx, "File: "..tostring(selected.file))
        local nchg, n = r.ImGui_InputText(ctx, "Name", name_edit)
        if nchg then name_edit = n end
        local tchg, t = r.ImGui_InputText(ctx, "Tags", tag_edit)
        if tchg then tag_edit = t end

        if r.ImGui_Button(ctx, "Save metadata") then
          selected.name = name_edit
          selected.tags = tag_edit
          save_manifest(manifest)
        end

        r.ImGui_Separator(ctx)

        local out_dev = (#midi_outs>0 and midi_outs[out_index] and midi_outs[out_index].id) or nil

        if r.ImGui_Button(ctx, "Preview Send (.syx)") then
          local ok, msg = Lib.send_syx_file(out_dev, selected.file)
          if ok then r.MB("Sent SysEx:\n"..msg, "MicroFreak", 0) else r.MB(msg, "MicroFreak", 0) end
        end

        if r.ImGui_Button(ctx, "Set as Project Recall") then
          Lib.set_proj_recall(0, selected.file, nil, channel, out_dev)
          r.MB("Project Recall set to:\n"..tostring(selected.name).."\n("..tostring(selected.file)..")", "MicroFreak", 0)
        end

        if r.ImGui_Button(ctx, "Set Recall + Send Now") then
          Lib.set_proj_recall(0, selected.file, nil, channel, out_dev)
          local ok, msg = Lib.send_syx_file(out_dev, selected.file)
          if ok then r.MB("Recall set and SysEx sent:\n"..msg, "MicroFreak", 0) else r.MB(msg, "MicroFreak", 0) end
        end
      end
      r.ImGui_EndChild(ctx)
    end

    r.ImGui_Separator(ctx)
    r.ImGui_TextWrapped(ctx, "Tip: Use 'MicroFreak CC Panel' to tweak CCs and store a CC snapshot into Project Recall.")
    r.ImGui_End(ctx)
  end

  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
