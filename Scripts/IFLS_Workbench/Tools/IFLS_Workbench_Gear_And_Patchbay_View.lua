-- @description IFLS Workbench - Tools/IFLS_Workbench_Gear_And_Patchbay_View.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench - Gear & Patchbay Viewer (ReaImGui)
-- @version 0.1.0
-- @author IFLS
-- @about
--   Viewer for Data/IFLS_Workbench/gear.json and patchbay.json (generated from Excel by GitHub Actions).
--   Requires ReaImGui extension (ReaTeam Extensions via ReaPack).

local r = reaper

-- ---------- tiny JSON decoder (limited but OK for our generated JSON) ----------
-- Supports: objects, arrays, strings (basic escapes), numbers, true/false/null.
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
      i = i + 1 -- skip "
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
          else
            -- \uXXXX not needed for our generator; treat literally
            out[#out+1]='\\' .. n; i=i+2
          end
        else
          out[#out+1]=c; i=i+1
        end
      end
    end

    local function parse_number()
      local s = i
      local c = str:sub(i,i)
      if c == '-' then i=i+1 end
      while str:sub(i,i):match('%d') do i=i+1 end
      if str:sub(i,i) == '.' then
        i=i+1
        while str:sub(i,i):match('%d') do i=i+1 end
      end
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
      i = i + 1 -- [
      skip()
      local arr = {}
      if str:sub(i,i) == ']' then i=i+1; return arr end
      while true do
        arr[#arr+1] = parse_value()
        skip()
        local c = str:sub(i,i)
        if c == ',' then i=i+1; skip()
        elseif c == ']' then i=i+1; return arr
        else error("Expected , or ] in array") end
      end
    end

    local function parse_object()
      i = i + 1 -- {
      skip()
      local obj = {}
      if str:sub(i,i) == '}' then i=i+1; return obj end
      while true do
        if str:sub(i,i) ~= '"' then error("Expected string key") end
        local k = parse_string()
        skip()
        if str:sub(i,i) ~= ':' then error("Expected : after key") end
        i=i+1; skip()
        obj[k] = parse_value()
        skip()
        local c = str:sub(i,i)
        if c == ',' then i=i+1; skip()
        elseif c == '}' then i=i+1; return obj
        else error("Expected , or } in object") end
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
    else error("Unexpected token at " .. i) end
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

local function norm(s)
  s = tostring(s or "")
  s = s:lower()
  return s
end

-- ---------- load data ----------
local resource = r.GetResourcePath()
local gear_path    = resource .. "/Data/IFLS_Workbench/gear.json"
local patch_path   = resource .. "/Data/IFLS_Workbench/patchbay.json"

local gear_data, patch_data
local gear_err, patch_err

local function reload_data()
  gear_err, patch_err = nil, nil

  local gs = slurp(gear_path)
  if gs then
    gear_data, gear_err = json_decode(gs)
  else
    gear_data, gear_err = nil, "gear.json not found: " .. gear_path
  end

  local ps = slurp(patch_path)
  if ps then
    patch_data, patch_err = json_decode(ps)
  else
    patch_data, patch_err = nil, "patchbay.json not found: " .. patch_path
  end
end

-- ---------- ReaImGui ----------
if not r.ImGui_CreateContext then
  r.MB("ReaImGui extension not found.\nInstall via ReaPack → ReaTeam Extensions → ReaImGui.", "IFLS Workbench", 0)
  return
end

local ctx = r.ImGui_CreateContext('IFLS Workbench - Gear & Patchbay')
local FONT_SCALE = 1.0

reload_data()

local search = ""
local filter_main = "Alle"
local filter_sub = "Alle"

local patch_only = false
local patch_search = ""

local function build_filters()
  local mains, subs = {["Alle"]=true}, {["Alle"]=true}
  if gear_data and gear_data.gear then
    for _, it in ipairs(gear_data.gear) do
      if it.main_category and it.main_category ~= "" then mains[it.main_category] = true end
      if it.sub_category and it.sub_category ~= "" then subs[it.sub_category] = true end
    end
  end
  local function keys(t)
    local a = {}
    for k in pairs(t) do a[#a+1]=k end
    table.sort(a)
    return a
  end
  return keys(mains), keys(subs)
end

local mains_list, subs_list = build_filters()

local function pass_filters(it)
  if filter_main ~= "Alle" and it.main_category ~= filter_main then return false end
  if filter_sub  ~= "Alle" and it.sub_category  ~= filter_sub  then return false end
  if search ~= "" then
    local hay = norm(it.manufacturer) .. " " .. norm(it.model) .. " " .. norm(it.category_type) .. " " ..
                norm(it.io_text) .. " " .. norm(it.notes_text) .. " " .. norm(it.tech_text)
    if not hay:find(norm(search), 1, true) then return false end
  end
  return true
end

local function mark_to_glyph(m)
  if m == "present" then return "✓"
  elseif m == "left" then return "L"
  elseif m == "right" then return "R"
  elseif m == "sidechain_in" then return "SC"
  elseif m == "none" then return "·"
  else return "?"
  end
end


local function mark_to_label(m)
  if m == "present" then return "✓ present (patched)"
  elseif m == "left" then return "L left (mono/left)"
  elseif m == "right" then return "R right (mono/right)"
  elseif m == "sidechain_in" then return "SC sidechain in"
  elseif m == "none" then return "· none / not patched"
  else return "? unknown" end
end

local function draw_mark_cell(m, scope, device_name, channel)
  local glyph = mark_to_glyph(m)
  r.ImGui_Text(ctx, glyph)

  if r.ImGui_IsItemHovered(ctx) then
    r.ImGui_BeginTooltip(ctx)
    r.ImGui_Text(ctx, string.format("%s | ch %s | %s", tostring(device_name or "?"), tostring(channel or "?"), mark_to_label(m)))
    r.ImGui_Text(ctx, "Click to copy")
    r.ImGui_EndTooltip(ctx)
  end

  if r.ImGui_IsItemClicked(ctx) then
    local line = string.format("%s: %s ch %s = %s", tostring(scope or "patch"), tostring(device_name or "?"), tostring(channel or "?"), tostring(m or "none"))
    copy_text(line)
  end
end

local function draw_patchbay_legend()
  r.ImGui_Text(ctx, "Legend:")
  r.ImGui_SameLine(ctx); r.ImGui_Text(ctx, "✓ = present")
  r.ImGui_SameLine(ctx); r.ImGui_Text(ctx, "L = left")
  r.ImGui_SameLine(ctx); r.ImGui_Text(ctx, "R = right")
  r.ImGui_SameLine(ctx); r.ImGui_Text(ctx, "SC = sidechain in")
  r.ImGui_SameLine(ctx); r.ImGui_Text(ctx, "· = none")
  if r.ImGui_IsItemHovered(ctx) then
    r.ImGui_BeginTooltip(ctx)
    r.ImGui_Text(ctx, "Hover any cell for details.")
    r.ImGui_EndTooltip(ctx)
  end
end


local function is_patched_mark(m)
  return m == "present" or m == "left" or m == "right" or m == "sidechain_in"
end

local function device_has_patch(dev)
  local map = dev.map or {}
  for _, m in pairs(map) do
    if is_patched_mark(m) then return true end
  end
  return false
end

local function dev_name_matches(dev, q)
  q = norm(q or "")
  if q == "" then return true end
  return norm(dev.name or ""):find(q, 1, true) ~= nil
end

local function copy_text(text)
  if r.ImGui_SetClipboardText then
    r.ImGui_SetClipboardText(ctx, text)
  else
    r.ShowConsoleMsg(text .. "\n")
  end
end

local function draw_patchbay_matrix(scope, title, matrix)
  if not matrix then
    r.ImGui_Text(ctx, "(keine Daten)")
    return
  end

  local channels = matrix.channels or {}
  local devices = matrix.devices or {}

  if #devices == 0 or #channels == 0 then
    r.ImGui_Text(ctx, "(Matrix leer)")
    return
  end

  -- apply device filters (optional)
  local filtered = {}
  for _, dev in ipairs(devices) do
    if (not patch_only or device_has_patch(dev)) and dev_name_matches(dev, patch_search) then
      filtered[#filtered+1] = dev
    end
  end

  if #filtered == 0 then
    r.ImGui_Text(ctx, "(keine Geräte passen zum Filter)")
    return
  end

  if r.ImGui_BeginTable(ctx, title, 1 + #filtered,
      r.ImGui_TableFlags_Borders() |
      r.ImGui_TableFlags_RowBg() |
      r.ImGui_TableFlags_ScrollX() |
      r.ImGui_TableFlags_ScrollY(),
      0, 280) then

    r.ImGui_TableSetupScrollFreeze(ctx, 1, 1)
    r.ImGui_TableSetupColumn(ctx, "Kanal", r.ImGui_TableColumnFlags_WidthFixed(), 60)

    for _, dev in ipairs(filtered) do
      r.ImGui_TableSetupColumn(ctx, dev.name or "?", r.ImGui_TableColumnFlags_WidthFixed(), 160)
    end
    r.ImGui_TableHeadersRow(ctx)

    for _, ch in ipairs(channels) do
      r.ImGui_TableNextRow(ctx)
      r.ImGui_TableSetColumnIndex(ctx, 0)
      r.ImGui_Text(ctx, tostring(ch))

      for d = 1, #filtered do
        local dev = filtered[d]
        local map = dev.map or {}
        local m = map[tostring(ch)] or "none"
        r.ImGui_TableSetColumnIndex(ctx, d)
        draw_mark_cell(m, scope, dev.name, ch)
      end
    end

    r.ImGui_EndTable(ctx)
  end
end

local function looplocal function loop()
  r.ImGui_SetNextWindowSize(ctx, 920*FONT_SCALE, 650*FONT_SCALE, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, 'IFLS Workbench - Gear & Patchbay', true,
    r.ImGui_WindowFlags_MenuBar())

  if visible then
    if r.ImGui_BeginMenuBar(ctx) then
      if r.ImGui_BeginMenu(ctx, "Daten") then
        if r.ImGui_MenuItem(ctx, "Reload JSON") then
          reload_data()
          mains_list, subs_list = build_filters()
        end
        r.ImGui_EndMenu(ctx)
      end
      r.ImGui_EndMenuBar(ctx)
    end

    if (gear_err) then r.ImGui_TextColored(ctx, 1.0, 0.3, 0.3, 1.0, "Gear-Error: " .. gear_err) end
    if (patch_err) then r.ImGui_TextColored(ctx, 1.0, 0.3, 0.3, 1.0, "Patchbay-Error: " .. patch_err) end

    if r.ImGui_BeginTabBar(ctx, "tabs") then
      -- -------- Gear tab --------
      if r.ImGui_BeginTabItem(ctx, "Gear") then
        local changed
        changed, search = r.ImGui_InputText(ctx, "Suche", search)
        r.ImGui_SameLine(ctx)

        if r.ImGui_BeginCombo(ctx, "Hauptkategorie", filter_main) then
          for _, k in ipairs(mains_list) do
            if r.ImGui_Selectable(ctx, k, k == filter_main) then filter_main = k end
          end
          r.ImGui_EndCombo(ctx)
        end
        r.ImGui_SameLine(ctx)
        if r.ImGui_BeginCombo(ctx, "Unterkategorie", filter_sub) then
          for _, k in ipairs(subs_list) do
            if r.ImGui_Selectable(ctx, k, k == filter_sub) then filter_sub = k end
          end
          r.ImGui_EndCombo(ctx)
        end

        r.ImGui_Separator(ctx)

        local items = (gear_data and gear_data.gear) or {}
        local shown = 0

        if r.ImGui_BeginChild(ctx, "gear_list", 0, 0, true) then
          for _, it in ipairs(items) do
            if pass_filters(it) then
              shown = shown + 1
              local header = string.format("[%s/%s] %s %s (x%d)",
                tostring(it.main_category or ""),
                tostring(it.sub_category or ""),
                tostring(it.manufacturer or ""),
                tostring(it.model or ""),
                tonumber(it.count or 0) or 0
              )

              if r.ImGui_CollapsingHeader(ctx, header, r.ImGui_TreeNodeFlags_DefaultOpen()) then
                if it.category_type and it.category_type ~= "" then
                  r.ImGui_Text(ctx, "Typ: " .. it.category_type)
                end
                if it.io_text and it.io_text ~= "" then
                  r.ImGui_Separator(ctx); r.ImGui_Text(ctx, "I/O:"); r.ImGui_TextWrapped(ctx, it.io_text)
                end
                if it.controls_text and it.controls_text ~= "" then
                  r.ImGui_Separator(ctx); r.ImGui_Text(ctx, "Regler:"); r.ImGui_TextWrapped(ctx, it.controls_text)
                end
                if it.power_text and it.power_text ~= "" then
                  r.ImGui_Separator(ctx); r.ImGui_Text(ctx, "Strom/Info:"); r.ImGui_TextWrapped(ctx, it.power_text)
                end
                if it.notes_text and it.notes_text ~= "" then
                  r.ImGui_Separator(ctx); r.ImGui_Text(ctx, "Notes:"); r.ImGui_TextWrapped(ctx, it.notes_text)
                end
                if it.tech_text and it.tech_text ~= "" then
                  r.ImGui_Separator(ctx); r.ImGui_Text(ctx, "Tech:"); r.ImGui_TextWrapped(ctx, it.tech_text)
                end
              end
            end
          end
          if shown == 0 then r.ImGui_Text(ctx, "(keine Treffer)") end
          r.ImGui_EndChild(ctx)
        end

        r.ImGui_EndTabItem(ctx)
      end

      -- -------- Patchbay tab --------
      if r.ImGui_BeginTabItem(ctx, "Patchbay") then
        draw_patchbay_legend()
        r.ImGui_Separator(ctx)
        local out = patch_data and patch_data.outputs
        local inp = patch_data and patch_data.inputs


        -- Filters
        local changed
        changed, patch_search = r.ImGui_InputText(ctx, "Geräte-Suche", patch_search)
        r.ImGui_SameLine(ctx)
        changed, patch_only = r.ImGui_Checkbox(ctx, "Nur gepatchte Geräte", patch_only)
        if r.ImGui_IsItemHovered(ctx) then
          r.ImGui_BeginTooltip(ctx)
          r.ImGui_Text(ctx, "Zeigt nur Geräte mit mind. einem ✓ / L / R / SC.")
          r.ImGui_EndTooltip(ctx)
        end

        r.ImGui_Separator(ctx)

        r.ImGui_Text(ctx, "Outputs")
        draw_patchbay_matrix("outputs", "outputs_matrix", out)

        r.ImGui_Separator(ctx)

        r.ImGui_Text(ctx, "Inputs")
        if inp then
          draw_patchbay_matrix("inputs", "inputs_matrix", inp)
        else
          r.ImGui_Text(ctx, "(inputs nicht im JSON vorhanden)")
        end

        r.ImGui_EndTabItem(ctx)
      end

      r.ImGui_EndTabBar(ctx)
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
