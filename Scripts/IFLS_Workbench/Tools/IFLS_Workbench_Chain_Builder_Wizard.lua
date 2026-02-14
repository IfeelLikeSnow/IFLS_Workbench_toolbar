-- @description IFLS Workbench - Tools/IFLS_Workbench_Chain_Builder_Wizard.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench - Chain Builder Wizard (Hardware + Patchbay)
-- @version 0.1.0
-- @author IFLS
-- @about
--   Build a hardware processing chain from:
--   - Data/IFLS_Workbench/device_profiles/*.json  (inventory + controls)
--   - Data/IFLS_Workbench/chain_presets/*.json    (sound intents)
--   - Data/IFLS_Workbench/patchbay.json           (routing)
--
--   Creates a track structure + routing + notes that document the external chain.
--   Options:
--     - Tracks method (hardware send/return)
--     - ReaInsert optional (adds FX; user selects IO manually in ReaInsert UI)
--     - Both
--
--   Requires ReaImGui.

local r = reaper

local SafeApply = require("IFLS_Workbench/Engine/IFLS_SafeApply")
if not r.ImGui_CreateContext then
  r.MB("ReaImGui extension not found.\nInstall via ReaPack → ReaTeam Extensions → ReaImGui.", "IFLS Workbench", 0)
  return
end

-- module path
package.path = package.path .. ";" .. r.GetResourcePath() .. "/Scripts/?.lua"
local Engine = require("IFLS_Workbench/Engine/IFLS_Patchbay_RoutingEngine")

-- ---------- tiny JSON decoder (same as elsewhere) ----------
local function json_decode(str)
  local i = 1
  local function skip()
    while true do
      local c = str:sub(i,i)
      if c == '' then return end
      if c == ' ' or c == '\n' or c == '\r' or c == '\t' then i = i + 1 else return end
    end
  end
  local function parse_value()
    local function parse_string()
      i = i + 1
      local out = {}
      while true do
        local c = str:sub(i,i)
        if c == '' then error("Unterminated string") end
        if c == '"' then i = i + 1; return table.concat(out) end
        if c == '\\' then
          local n = str:sub(i+1,i+1)
          if n == '"' or n == '\\' or n == '/' then out[#out+1]=n; i=i+2
          elseif n == 'b' then out[#out+1]='\b'; i=i+2
          elseif n == 'f' then out[#out+1]='\f'; i=i+2
          elseif n == 'n' then out[#out+1]='\n'; i=i+2
          elseif n == 'r' then out[#out+1]='\r'; i=i+2
          elseif n == 't' then out[#out+1]='\t'; i=i+2
          else out[#out+1]='\\'..n; i=i+2 end
        else out[#out+1]=c; i=i+1 end
      end
    end
    local function parse_number()
      local s = i
      local c = str:sub(i,i)
      if c == '-' then i=i+1 end
      while str:sub(i,i):match('%d') do i=i+1 end
      if str:sub(i,i) == '.' then i=i+1; while str:sub(i,i):match('%d') do i=i+1 end end
      local e = str:sub(i,i)
      if e == 'e' or e == 'E' then
        i=i+1
        local sign = str:sub(i,i)
        if sign == '+' or sign == '-' then i=i+1 end
        while str:sub(i,i):match('%d') do i=i+1 end
      end
      return tonumber(str:sub(s,i-1))
    end
    local function parse_array()
      i=i+1; skip()
      local arr = {}
      if str:sub(i,i) == ']' then i=i+1; return arr end
      while true do
        arr[#arr+1] = parse_value()
        skip()
        local c = str:sub(i,i)
        if c == ',' then i=i+1; skip()
        elseif c == ']' then i=i+1; return arr
        else error("Expected , or ]") end
      end
    end
    local function parse_object()
      i=i+1; skip()
      local obj = {}
      if str:sub(i,i) == '}' then i=i+1; return obj end
      while true do
        if str:sub(i,i) ~= '"' then error("Expected string key") end
        local k = parse_string()
        skip()
        if str:sub(i,i) ~= ':' then error("Expected :") end
        i=i+1; skip()
        obj[k] = parse_value()
        skip()
        local c = str:sub(i,i)
        if c == ',' then i=i+1; skip()
        elseif c == '}' then i=i+1; return obj
        else error("Expected , or }") end
      end
    end
    skip()
    local c = str:sub(i,i)
    if c == '"' then return parse_string()
    elseif c == '{' then return parse_object()
    elseif c == '[' then return parse_array()
    elseif c:match('[%-%d]') then return parse_number()
    elseif str:sub(i,i+3) == 'true' then i=i+4; return true
    elseif str:sub(i,i+4) == 'false' then i=i+5; return false
    elseif str:sub(i,i+3) == 'null' then i=i+4; return nil
    else error("Unexpected token at "..i) end
  end
  local ok, res = pcall(parse_value)
  if not ok then return nil, res end
  return res, nil
end

local function slurp(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function norm(s) return tostring(s or ""):lower() end

local function bool(x) return x and true or false end

-- ---------- Load data ----------
local resource = r.GetResourcePath()
local base = resource .. "/Data/IFLS_Workbench"

local function load_json(path)
  local s = slurp(path)
  if not s then return nil, "missing: " .. path end
  local obj, err = json_decode(s)
  if not obj then return nil, err end
  return obj, nil
end

local patch_data, patch_err = Engine.load_patchbay()

local profiles_index, idx_err = load_json(base .. "/device_profiles_index.json")

local function list_chain_presets()
  local dir = base .. "/chain_presets"
  local list = {}
  local i = 0
  while true do
    local fn = r.EnumerateFiles(dir, i)
    if not fn then break end
    if fn:match("%.json$") then list[#list+1] = fn end
    i = i + 1
  end
  table.sort(list)
  return list
end

local chain_files = list_chain_presets()
local chain_cache = {}

local function load_chain(filename)
  if chain_cache[filename] then return chain_cache[filename] end
  local obj, err = load_json(base .. "/chain_presets/" .. filename)
  if not obj then return nil, err end
  chain_cache[filename] = obj
  return obj, nil
end

local function load_profile(id)
  local obj, err = load_json(base .. "/device_profiles/" .. id .. ".json")
  return obj, err
end

local function list_profiles()
  local devs = (profiles_index and profiles_index.devices) or {}
  local list = {}
  for _, d in ipairs(devs) do list[#list+1] = d end
  table.sort(list, function(a,b) return (a.name_de or "") < (b.name_de or "") end)
  return list
end

local profiles_list = list_profiles()

-- ---------- Chains / Presets ----------
local function load_chain_presets()
  local resource = r.GetResourcePath()
  local p = resource .. "/Data/IFLS_Workbench/chains/chain_presets.json"
  local txt = read_file(p)
  if not txt then return {use_cases={}, presets={}}, "Missing chain_presets.json at:\n" .. p end
  local ok, obj = pcall(json_decode, txt)
  if not ok or type(obj) ~= "table" then
    return {use_cases={}, presets={}}, "Failed to parse chain_presets.json"
  end
  obj.use_cases = obj.use_cases or {}
  obj.presets = obj.presets or {}
  return obj, nil
end

local chain_db, chain_db_err = load_chain_presets()
local selected_use_case = 1
local selected_preset = 1

local function presets_for_use_case(use_case_id)
  local out = {}
  for _, pr in ipairs(chain_db.presets or {}) do
    if pr.use_case_id == use_case_id then out[#out+1] = pr end
  end
  return out
end

local function find_profile_by_id(pid)
  if not pid or pid == "" then return nil end
  for _, prof in ipairs(profiles_list or {}) do
    if prof.id == pid then return prof end
  end
  return nil
end

local function load_preset_into_builder(preset)
  if type(preset) ~= "table" then return end
  -- We store selections in current_chain (role -> chosen profile)
  current_chain = current_chain or {}
  for _, st in ipairs(preset.steps or {}) do
    local role = st.role
    if role and role ~= "" then
      local prof = find_profile_by_id(st.device_id)
      current_chain[role] = {
        prof = prof,
        device_id = st.device_id,
        knob_hints = st.knob_hints or {},
        note_de = st.note_de or ""
      }
    end
  end
  -- also store routing hint
  current_preset = preset
end

-- ---------- Mode Matrix channel (cheatsheet panel) ----------
local matrix_filter = ""
local matrix_scope = "auto" -- auto|pick|hover
local last_hover_prof = nil
local matrix_preset = "none"
local matrix_show_presets = true
local append_notes = true

local function pm_to_rows(pm)
  local rows = {}
  if type(pm) ~= "table" then return rows end
  local is_array = (pm[1] ~= nil)
  if is_array then
    for _, row in ipairs(pm) do
      rows[#rows+1] = {
        mode = tostring(row.type or row.mode or ""),
        p1 = tostring(row.param1 or row.p1 or ""),
        p2 = tostring(row.param2 or row.p2 or ""),
        p3 = tostring(row.param3 or row.p3 or ""),
        src = tostring(row.source or "")
      }
    end
  else
    for mode, params in pairs(pm) do
      if type(params) == "table" then
        rows[#rows+1] = {
          mode = tostring(mode),
          p1 = tostring(params.param1 or ""),
          p2 = tostring(params.param2 or ""),
          p3 = tostring(params.param3 or ""),
          src = tostring(params.source or "")
        }
      end
    end
  end
  table.sort(rows, function(a,b) return a.mode < b.mode end)
  return rows
end

local function matches_filter(row, f)
  if not f or f == "" then return true end
  local s = (row.mode .. " " .. row.p1 .. " " .. row.p2 .. " " .. row.p3 .. " " .. (row.src or "")):lower()
  return s:find(f:lower(), 1, true) ~= nil
end



local function pct_to_clock(pct)
  -- pct: 0..100 -> "7:00..5:00" style (approx). 50 = 12:00.
  local p = tonumber(pct) or 0
  if p < 0 then p = 0 end
  if p > 100 then p = 100 end
  local hours = 7 + (p/100.0)*10 -- 7..17
  local h = math.floor(hours)
  local m = math.floor((hours - h) * 60 + 0.5)
  if m >= 60 then h = h + 1; m = 0 end
  if h > 12 then h = h - 12 end
  if h == 0 then h = 12 end
  return ("%d:%02d"):format(h, m)
end

local function add_knob_hint(lines, knob, pct, extra)
  local clk = pct_to_clock(pct)
  local s = ("%s: %s (~%d%%)"):format(knob, clk, math.floor(pct+0.5))
  if extra and extra ~= "" then s = s .. " — " .. extra end
  lines[#lines+1] = s
end

local function build_matrix_clipboard_text(prof, rows, filter_txt)
  local name = tostring(prof.name_de or prof.name_en or prof.id or "")
  local out = {}
  out[#out+1] = "Mode Matrix: " .. name
  if filter_txt and filter_txt ~= "" then
    out[#out+1] = "Filter: " .. filter_txt
  end
  out[#out+1] = "mode\tparam1\tparam2\tparam3"
  for _, row in ipairs(rows) do
    if matches_filter(row, filter_txt or "") then
      out[#out+1] = ("%s\t%s\t%s\t%s"):format(row.mode, row.p1 ~= "" and row.p1 or "-", row.p2 ~= "" and row.p2 or "-", row.p3 ~= "" and row.p3 or "-")
    end
  end
  return table.concat(out, "\n")
end

local function preset_hints_for(prof, preset_name)
  -- returns {title=..., lines={...}}
  local id = (prof.id or ""):lower()
  local cc = prof.controls_contextual or {}
  local pm = cc.param_matrix

  local hints = {title = "Preset Hints", lines = {}}
  if preset_name == "none" then
    hints.title = "Preset Hints (none)"
    hints.lines = {"Wähle ein Preset, um Vorschläge zu sehen."}
    return hints
  end

  if preset_name == "idm_shimmer_pad" then
    hints.title = "IDM Shimmer Pad"
    if id:find("mini_universe") and type(pm)=="table" and pm.shimmer then
      hints.lines = {}
      hints.lines[#hints.lines+1] = "Mode: shimmer"
      add_knob_hint(hints.lines, "Mix", 55, "Pad vorne, aber Dry stabil")
      add_knob_hint(hints.lines, "Decay", 80, "lange Hallfahne")
      add_knob_hint(hints.lines, "Param1 (High-Pass)", 60, "Low-End frei lassen")
      add_knob_hint(hints.lines, "Param2 (Pitch)", 70, "+1 Oct airy; 90% ~ +2 Oct")
      add_knob_hint(hints.lines, "Param3 (Amount)", 50, "mittel; zu hoch wird schrill")
      hints.lines[#hints.lines+1] = "Tipp: danach Chorus/Ensemble subtil + ReaEQ HPF"
    
    else
      hints.lines = {
        "Empfohlen: Reverb/Delay Mode mit Pitch/Texture",
        "Mix 40–70%, lange Decay/Time, HighPass etwas hoch, Texture/Amount mittel"
      }
    end
    return hints
  end

  if preset_name == "lofi_drift_drone" then
    hints.title = "LoFi Drift Drone"
    if id:find("mini_universe") and type(pm)=="table" and pm.lofi then
      hints.lines = {}
      hints.lines[#hints.lines+1] = "Mode: lofi"
      add_knob_hint(hints.lines, "Mix", 85, "für Drone auch full wet")
      add_knob_hint(hints.lines, "Decay", 65, "mittel–hoch")
      add_knob_hint(hints.lines, "Param1 (Sample Rate)", 25, "runter für Crunch")
      add_knob_hint(hints.lines, "Param2 (White Noise)", 30, "nur als 'air'")
      add_knob_hint(hints.lines, "Param3 (Drift)", 75, "bewegte Textur")
      hints.lines[#hints.lines+1] = "Tipp: parallel aufnehmen und in Reaper resamplen/loopen"
    
    else
      hints.lines = {
        "Empfohlen: LoFi/Mod/Texture Mode, Mix hoch, SampleRate runter, Drift hoch"
      }
    end
    return hints
  end

  if preset_name == "glitch_chop_ice" then
    hints.title = "Glitch Chop / ICE"
    if id:find("elemental") and type(pm)=="table" then
      hints.lines = {}
      hints.lines[#hints.lines+1] = "Mode: ICE (oder PATTERN)"
      add_knob_hint(hints.lines, "Mix", 45, "glitch layer")
      add_knob_hint(hints.lines, "Time", 35, "kurz–mittel, rhythmisch")
      add_knob_hint(hints.lines, "Mod (Rate)", 70, "schnell für Stutter")
      add_knob_hint(hints.lines, "Param (Pitch/Artifacts)", 65, "mittel–hoch")
      hints.lines[#hints.lines+1] = "Tipp: Gate vor Insert + danach Transient/EQ"
    
    else
      hints.lines = {
        "Empfohlen: Mode mit Chop/Pattern; Mix mittel; Mod=Rate; Param=Artifact/Pitch"
      }
    end
    return hints
  end

  hints.title = "Preset Hints (unknown preset)"
  hints.lines = {"Unbekanntes Preset."}
  return hints
end


local function apply_text_to_selected_track_notes(text, append)
  if not text or text == "" then return false, "empty text" end
  local tr = r.GetSelectedTrack(0, 0)
  if not tr then
    -- fallback: master track
    tr = r.GetMasterTrack(0)
  end
  local ok, cur = r.GetSetMediaTrackInfo_String(tr, "P_NOTES", "", false)
  if not ok then cur = "" end
  local out = text
  if append and cur ~= "" then
    out = (cur .. "\n\n" .. text)
  end
  r.GetSetMediaTrackInfo_String(tr, "P_NOTES", out, true)
  return true, "ok"
end

local function draw_mode_matrix_channel(ctx, prof)
  if type(prof) ~= "table" then
    r.ImGui_TextDisabled(ctx, "Mode Matrix: kein Device ausgewählt.")
    return
  end
  local cc = prof.controls_contextual
  if type(cc) ~= "table" or type(cc.param_matrix) ~= "table" then
    r.ImGui_TextDisabled(ctx, "Mode Matrix: dieses Device hat keine Param-Matrix.")
    return
  end

  r.ImGui_Text(ctx, ("Mode Matrix: %s"):format(tostring(prof.name_de or prof.name_en or prof.id or "")))

  r.ImGui_SameLine(ctx)
  if matrix_show_presets then
    if r.ImGui_Button(ctx, "Hide preset hints") then matrix_show_presets = false end
  else
    if r.ImGui_Button(ctx, "Show preset hints") then matrix_show_presets = true end
  end
  local changed; changed, matrix_filter = r.ImGui_InputText(ctx, "Search/Filter", matrix_filter)
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, "Clear") then matrix_filter = "" end

  r.ImGui_SameLine(ctx)
  local rows_preview = pm_to_rows(cc.param_matrix)
  if r.ImGui_Button(ctx, "Copy (filtered)") then
    local txt = build_matrix_clipboard_text(prof, rows_preview, matrix_filter)
    r.ImGui_SetClipboardText(ctx, txt)
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, "Copy (all)") then
    local txt = build_matrix_clipboard_text(prof, rows_preview, "")
    r.ImGui_SetClipboardText(ctx, txt)
  end

  r.ImGui_SameLine(ctx)
  local items = {"auto", "pick", "hover"}
  local idx = 1
  if matrix_scope == "pick" then idx = 2 elseif matrix_scope == "hover" then idx = 3 end
  local changed2; changed2, idx = r.ImGui_Combo(ctx, "Scope", idx, table.concat(items, "\0") .. "\0")
  if changed2 then matrix_scope = items[idx] end

  -- Preset hints
  if matrix_show_presets then
    r.ImGui_Separator(ctx)
    local preset_items = {"none", "idm_shimmer_pad", "lofi_drift_drone", "glitch_chop_ice"}
    local pidx = 1
    for i, it in ipairs(preset_items) do
      if it == matrix_preset then pidx = i break end
    end
    local changed3; changed3, pidx = r.ImGui_Combo(ctx, "Preset", pidx, table.concat(preset_items, "\0") .. "\0")
    if changed3 then matrix_preset = preset_items[pidx] end

    local hints = preset_hints_for(prof, matrix_preset)
    r.ImGui_Text(ctx, hints.title)
    for _, line in ipairs(hints.lines or {}) do
      r.ImGui_BulletText(ctx, line)
    end
    
    r.ImGui_SameLine(ctx)
    if append_notes == nil then append_notes = true end
    local ch; ch, append_notes = r.ImGui_Checkbox(ctx, "Append", append_notes)

    if r.ImGui_Button(ctx, "Apply to selected track notes") then
      local out = {}
      out[#out+1] = (hints.title or "Preset Hints") .. " — " .. tostring(prof.name_de or prof.name_en or prof.id or "")
      out[#out+1] = ""
      for _, line in ipairs(hints.lines or {}) do out[#out+1] = "- " .. line end
      local ok, msg = apply_text_to_selected_track_notes(table.concat(out, "\n"), append_notes)
      -- optional feedback
      if not ok then
        r.ShowMessageBox("Failed to write track notes: " .. tostring(msg), "IFLS Workbench", 0)
      end
    end

    if r.ImGui_Button(ctx, "Copy preset hints") then
      local out = {}
      out[#out+1] = (hints.title or "Preset Hints") .. " — " .. tostring(prof.name_de or prof.name_en or prof.id or "")
      for _, line in ipairs(hints.lines or {}) do out[#out+1] = "- " .. line end
      r.ImGui_SetClipboardText(ctx, table.concat(out, "\n"))
    end
  else
    if r.ImGui_Button(ctx, "Show preset hints") then matrix_show_presets = true end
  end

  local tp = cc.type_knob_positions
  if type(tp) == "table" and #tp > 0 then
    if r.ImGui_TreeNode(ctx, "Type/GEAR mapping") then
      for _, it in ipairs(tp) do
        r.ImGui_BulletText(ctx, ("%s → %s"):format(tostring(it.label or it.index), tostring(it.mode)))
      end
      r.ImGui_TreePop(ctx)
    end
  end

  local rows = pm_to_rows(cc.param_matrix)

  if r.ImGui_BeginTable(ctx, "mode_matrix_table", 4, r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_RowBg() | r.ImGui_TableFlags_SizingStretchProp()) then
    r.ImGui_TableSetupColumn(ctx, "Mode")
    r.ImGui_TableSetupColumn(ctx, "Param1")
    r.ImGui_TableSetupColumn(ctx, "Param2")
    r.ImGui_TableSetupColumn(ctx, "Param3")
    r.ImGui_TableHeadersRow(ctx)

    for _, row in ipairs(rows) do
      if matches_filter(row, matrix_filter) then
        r.ImGui_TableNextRow(ctx)
        r.ImGui_TableSetColumnIndex(ctx, 0); r.ImGui_Text(ctx, row.mode)
        r.ImGui_TableSetColumnIndex(ctx, 1); r.ImGui_Text(ctx, row.p1 ~= "" and row.p1 or "-")
        r.ImGui_TableSetColumnIndex(ctx, 2); r.ImGui_Text(ctx, row.p2 ~= "" and row.p2 or "-")
        r.ImGui_TableSetColumnIndex(ctx, 3); r.ImGui_Text(ctx, row.p3 ~= "" and row.p3 or "-")
      end
    end
    r.ImGui_EndTable(ctx)
  end
end

-- ---------- Verification helpers ----------
local function verif_tag(prof)
  local m = (prof and prof.meta) or {}
  if m.controls_completeness == "manual_rich" or m.manual_rich then return "[MR]" end
  if m.panel_verified or prof.controls_verified_by_image then return "[PV]" end
  if m.video_verified or m.video_verified_at_utc then return "[VV]" end
  if m.web_verified or m.web_verified_at_utc then return "[WV]" end
  if m.controls_completeness == "partial_manual" or m.partial_manual then return "[PM]" end
  return "[?]"
end

local function verif_tooltip_text(tag)
  if tag == "[MR]" then return "Manual-rich: tief aus Manual/Service-Doku gemappt"
  elseif tag == "[PV]" then return "Panel-verified: Regler/Schalter per Foto/Panel verifiziert"
  elseif tag == "[VV]" then return "Video-verified: Funktionen aus Video/Transcript verifiziert"
  elseif tag == "[WV]" then return "Web-verified: Controls/Features aus Listings/Quellen verifiziert"
  elseif tag == "[PM]" then return "Partial-manual: Manual vorhanden, aber (noch) nicht vollständig gemappt"
  else return "Unverified: benötigt Manual/Foto/Video/Web-Quelle"
  end
end

local function draw_param_matrix_tooltip(ctx, prof)
  if type(prof) ~= "table" then return end
  local cc = prof.controls_contextual
  if type(cc) ~= "table" then return end
  local pm = cc.param_matrix
  if type(pm) ~= "table" then return end

  r.ImGui_Separator(ctx)
  r.ImGui_Text(ctx, "Mode Cheatsheet:")
  -- show Type positions if present
  local tp = cc.type_knob_positions
  if type(tp) == "table" and #tp > 0 then
    r.ImGui_Text(ctx, "Type/GEAR:")
    for _, it in ipairs(tp) do
      local line = ("%d: %s"):format(tonumber(it.index) or 0, tostring(it.mode or it.label or ""))
      r.ImGui_BulletText(ctx, line)
    end
  end

  for mode, params in pairs(pm) do
    r.ImGui_Text(ctx, tostring(mode) .. ":")
    local p1 = params.param1 or "-"
    local p2 = params.param2 or "-"
    local p3 = params.param3 or "-"
    r.ImGui_BulletText(ctx, "Param1: " .. tostring(p1))
    r.ImGui_BulletText(ctx, "Param2: " .. tostring(p2))
    r.ImGui_BulletText(ctx, "Param3: " .. tostring(p3))
  end
end

local function find_patchbay_device_name(profile)
  -- preferred: explicit mapping
  if profile and profile.patchbay_name and profile.patchbay_name ~= "" then return profile.patchbay_name end
  -- fallback: best-effort match against patchbay header names (contains match)
  if not patch_data then return nil end
  local candidates = Engine.list_devices_common(patch_data)
  local target = norm((profile and profile.name_de) or "")
  for _, name in ipairs(candidates) do
    local n = norm(name)
    if n == target then return name end
  end
  for _, name in ipairs(candidates) do
    local n = norm(name)
    if target:find(n, 1, true) or n:find(target, 1, true) then return name end
  end
  return nil
end

-- ---------- Simple role->device suggestions ----------
local function suggest_devices_for_role(role, query)
  -- very simple heuristic: match role keywords in name/notes/tech
  local out = {}
  local q = norm(query)
  for _, d in ipairs(profiles_list) do
    local id = d.id
    local name = d.name_de or ""
    if q ~= "" and not norm(name):find(q, 1, true) then goto continue end
    -- load profile lazily only when likely
    local prof = load_profile(id)
    if type(prof) ~= "table" then goto continue end
    local blob = norm(name .. " " .. (prof.notes_raw_de or "") .. " " .. (prof.tech_raw_de or "") .. " " .. (prof.controls_raw_de or ""))
    if blob:find(norm(role), 1, true) or blob:find(role:gsub("_"," "), 1, true) then
      out[#out+1] = {id=id, name=name, panel_verified=bool(prof and (prof.controls_verified_by_image or (prof.meta and prof.meta.panel_verified))), tag=verif_tag(prof), prof=prof}
    else
      -- keyword hints
      local kw = {
        gate={"gate","expander"},
        compressor={"compress","kompressor","comp"},
        lofi={"lofi","bit","crusher","crush","degrade"},
        bitcrusher={"bit","crusher"},
        ring_mod={"ring","ringmod"},
        pitch={"pitch","whammy","oct","shifter"},
        chorus={"chorus","uni","vibe","vibrato"},
        phaser={"phaser"},
        delay={"delay","echo"},
        reverb={"reverb","hall"},
        tremolo={"tremolo"},
        modulation={"chorus","phaser","flanger","vibrato","univibe","mod"},
        envelope={"attack","decay","envelope","filter"},
        reamp={"reamp","daccapo"},
        di={"di400","di "},
        patchbay={"patchulator","patchbay","patch"},
      }
      local keys = kw[role] or kw["modulation"] or {}
      for _, k in ipairs(keys) do
        if blob:find(k, 1, true) then
          out[#out+1] = {id=id, name=name, panel_verified=bool(prof and (prof.controls_verified_by_image or (prof.meta and prof.meta.panel_verified))), tag=verif_tag(prof), prof=prof}
          break
        end
      end
    end
    ::continue::
  end
  table.sort(out, function(a,b)
    if a.panel_verified ~= b.panel_verified then return a.panel_verified and not b.panel_verified end
    return a.name < b.name
  end)
  return out
end

-- ---------- Track builder ----------
local function add_hw_send_return_tracks(chain_name, patchbay_device_name, mode, build_method, open_reainsert_ui)
  return SafeApply.run("IFLS: IFLS Workbench Chain Builder Wizard", function()
local idx = r.CountTracks(0)

  -- Folder (optional)
  r.InsertTrackAtIndex(idx, true)
  local folder = r.GetTrack(0, idx)
  r.GetSetMediaTrackInfo_String(folder, "P_NAME", "HW Chain: " .. chain_name, true)
  r.SetMediaTrackInfo_Value(folder, "I_FOLDERDEPTH", 1)

  -- Send track
  r.InsertTrackAtIndex(idx+1, true)
  local send_tr = r.GetTrack(0, idx+1)
  r.GetSetMediaTrackInfo_String(send_tr, "P_NAME", chain_name .. " (Send)", true)
  r.SetMediaTrackInfo_Value(send_tr, "B_MAINSEND", 0)

  -- Return track
  r.InsertTrackAtIndex(idx+2, true)
  local ret_tr = r.GetTrack(0, idx+2)
  r.GetSetMediaTrackInfo_String(ret_tr, "P_NAME", chain_name .. " (Return)", true)

  -- Close folder
  r.InsertTrackAtIndex(idx+3, true)
  local end_tr = r.GetTrack(0, idx+3)
  r.GetSetMediaTrackInfo_String(end_tr, "P_NAME", "(end)", true)
  r.SetMediaTrackInfo_Value(end_tr, "I_FOLDERDEPTH", -1)
  r.SetMediaTrackInfo_Value(end_tr, "B_MAINSEND", 0)

  -- Routing suggestion from patchbay
  if patch_data and patchbay_device_name and patchbay_device_name ~= "" then
    local out_map = Engine.get_device_map(patch_data.outputs, patchbay_device_name) or {}
    local in_map  = Engine.get_device_map(patch_data.inputs,  patchbay_device_name) or {}

    local outL, outR, outWhy
    local inL, inR, inWhy

    if mode == "stereo" then
      outL,outR,outWhy = Engine.suggest_stereo_channels(out_map)
      inL,inR,inWhy = Engine.suggest_stereo_channels(in_map)
    else
      outL = Engine.suggest_mono_channel(out_map)
      inL = Engine.suggest_mono_channel(in_map)
    end

    if outL and inL then
      -- HW out send on send_tr
      Engine.add_hw_out_send(send_tr, outL, mode)
      -- HW input on return track
      Engine.set_track_hw_input(ret_tr, inL)
      -- Notes
      local out_txt = (mode=="stereo") and (tostring(outL).."/"..tostring(outR)) or tostring(outL)
      local in_txt  = (mode=="stereo") and (tostring(inL).."/"..tostring(inR)) or tostring(inL)
      local notes = ("IFLS Chain Builder\nPatchbay device: %s\nMode: %s\nHW OUT: %s\nHW IN: %s\n"):format(patchbay_device_name, mode, out_txt, in_txt)
      r.GetSetMediaTrackInfo_String(send_tr, "P_NOTES", notes, true)
      r.GetSetMediaTrackInfo_String(ret_tr, "P_NOTES", notes, true)
    end
  end

  if build_method == "reainsert" or build_method == "both" then
    Engine.add_reainsert_fx(send_tr, open_reainsert_ui)
  end

  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
end)
end

-- ---------- UI ----------
local ctx = r.ImGui_CreateContext("IFLS Workbench - Chain Builder Wizard")

local chain_selected = chain_files[1]
local chain_obj = nil
local chain_err = nil

local mode = "stereo"
local build_method = "tracks" -- tracks / reainsert / both
local open_reainsert_ui = true

local routing_search = ""
local routing_selected = nil

local role_picks = {} -- role -> {id,name}
local role_search = {}
local role_candidates = {}

local function reload_chain()
  chain_obj, chain_err = nil, nil
  if chain_selected then
    chain_obj, chain_err = load_chain(chain_selected)
  end
  role_picks = {}
  role_search = {}
  role_candidates = {}
end

reload_chain()

local function list_routing_candidates()
  if not patch_data then return {} end
  local list = Engine.list_devices_common(patch_data)
  local q = norm(routing_search)
  if q == "" then return list end
  local out = {}
  for _, n in ipairs(list) do
    if norm(n):find(q, 1, true) then out[#out+1] = n end
  end
  return out
end

local function build_notes(chain)
  local lines = {}
  lines[#lines+1] = "IFLS Chain Preset\n"
  lines[#lines+1] = "ID: " .. tostring(chain.id or chain_selected) .. "\n"
  if chain.intent_de then lines[#lines+1] = "Intent (DE): " .. chain.intent_de .. "\n" end
  if chain.intent_en then lines[#lines+1] = "Intent (EN): " .. chain.intent_en .. "\n" end
  if chain.routing_template then lines[#lines+1] = "Routing: " .. chain.routing_template .. "\n" end
  lines[#lines+1] = "\nRoles:\n"
  for _, role in ipairs(chain.recommended_roles or {}) do
    local pick = role_picks[role]
    if pick then
      lines[#lines+1] = "- " .. role .. " -> " .. pick.name .. "\n"
    else
      lines[#lines+1] = "- " .. role .. " -> (unassigned)\n"
    end
  end
  return table.concat(lines)
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 980, 680, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "Chain Builder Wizard", true)

  if visible then
    if patch_err then
      r.ImGui_TextColored(ctx, 1,0.3,0.3,1, "Patchbay error: " .. tostring(patch_err))
    end
    if idx_err then
      r.ImGui_TextColored(ctx, 1,0.3,0.3,1, "Profiles index error: " .. tostring(idx_err))
    end

    -- Chain preset selection
    r.ImGui_Text(ctx, "Chain preset:")
    if r.ImGui_BeginCombo(ctx, "##chain", chain_selected or "(none)") then
      for _, f in ipairs(chain_files) do
        if r.ImGui_Selectable(ctx, f, f == chain_selected) then
          chain_selected = f
          reload_chain()
        end
      end
      r.ImGui_EndCombo(ctx)
    end

    if chain_err then
      r.ImGui_TextColored(ctx, 1,0.3,0.3,1, "Chain load error: " .. tostring(chain_err))
    end

    r.ImGui_Separator(ctx)

    -- Mode + Build method
    r.ImGui_Text(ctx, "Mode:")
    r.ImGui_SameLine(ctx)
    local stereo = (mode == "stereo")
    if r.ImGui_RadioButton(ctx, "Stereo", stereo) then mode = "stereo" end
    r.ImGui_SameLine(ctx)
    if r.ImGui_RadioButton(ctx, "Mono", not stereo) then mode = "mono" end

    r.ImGui_SameLine(ctx, 0, 20)
    r.ImGui_Text(ctx, "Build:")
    r.ImGui_SameLine(ctx)
    if r.ImGui_BeginCombo(ctx, "##build", build_method) then
      if r.ImGui_Selectable(ctx, "tracks", build_method=="tracks") then build_method="tracks" end
      if r.ImGui_Selectable(ctx, "reainsert", build_method=="reainsert") then build_method="reainsert" end
      if r.ImGui_Selectable(ctx, "both", build_method=="both") then build_method="both" end
      r.ImGui_EndCombo(ctx)
    end
    r.ImGui_SameLine(ctx)
    local _, oui = r.ImGui_Checkbox(ctx, "Open ReaInsert UI", open_reainsert_ui)
    open_reainsert_ui = oui

    r.ImGui_Separator(ctx)

    -- Routing device selection (patchbay)
    r.ImGui_Text(ctx, "Routing device (Patchbay header):")
    local _, rs = r.ImGui_InputText(ctx, "Search routing", routing_search)
    routing_search = rs

    local routing_list = list_routing_candidates()
    if r.ImGui_BeginListBox(ctx, "##routing", -1, 140) then
      for _, name in ipairs(routing_list) do
        local sel = (routing_selected == name)
        if r.ImGui_Selectable(ctx, name, sel) then
          routing_selected = name
        end
      end
      r.ImGui_EndListBox(ctx)
    end

    r.ImGui_Separator(ctx)

    -- Roles assignment
    r.ImGui_Text(ctx, "Role assignment (Controls EN / Notes DE):")

    r.ImGui_SameLine(ctx, 0, 20)
    r.ImGui_TextDisabled(ctx, "[MR]/[PV]/[VV]/[WV]/[PM]")
    if r.ImGui_IsItemHovered(ctx) then
      r.ImGui_BeginTooltip(ctx)
      r.ImGui_Text(ctx, "Verification tags:")
      r.ImGui_Text(ctx, "[MR] Manual-rich (deep manual mapping)")
      r.ImGui_Text(ctx, "[PV] Panel-verified (photo/panel ground truth)")
      r.ImGui_Text(ctx, "[VV] Video-verified (transcript)")
      r.ImGui_Text(ctx, "[WV] Web-verified (listings/sources)")
      r.ImGui_Text(ctx, "[PM] Partial-manual (incomplete)")
      r.ImGui_EndTooltip(ctx)
    end

    if chain_obj and chain_obj.recommended_roles then
      if r.ImGui_BeginChild(ctx, "roles", 0, 290, true) then
        for _, role in ipairs(chain_obj.recommended_roles) do
          r.ImGui_Separator(ctx)
          r.ImGui_Text(ctx, "Role: " .. role)

          local pick = role_picks[role]
          r.ImGui_SameLine(ctx, 0, 20)
          if pick then
            local tag = pick.tag or "[?]"
            r.ImGui_Text(ctx, "Pick: " .. (pick.name or pick.id or "(none)") .. " " .. tag)
            if r.ImGui_IsItemHovered(ctx) then
              last_hover_prof = pick and pick.prof or last_hover_prof
              r.ImGui_BeginTooltip(ctx)
              r.ImGui_Text(ctx, verif_tooltip_text(tag))
              draw_param_matrix_tooltip(ctx, pick and pick.prof)
              r.ImGui_EndTooltip(ctx)
            end
          else
            r.ImGui_Text(ctx, "Pick: (none)")
          end

          r.ImGui_SameLine(ctx, 0, 20)
          local _, q = r.ImGui_InputText(ctx, "Search##"..role, role_search[role] or "")
          role_search[role] = q

          r.ImGui_SameLine(ctx)
          if r.ImGui_Button(ctx, "Suggest##"..role) then
            role_candidates[role] = suggest_devices_for_role(role, role_search[role] or "")
          end

          local cand = role_candidates[role] or {}
          if #cand > 0 then
            if r.ImGui_BeginListBox(ctx, "##cand_"..role, -1, 90) then
              for i = 1, math.min(#cand, 25) do
                local c = cand[i]
                local tag = c.tag or "[?]"
                if r.ImGui_Selectable(ctx, c.name .. " " .. tag .. "##" .. c.id, false) then
                  role_picks[role] = c
                end
                if r.ImGui_IsItemHovered(ctx) then
                  last_hover_prof = c and c.prof or last_hover_prof
                  r.ImGui_BeginTooltip(ctx)
                  r.ImGui_Text(ctx, verif_tooltip_text(tag))
                  draw_param_matrix_tooltip(ctx, c and c.prof)
                  r.ImGui_EndTooltip(ctx)
                end
              end
              r.ImGui_EndListBox(ctx)
            end
          else
            r.ImGui_Text(ctx, "(Click Suggest to get candidates)")
          end
        end
        r.ImGui_EndChild(ctx)
      end
    else
      r.ImGui_Text(ctx, "(No roles in preset)")
    end

    r.ImGui_Separator(ctx)

    -- Apply
    local can_apply = (routing_selected ~= nil and routing_selected ~= "" and chain_obj ~= nil)
    if not can_apply then r.ImGui_BeginDisabled(ctx, true) end
    if r.ImGui_Button(ctx, "Create HW Chain Tracks") then
      local chain_name = chain_obj.id or chain_selected or "chain"
      local ok = add_hw_send_return_tracks(chain_name, routing_selected, mode, build_method, open_reainsert_ui)
      if ok then
        -- write notes into folder track (top track is last inserted block start: we inserted 4 tracks at end of project)
        -- best effort: set notes on folder created (track count - 4)
        local tc = r.CountTracks(0)
        local folder = r.GetTrack(0, tc - 4)
        if folder then
          r.GetSetMediaTrackInfo_String(folder, "P_NOTES", build_notes(chain_obj), true)
        end
      end
    end
    if not can_apply then
      r.ImGui_EndDisabled(ctx)
      r.ImGui_Text(ctx, "Select a chain preset and a routing device to enable.")
    end

    r.ImGui_SameLine(ctx)
    if chain_obj then
      if r.ImGui_Button(ctx, "Copy notes") then
        local text = build_notes(chain_obj)
        if r.ImGui_SetClipboardText then
          r.ImGui_SetClipboardText(ctx, text)
        else
          r.ShowConsoleMsg(text .. "\n")
        end
      end
    end

    r.ImGui_End(ctx)
  end

  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
    -- ---------- Chain Presets / Use-Cases ----------
    if r.ImGui_CollapsingHeader(ctx, "Chain Presets", r.ImGui_TreeNodeFlags_DefaultOpen()) then
      if chain_db_err then
        r.ImGui_TextColored(ctx, 1, 0.4, 0.4, 1, "ERROR: " .. tostring(chain_db_err))
      end

      local uc_items = {}
      for i, uc in ipairs(chain_db.use_cases or {}) do
        uc_items[i] = (uc.name_de or uc.name_en or uc.id or ("use_case_"..i))
      end
      if #uc_items == 0 then
        r.ImGui_TextDisabled(ctx, "No use-cases found. Put chain_presets.json into Data/IFLS_Workbench/chains/.")
      else
        local changed_uc; changed_uc, selected_use_case = r.ImGui_Combo(ctx, "Use-Case", selected_use_case, table.concat(uc_items, "\0") .. "\0")
        local uc = chain_db.use_cases[selected_use_case]
        if uc then
          r.ImGui_TextWrapped(ctx, uc.description_de or uc.description_en or "")
        end

        local prs = presets_for_use_case(uc and uc.id or "")
        if #prs == 0 then
          r.ImGui_TextDisabled(ctx, "No presets for this use-case.")
        else
          local pr_items = {}
          for i, pr in ipairs(prs) do
            pr_items[i] = pr.name_de or pr.name_en or pr.id or ("preset_"..i)
          end
          if selected_preset > #pr_items then selected_preset = 1 end
          local changed_pr; changed_pr, selected_preset = r.ImGui_Combo(ctx, "Preset", selected_preset, table.concat(pr_items, "\0") .. "\0")

          local pr = prs[selected_preset]
          if pr then
            r.ImGui_TextWrapped(ctx, pr.signal_flow_de or pr.signal_flow_en or "")
            if pr.recommended_routing and pr.recommended_routing.notes_de then
              r.ImGui_TextWrapped(ctx, "Routing: " .. tostring(pr.recommended_routing.mode or "") .. " — " .. pr.recommended_routing.notes_de)
            end

            if r.ImGui_Button(ctx, "Load preset into builder") then
              load_preset_into_builder(pr)
            end
            r.ImGui_SameLine(ctx)
            
            if pr.patch_instructions_de and pr.patch_instructions_de ~= "" then
              r.ImGui_SameLine(ctx)
              if r.ImGui_Button(ctx, "Copy patch instructions") then
                r.ImGui_SetClipboardText(ctx, pr.patch_instructions_de)
              end
            end
if r.ImGui_Button(ctx, "Copy preset summary") then
              local out = {}
              out[#out+1] = (pr.name_de or pr.id or "Preset")
              out[#out+1] = pr.signal_flow_de or ""
              out[#out+1] = ""
              for _, st in ipairs(pr.steps or {}) do
                local line = ("- %s: %s"):format(tostring(st.role), tostring(st.device_id or ""))
                if st.note_de and st.note_de ~= "" then line = line .. " — " .. st.note_de end
                out[#out+1] = line
              end
              r.ImGui_SetClipboardText(ctx, table.concat(out, "\n"))
            end

            if r.ImGui_TreeNode(ctx, "Steps") then
              for _, st in ipairs(pr.steps or {}) do
                r.ImGui_BulletText(ctx, ("%s → %s"):format(tostring(st.role), tostring(st.device_id or "auto")))
                if st.note_de and st.note_de ~= "" then
                  r.ImGui_Indent(ctx); r.ImGui_TextWrapped(ctx, st.note_de); r.ImGui_Unindent(ctx)
                end
                
                if st.pedal_settings_de and st.pedal_settings_de ~= "" then
                  r.ImGui_Indent(ctx)
                  r.ImGui_TextWrapped(ctx, "Settings: " .. st.pedal_settings_de)
                  r.ImGui_Unindent(ctx)
                end
if st.knob_hints and next(st.knob_hints) ~= nil then
                  r.ImGui_Indent(ctx)
                  for k, v in pairs(st.knob_hints) do
                    r.ImGui_Text(ctx, ("%s: %s (~%d%%)"):format(tostring(k), pct_to_clock(v), tonumber(v) or 0))
                  end
                  r.ImGui_Unindent(ctx)
                end
              end
              r.ImGui_TreePop(ctx)

            
            -- ---------- V43 Hardware Parallel + Pedal FX Loops ----------
            local function draw_step_list(title, steps)
              if not steps or #steps == 0 then return end
              if r.ImGui_TreeNode(ctx, title) then
                for _, st in ipairs(steps) do
                  r.ImGui_BulletText(ctx, ("%s → %s"):format(tostring(st.role or ""), tostring(st.device_id or "")))
                  if st.note_de and st.note_de ~= "" then
                    r.ImGui_Indent(ctx); r.ImGui_TextWrapped(ctx, st.note_de); r.ImGui_Unindent(ctx)
                  end
                  if st.pedal_settings_de and st.pedal_settings_de ~= "" then
                    r.ImGui_Indent(ctx); r.ImGui_TextWrapped(ctx, "Settings: " .. st.pedal_settings_de); r.ImGui_Unindent(ctx)
                  end
                end
                r.ImGui_TreePop(ctx)
              end
            end

            local function draw_hardware_parallel(hp)
              if type(hp) ~= "table" then return end
              if r.ImGui_TreeNode(ctx, "Hardware Parallel (Portal)") then
                r.ImGui_TextWrapped(ctx, "Device: " .. tostring(hp.device or ""))
                if hp.notes_de and hp.notes_de ~= "" then r.ImGui_TextWrapped(ctx, hp.notes_de) end
                if hp.loopA then
                  draw_step_list("Loop A", hp.loopA.steps or {})
                  if hp.loopA.mix_hint_de then r.ImGui_TextWrapped(ctx, "Loop A mix hint: " .. hp.loopA.mix_hint_de) end
                end
                if hp.loopB then
                  draw_step_list("Loop B", hp.loopB.steps or {})
                  if hp.loopB.mix_hint_de then r.ImGui_TextWrapped(ctx, "Loop B mix hint: " .. hp.loopB.mix_hint_de) end
                end
                r.ImGui_TreePop(ctx)
              end
            end

            local function draw_fx_loop(st)
              if type(st) ~= "table" then return end
              local fl = st.fx_loop
              if type(fl) ~= "table" then return end
              if r.ImGui_TreeNode(ctx, "Pedal FX Loop (Send/Return)") then
                if fl.notes_de and fl.notes_de ~= "" then r.ImGui_TextWrapped(ctx, fl.notes_de) end
                draw_step_list("Insert chain (inside pedal)", fl.insert_steps or {})
                r.ImGui_TreePop(ctx)
              end
            end
-- ---------- V40 Pre/Post VST Chains ----------
            local function draw_fx_chain(title, chain)
              if chain and #chain > 0 then
                if r.ImGui_TreeNode(ctx, title) then
                  for i, fx in ipairs(chain) do
                    r.ImGui_BulletText(ctx, ("%d) %s"):format(i, tostring(fx.fx_name or "")))
                    if fx.fx_ident and fx.fx_ident ~= "" then
                      r.ImGui_Indent(ctx); r.ImGui_TextWrapped(ctx, "ident: " .. tostring(fx.fx_ident)); r.ImGui_Unindent(ctx)
                    end
                    if fx.notes_de and fx.notes_de ~= "" then
                      r.ImGui_Indent(ctx); r.ImGui_TextWrapped(ctx, fx.notes_de); r.ImGui_Unindent(ctx)
                    end
                    if fx.params and next(fx.params) ~= nil then
                      r.ImGui_Indent(ctx)
                      for k, v in pairs(fx.params) do
                        r.ImGui_Text(ctx, ("%s: %s"):format(tostring(k), tostring(v)))
                      end
                      r.ImGui_Unindent(ctx)
                    end
                  end
                  r.ImGui_TreePop(ctx)
                end
              end
            end

            draw_fx_chain("VST/JSFX chain (pre) — before ReaInsert", pr.pre_fx_chain or {})
            draw_fx_chain("VST/JSFX chain (post) — after hardware return", pr.post_fx_chain or {})
            draw_hardware_parallel(pr.hardware_parallel)

            if pr.patch_instructions_de and pr.patch_instructions_de ~= "" then
              if r.ImGui_TreeNode(ctx, "Patch instructions") then
                r.ImGui_TextWrapped(ctx, pr.patch_instructions_de)
                r.ImGui_TreePop(ctx)
              end
            end

            -- V40: replaced reaper_fx_chain block
-- if pr.reaper_fx_chain and #pr.reaper_fx_chain > 0 then
              if r.ImGui_TreeNode(ctx, "Reaper FX chain (after hardware)") then
                for i, fx in ipairs(pr.reaper_fx_chain) do
                  r.ImGui_BulletText(ctx, ("%d) %s"):format(i, tostring(fx.fx_name or "")))

                  if fx.fx_ident and fx.fx_ident ~= "" then
                    r.ImGui_Indent(ctx); r.ImGui_TextWrapped(ctx, "ident: " .. tostring(fx.fx_ident)); r.ImGui_Unindent(ctx)
                  end
                  if fx.notes_de and fx.notes_de ~= "" then
                    r.ImGui_Indent(ctx); r.ImGui_TextWrapped(ctx, fx.notes_de); r.ImGui_Unindent(ctx)
                  end
                  if fx.params and next(fx.params) ~= nil then
                    r.ImGui_Indent(ctx)
                    for k, v in pairs(fx.params) do
                      r.ImGui_Text(ctx, ("%s: %s"):format(tostring(k), tostring(v)))
                    end
                    r.ImGui_Unindent(ctx)
                  end
                end
                r.ImGui_TreePop(ctx)
              end
            end
            end
          end
        end
      end
    end

