-- @description M350 Preset Editor (ReaImGui) - edit m350_presets.json with a proper UI
-- @version 1.0
-- @author Reaper DAW Ultimate Assistant
-- @about
--   Requires ReaImGui (cfillion). Provides a list, text fields, add/delete, save/reload.
--   Edits: Scripts/IFLS_Workbench/Workbench/M350/Data/m350_presets.json

local SCRIPT_DIR = ({reaper.get_action_context()})[2]:match("^(.*)[/\\]")
local PRESET_JSON = SCRIPT_DIR .. "/../Workbench/M350/Data/m350_presets.json"
local EXT_SECTION = "IFLS_M350_PRESETEDITOR"

-- ---------- small JSON (string map) helpers ----------
local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function file_exists(p) local f=io.open(p,"rb"); if f then f:close(); return true end return false end

local function json_unescape(s)
  s = s:gsub("\\\\","\\")
  s = s:gsub('\\"','"')
  s = s:gsub("\\n","\n")
  s = s:gsub("\\r","\r")
  s = s:gsub("\\t","\t")
  return s
end

local function json_escape(s)
  s = tostring(s or "")
  s = s:gsub("\\","\\\\")
  s = s:gsub('"','\\"')
  s = s:gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")
  return s
end

local function read_preset_json(path)
  local map = {}
  if not file_exists(path) then return map end
  local f = io.open(path, "rb"); if not f then return map end
  local txt = f:read("*a"); f:close()
  for k,v in txt:gmatch('"%s*([^"]+)%s*"%s*:%s*"%s*([^"]-)%s*"') do
    map[trim(k)] = json_unescape(v)
  end
  return map
end

local function write_preset_json(path, map)
  local keys = {}
  for k,_ in pairs(map) do keys[#keys+1]=k end
  table.sort(keys, function(a,b)
    local na, nb = tonumber(a), tonumber(b)
    if na and nb then return na < nb end
    return tostring(a) < tostring(b)
  end)
  local out = {"{\n"}
  for i,k in ipairs(keys) do
    local v = map[k] or ""
    out[#out+1] = string.format('  "%s": "%s"%s\n', json_escape(k), json_escape(v), (i<#keys) and "," or "")
  end
  out[#out+1] = "}\n"
  local f = io.open(path, "wb"); if not f then return false end
  f:write(table.concat(out)); f:close()
  return true
end

-- ---------- ReaImGui UI ----------
local ctx = reaper.ImGui_CreateContext('M350 Preset Editor')
local sizeX, sizeY = 720, 520
local map = read_preset_json(PRESET_JSON)

-- row buffers
local buf = {} -- [key] = string
local function refresh_buffers()
  buf = {}
  for k,v in pairs(map) do buf[k]=tostring(v or "") end
end
refresh_buffers()

local function sorted_keys()
  local keys={}
  for k,_ in pairs(map) do keys[#keys+1]=k end
  table.sort(keys, function(a,b)
    local na, nb = tonumber(a), tonumber(b)
    if na and nb then return na < nb end
    return tostring(a) < tostring(b)
  end)
  return keys
end

local function set_status(msg)
  reaper.SetExtState(EXT_SECTION, "status", msg or "", false)
end
local function get_status()
  return reaper.GetExtState(EXT_SECTION, "status") or ""
end

-- add preset UI state
local add_num = tonumber(reaper.GetExtState(EXT_SECTION,"add_num")) or 1
local add_name = reaper.GetExtState(EXT_SECTION,"add_name") or ""

local function loop()
  reaper.ImGui_SetNextWindowSize(ctx, sizeX, sizeY, reaper.ImGui_Cond_FirstUseEver())
  local visible, open = reaper.ImGui_Begin(ctx, 'M350 Preset Editor', true,
    reaper.ImGui_WindowFlags_NoCollapse())

  if visible then
    reaper.ImGui_Text(ctx, 'File: ' .. PRESET_JSON)

    -- top buttons
    if reaper.ImGui_Button(ctx, 'Reload') then
      map = read_preset_json(PRESET_JSON)
      refresh_buffers()
      set_status("Reloaded.")
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, 'Save') then
      -- commit buffers
      for k,v in pairs(buf) do map[k]=v end
      local ok = write_preset_json(PRESET_JSON, map)
      set_status(ok and "Saved." or "Save FAILED (file locked?)")
    end
    reaper.ImGui_SameLine(ctx)
    if reaper.ImGui_Button(ctx, 'Sort keys') then
      -- no-op; sorting happens on save, but we set status for clarity
      set_status("Sorting applies on Save.")
    end

    reaper.ImGui_Separator(ctx)

    -- Add section
    reaper.ImGui_Text(ctx, 'Add / Update Preset')
    local changed
    changed, add_num = reaper.ImGui_InputInt(ctx, 'Preset #', add_num)
    if changed then reaper.SetExtState(EXT_SECTION,"add_num", tostring(add_num), false) end
    changed, add_name = reaper.ImGui_InputText(ctx, 'Name', add_name)
    if changed then reaper.SetExtState(EXT_SECTION,"add_name", add_name, false) end
    if reaper.ImGui_Button(ctx, 'Add/Update') then
      local k = tostring(math.max(1, math.min(128, add_num)))
      map[k] = add_name
      buf[k] = add_name
      set_status("Added/updated preset " .. k)
    end

    reaper.ImGui_Separator(ctx)

    -- Table
    local flags = reaper.ImGui_TableFlags_Borders() | reaper.ImGui_TableFlags_RowBg() |
                  reaper.ImGui_TableFlags_Resizable() | reaper.ImGui_TableFlags_ScrollY()
    if reaper.ImGui_BeginTable(ctx, 'presets', 3, flags, -1, -40) then
      reaper.ImGui_TableSetupColumn(ctx, 'Preset', reaper.ImGui_TableColumnFlags_WidthFixed(), 70)
      reaper.ImGui_TableSetupColumn(ctx, 'Name', reaper.ImGui_TableColumnFlags_WidthStretch())
      reaper.ImGui_TableSetupColumn(ctx, 'Actions', reaper.ImGui_TableColumnFlags_WidthFixed(), 120)
      reaper.ImGui_TableHeadersRow(ctx)

      for _,k in ipairs(sorted_keys()) do
        reaper.ImGui_TableNextRow(ctx)
        reaper.ImGui_TableSetColumnIndex(ctx, 0)
        reaper.ImGui_Text(ctx, k)

        reaper.ImGui_TableSetColumnIndex(ctx, 1)
        local label = '##name_' .. k
        local val = buf[k] or ""
        local rv; rv, val = reaper.ImGui_InputText(ctx, label, val)
        if rv then buf[k]=val end

        reaper.ImGui_TableSetColumnIndex(ctx, 2)
        if reaper.ImGui_Button(ctx, 'Delete##' .. k) then
          map[k]=nil; buf[k]=nil
          set_status("Deleted preset " .. k .. " (Save to commit).")
        end
      end

      reaper.ImGui_EndTable(ctx)
    end

    reaper.ImGui_Separator(ctx)
    reaper.ImGui_Text(ctx, get_status())

    reaper.ImGui_End(ctx)
  end

  if open then
    reaper.defer(loop)
  else
    reaper.ImGui_DestroyContext(ctx)
  end
end

reaper.defer(loop)
