-- @description IFLS Workbench - Tools/IFLS_Workbench_Research_Queue.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench - Research Queue (resolve unknown pedal controls)
-- @version 0.1.0
-- @author IFLS
-- @about
--   UI to track pedals with missing/unknown control coverage.
--   Reads tasklist CSV from:
--     - REAPER_RESOURCE/Data/IFLS_Workbench/Reports/unknown_pedals_tasklist.csv
--     - (fallback) REAPER_RESOURCE/Reports/V34_unknown_pedals_tasklist.csv
--   Requires ReaImGui.

local r = reaper

if not r.ImGui_CreateContext then
  r.MB("ReaImGui extension not found.\nInstall via ReaPack → ReaTeam Extensions → ReaImGui.", "IFLS Workbench", 0)
  return
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end

local function split_csv_line(line)
  -- Minimal CSV: supports quoted fields, commas, and escaped quotes ("")
  local out, i, n = {}, 1, #line
  while i <= n do
    local c = line:sub(i,i)
    if c == '"' then
      i = i + 1
      local buf = {}
      while i <= n do
        local ch = line:sub(i,i)
        if ch == '"' then
          local nx = line:sub(i+1,i+1)
          if nx == '"' then
            buf[#buf+1] = '"'
            i = i + 2
          else
            i = i + 1
            break
          end
        else
          buf[#buf+1] = ch
          i = i + 1
        end
      end
      out[#out+1] = table.concat(buf)
      if line:sub(i,i) == "," then i = i + 1 end
    else
      local j = i
      while j <= n and line:sub(j,j) ~= "," do j = j + 1 end
      out[#out+1] = line:sub(i, j-1)
      i = j + 1
    end
  end
  return out
end

local function load_tasks()
  local resource = r.GetResourcePath()
  local p1 = resource .. "/Data/IFLS_Workbench/Reports/unknown_pedals_tasklist.csv"
  local p2 = resource .. "/Reports/V34_unknown_pedals_tasklist.csv"
  local csv = read_file(p1) or read_file(p2)
  if not csv then return {}, "Tasklist CSV not found.\nExpected:\n" .. p1 end

  local lines = {}
  for line in (csv .. "\n"):gmatch("(.-)\n") do
    if line and line ~= "" then lines[#lines+1] = line end
  end
  if #lines < 2 then return {}, "Tasklist CSV empty." end

  local header = split_csv_line(lines[1])
  local col = {}
  for i, h in ipairs(header) do col[h] = i end

  local tasks = {}
  for i = 2, #lines do
    local row = split_csv_line(lines[i])
    local function get(name) return row[col[name] or -1] or "" end
    tasks[#tasks+1] = {
      id = get("id"),
      manufacturer = get("manufacturer"),
      name = get("name"),
      needs = get("needs"),
      missing_controls = get("missing_controls"),
      suggested_queries = get("suggested_queries"),
      profile_path = get("profile_path"),
    }
  end
  return tasks, nil
end

local ctx = r.ImGui_CreateContext("IFLS Research Queue")
local font = r.ImGui_CreateFont("sans-serif", 14)
r.ImGui_Attach(ctx, font)

local tasks, load_err = load_tasks()
local filter = ""
local selected = 1

local function norm(s)
  s = tostring(s or ""):lower()
  return s
end

local function matches(t, f)
  if not f or f == "" then return true end
  local hay = norm(t.manufacturer) .. " " .. norm(t.name) .. " " .. norm(t.needs) .. " " .. norm(t.missing_controls)
  return hay:find(norm(f), 1, true) ~= nil
end

local function copy_to_clipboard(text)
  r.ImGui_SetClipboardText(ctx, text or "")
end

local function open_in_explorer(rel_path)
  -- Opens REAPER resource folder location; user can navigate to file
  local resource = r.GetResourcePath()
  local full = resource .. "/" .. rel_path
  if r.GetOS():find("OSX") then
    os.execute('open "' .. full .. '"')
  elseif r.GetOS():find("Win") then
    os.execute('explorer "' .. full:gsub("/", "\\") .. '"')
  else
    os.execute('xdg-open "' .. full .. '"')
  end
end

local function draw()
  r.ImGui_PushFont(ctx, font)

  if load_err then
    r.ImGui_Text(ctx, "ERROR:")
    r.ImGui_TextWrapped(ctx, load_err)
    r.ImGui_PopFont(ctx)
    return
  end

  r.ImGui_Text(ctx, "Unknown Pedals Research Queue")
  local ch; ch, filter = r.ImGui_InputText(ctx, "Search", filter)

  if r.ImGui_BeginTable(ctx, "rq", 2, r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_RowBg() | r.ImGui_TableFlags_SizingStretchProp()) then
    r.ImGui_TableSetupColumn(ctx, "Queue", r.ImGui_TableColumnFlags_WidthStretch(), 0.45)
    r.ImGui_TableSetupColumn(ctx, "Details", r.ImGui_TableColumnFlags_WidthStretch(), 0.55)
    r.ImGui_TableHeadersRow(ctx)

    -- left: list
    r.ImGui_TableNextRow(ctx)
    r.ImGui_TableSetColumnIndex(ctx, 0)

    if r.ImGui_BeginChild(ctx, "list", 0, 0, true) then
      local visible_index = 0
      for i, t in ipairs(tasks) do
        if matches(t, filter) then
          visible_index = visible_index + 1
          local label = (t.manufacturer ~= "" and (t.manufacturer .. " – ") or "") .. (t.name ~= "" and t.name or t.id)
          if r.ImGui_Selectable(ctx, label, selected == i) then
            selected = i
          end
          if r.ImGui_IsItemHovered(ctx) then
            r.ImGui_BeginTooltip(ctx)
            r.ImGui_Text(ctx, "Needs: " .. (t.needs or ""))
            if t.missing_controls and t.missing_controls ~= "" then
              r.ImGui_Text(ctx, "Missing controls: " .. t.missing_controls)
            end
            r.ImGui_EndTooltip(ctx)
          end
        end
      end
      r.ImGui_EndChild(ctx)
    end

    -- right: details
    r.ImGui_TableSetColumnIndex(ctx, 1)
    local t = tasks[selected]
    if t then
      r.ImGui_Text(ctx, (t.manufacturer or "") .. " " .. (t.name or ""))
      r.ImGui_Separator(ctx)
      r.ImGui_TextWrapped(ctx, "Profile: " .. (t.profile_path or ""))
      r.ImGui_TextWrapped(ctx, "Needs: " .. (t.needs or ""))
      if t.missing_controls and t.missing_controls ~= "" then
        r.ImGui_TextWrapped(ctx, "Missing controls: " .. t.missing_controls)
      end

      r.ImGui_Separator(ctx)
      r.ImGui_Text(ctx, "Actions:")
      if r.ImGui_Button(ctx, "Copy search queries") then
        local out = {}
        for q in tostring(t.suggested_queries or ""):gmatch("([^|]+)") do
          q = q:gsub("^%s+",""):gsub("%s+$","")
          if q ~= "" then out[#out+1] = q end
        end
        copy_to_clipboard(table.concat(out, "\n"))
      end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "Copy issue template") then
        local out = {}
        out[#out+1] = "Profile ID: " .. (t.id or "")
        out[#out+1] = "Profile path: " .. (t.profile_path or "")
        out[#out+1] = "Needs: " .. (t.needs or "")
        if t.missing_controls and t.missing_controls ~= "" then
          out[#out+1] = "Missing controls: " .. t.missing_controls
        end
        out[#out+1] = ""
        out[#out+1] = "Suggested queries:"
        for q in tostring(t.suggested_queries or ""):gmatch("([^|]+)") do
          q = q:gsub("^%s+",""):gsub("%s+$","")
          if q ~= "" then out[#out+1] = "- " .. q end
        end
        copy_to_clipboard(table.concat(out, "\n"))
      end

      if r.ImGui_Button(ctx, "Open profile location") then
        -- Opens explorer at resource/path (may not exist if user hasn't copied files there)
        open_in_explorer(t.profile_path or "")
      end
    else
      r.ImGui_TextDisabled(ctx, "No selection.")
    end

    r.ImGui_EndTable(ctx)
  end

  r.ImGui_PopFont(ctx)
end

local function loop()
  local visible, open = r.ImGui_Begin(ctx, "IFLS Research Queue", true, r.ImGui_WindowFlags_MenuBar())
  if visible then
    draw()
    r.ImGui_End(ctx)
  end
  if open then
    r.defer(loop)
  else
    r.ImGui_DestroyContext(ctx)
  end
end

r.defer(loop)
