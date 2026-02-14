-- @description IFLS Workbench - Tools/IFLS_Workbench_Slicing_Control_Panel_ReaImGui.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Slicing Control Panel (ReaImGui)
-- @version 0.7.6
-- @author IFLS
-- @about
--   A single control panel UI for IFLS slicing workflows:
--   - Mode: Normal / Clicks&Pops / Drones
--   - PostFX: TailTrim (AudioAccessor) + Spread gaps (seconds or beats)
--   - Routing: Select IFLS Slices items, route-to-slices-track
--   - Advanced: optional "Dynamic Split" hook via user-provided Named Command ID
--   Requires ReaImGui extension (distributed via ReaPack in ReaTeam Extensions).
--   ReaImGui scripting pattern is based on ReaTeam templates (CreateContext + defer loop).
--   Notes:
--   - This panel *drives* existing IFLS scripts by registering/running them by file path.
--   - It persists settings in ExtState (global) so they survive REAPER restarts.
--   Install:
--     Put this file in:
--       %APPDATA%\REAPER\Scripts\IFLS_Workbench\Tools\
--     Load it once via Actions -> ReaScript -> Load...
--   Tip:
--     For best UX, dock the panel (ReaImGui supports docking).

--
--
--
--

local r = reaper

-- ---------- Dependency check ----------
if not r.ImGui_CreateContext then
  r.MB(
    "This script requires the ReaImGui extension.\n\n" ..
    "Install via ReaPack:\n" ..
    "Extensions -> ReaPack -> Browse packages -> search 'ReaImGui' and install.\n\n" ..
    "Then restart REAPER and run again.",
    "IFLS Slicing Control Panel",
    0
  )
  return
end

-- ---------- Paths to IFLS scripts ----------
local function join(a,b)
  local sep = package.config:sub(1,1)
  if a:sub(-1) == sep then return a..b end
  return a..sep..b
end

local RP = r.GetResourcePath()
local IFLS_SCRIPTS = join(join(RP, "Scripts"), "IFLS_Workbench")
local IFLS_SLICING = join(IFLS_SCRIPTS, "Slicing")
local IFLS_TOOLS   = join(IFLS_SCRIPTS, "Tools")

-- Core pipeline (from your merged repo). If you rename it, update here.
local PATH_PIPELINE = join(IFLS_SLICING, "IFLS_Workbench_Slice_Smart_Trim_And_Spread.lua")

-- Mode post processors (from ModesPack)
local PATH_SELECT_SLICES = join(IFLS_TOOLS, "IFLS_Workbench_Select_Items_On_IFLS_Slices_Tracks.lua")
local PATH_CLICKIFY      = join(IFLS_TOOLS, "IFLS_Workbench_Slicing_Clickify_SelectedItems.lua")
local PATH_DRONECHOP     = join(IFLS_TOOLS, "IFLS_Workbench_Slicing_DroneChop_SelectedItems.lua")

-- Optional routing helper (if present in your repo)
local PATH_ROUTE_TO_SLICES = join(IFLS_SLICING, "IFLS_Workbench_Slicing_Route_Selected_Items_To_IFLS_Slices_Track.lua")

-- Optional tail trim/spread tools (if your pipeline uses different filenames, adjust)
local PATH_TAILTRIM = join(IFLS_TOOLS, "IFLS_Workbench_Slicing_TailTrim_SelectedItems.lua")
local PATH_SPREAD   = join(IFLS_TOOLS, "IFLS_Workbench_Slicing_Spread_SelectedItems_With_Gaps.lua")

-- ---------- Helpers ----------
local EXT_NS = "IFLS_WORKBENCH_SLICING_PANEL"

local function get_ext(key, default)
  local v = r.GetExtState(EXT_NS, key)
  if v == nil or v == "" then return default end
  return v
end

local function set_ext(key, value)
  r.SetExtState(EXT_NS, key, tostring(value), true)
end

local function to_num(s, def)
  local n = tonumber(s)
  if n == nil then return def end
  return n
end

local function bool_to_int(b) return b and 1 or 0 end
local function int_to_bool(i) return (tonumber(i) or 0) ~= 0 end

local function file_exists(path)
  local f = io.open(path, "r")
  if f then f:close(); return true end
  return false
end

-- Register and run a script by absolute path via Action system
local function run_script(path)
  if not file_exists(path) then
    r.MB("Script not found:\n\n"..path.."\n\nCheck your installation structure.", "IFLS Panel", 0)
    return false
  end
  local cmd = r.AddRemoveReaScript(true, 0, path, true)
  if not cmd or cmd == 0 then
    r.MB("Failed to register script:\n\n"..path, "IFLS Panel", 0)
    return false
  end
  r.Main_OnCommand(cmd, 0)
  return true
end

-- Run a NamedCommand (extensions/custom actions/scripts) safely
-- NamedCommandLookup expects a string like "_XENAKIOS_SPLIT_ITEMSATRANSIENTS"
local function run_named_command(named)
  if not named or named == "" then return false end
  if named:sub(1,1) ~= "_" then named = "_" .. named end
  local id = r.NamedCommandLookup(named)
  if not id or id == 0 then
    r.MB("NamedCommand not found:\n\n"..named.."\n\nCheck spelling, and ensure the extension/script is installed.", "IFLS Panel", 0)
    return false
  end
  r.Main_OnCommand(id, 0)
  return true
end

-- Convert beats to seconds using TimeMap2 if available (native API)
local function beats_to_time(beats)
  if r.TimeMap2_beatsToTime then
    return r.TimeMap2_beatsToTime(0, beats)
  end
  return beats
end

-- ---------- State ----------
local state = {
  mode = get_ext("mode", "normal"), -- normal|clicks|drones
  prompt_postfx = int_to_bool(get_ext("prompt_postfx", "1")),

  tail_enabled = int_to_bool(get_ext("tail_enabled", "1")),
  tail_thr_db  = to_num(get_ext("tail_thr_db", "-50"), -50.0),
  tail_pad_ms  = to_num(get_ext("tail_pad_ms", "5"), 5.0),

  spread_enabled = int_to_bool(get_ext("spread_enabled", "1")),
  spread_units   = get_ext("spread_units", "seconds"), -- seconds|beats
  spread_min     = to_num(get_ext("spread_min", "1.0"), 1.0),
  spread_max     = to_num(get_ext("spread_max", "5.0"), 5.0),
  spread_random  = int_to_bool(get_ext("spread_random", "1")),
  spread_start   = get_ext("spread_start", "cursor"), -- cursor|first

  dynsplit_named = get_ext("dynsplit_named", ""), -- optional
}

local function persist_state()
  set_ext("mode", state.mode)
  set_ext("prompt_postfx", bool_to_int(state.prompt_postfx))

  set_ext("tail_enabled", bool_to_int(state.tail_enabled))
  set_ext("tail_thr_db", state.tail_thr_db)
  set_ext("tail_pad_ms", state.tail_pad_ms)

  set_ext("spread_enabled", bool_to_int(state.spread_enabled))
  set_ext("spread_units", state.spread_units)
  set_ext("spread_min", state.spread_min)
  set_ext("spread_max", state.spread_max)
  set_ext("spread_random", bool_to_int(state.spread_random))
  set_ext("spread_start", state.spread_start)

  set_ext("dynsplit_named", state.dynsplit_named)
end

-- Apply settings to existing IFLS tools (they read ExtState/ProjExtState in their own namespaces)
-- Here we "bridge" panel values by writing to the ExtState keys those tools use.
local function bridge_postfx_settings()
  -- TailTrim tool in your pack stores its own settings; we support a minimal bridge:
  -- If your TailTrim tool reads EXT_NS="IFLS_WORKBENCH_SLICING" and key "TAIL_TRIM_SETTINGS",
  -- you can uncomment below and match the exact schema.
  --
  -- Example schema: thr_db,pad_ms,win_ms,max_scan_s,min_len_ms
  -- r.SetExtState("IFLS_WORKBENCH_SLICING", "TAIL_TRIM_SETTINGS",
  --   string.format("%.6f,%.6f,10.0,12.0,15.0", state.tail_thr_db, state.tail_pad_ms), true)

  -- Spread tool schema (example): min,max,mode,start
  local mode = state.spread_random and "random" or "fixed"
  r.SetExtState("IFLS_WORKBENCH_SLICING", "SPREAD_SETTINGS",
    string.format("%.6f,%.6f,%s,%s", state.spread_min, state.spread_max, mode, state.spread_start), true)
end

-- Run the full workflow according to selected mode
local function run_mode()
  persist_state()
  bridge_postfx_settings()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  -- Always run the core pipeline first
  local ok = run_script(PATH_PIPELINE)
  if not ok then
    r.PreventUIRefresh(-1)
    r.Undo_EndBlock("IFLS: Slicing Control Panel (failed)", -1)
    return
  end

  -- Optional: run Dynamic Split hook (user-specified named command)
  if state.dynsplit_named ~= "" then
    run_named_command(state.dynsplit_named)
  end

  -- Mode-specific post
  if state.mode == "clicks" then
    run_script(PATH_SELECT_SLICES)
    run_script(PATH_CLICKIFY)
  elseif state.mode == "drones" then
    run_script(PATH_SELECT_SLICES)
    run_script(PATH_DRONECHOP)
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS: Slicing Control Panel run ("..state.mode..")", -1)
end

-- ---------- UI ----------
local ctx = r.ImGui_CreateContext("IFLS Slicing Control Panel")
local size_w, size_h = 520, 640

local function help_marker(text)
  r.ImGui_SameLine(ctx)
  r.ImGui_TextDisabled(ctx, "(?)")
  if r.ImGui_IsItemHovered(ctx) then
    r.ImGui_BeginTooltip(ctx)
    r.ImGui_PushTextWrapPos(ctx, 420)
    r.ImGui_Text(ctx, text)
    r.ImGui_PopTextWrapPos(ctx)
    r.ImGui_EndTooltip(ctx)
  end
end

local function ui_modes()
  r.ImGui_Text(ctx, "Slicing Mode")
  r.ImGui_Separator(ctx)

  local changed = false

  local v = state.mode
  local rv

  rv, changed = r.ImGui_RadioButton(ctx, "Normal", v == "normal")
  if rv then state.mode = "normal" end
  rv, _ = r.ImGui_RadioButton(ctx, "Clicks & Pops (post: Clickify micro-trims)", v == "clicks")
  if rv then state.mode = "clicks" end
  rv, _ = r.ImGui_RadioButton(ctx, "Drones (post: Glue + time chops + fades)", v == "drones")
  if rv then state.mode = "drones" end

  help_marker("Normal runs your Smart Slice pipeline.\nClicks & Pops runs pipeline, then Clickify (peak-based micro trims).\nDrones runs pipeline, then DroneChop (glue+time chops for sustained textures).")

  r.ImGui_Spacing(ctx)
  if r.ImGui_Button(ctx, "RUN (Selected Mode)", -1, 0) then
    run_mode()
  end

  r.ImGui_Spacing(ctx)
  r.ImGui_Text(ctx, "Quick Helpers")
  if r.ImGui_Button(ctx, "Select items on IFLS Slices tracks") then run_script(PATH_SELECT_SLICES) end
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, "Route selected items -> IFLS Slices track") then
    if file_exists(PATH_ROUTE_TO_SLICES) then run_script(PATH_ROUTE_TO_SLICES)
    else r.MB("Routing helper not found:\n"..PATH_ROUTE_TO_SLICES, "IFLS Panel", 0) end
  end
end

local function ui_postfx()
  r.ImGui_Text(ctx, "PostFX Settings")
  r.ImGui_Separator(ctx)

  local rv

  rv, state.prompt_postfx = r.ImGui_Checkbox(ctx, "Prompt in tools (if supported)", state.prompt_postfx)
  help_marker("Some IFLS tools may prompt for settings on run. This panel stores defaults regardless.\nIf your tool prompts every time, you can disable prompts inside the tool or adjust its settings behavior.")

  r.ImGui_Spacing(ctx)
  rv, state.tail_enabled = r.ImGui_Checkbox(ctx, "Enable TailTrim (AudioAccessor)", state.tail_enabled)
  help_marker("TailTrim trims trailing silence by scanning samples via AudioAccessor (threshold in dB + pad in ms).")

  r.ImGui_PushItemWidth(ctx, 120)
  rv, state.tail_thr_db = r.ImGui_SliderDouble(ctx, "Tail threshold (dB)", state.tail_thr_db, -90.0, -10.0, "%.1f")
  rv, state.tail_pad_ms = r.ImGui_SliderDouble(ctx, "Tail pad (ms)", state.tail_pad_ms, 0.0, 200.0, "%.1f")
  r.ImGui_PopItemWidth(ctx)

  r.ImGui_Spacing(ctx)
  rv, state.spread_enabled = r.ImGui_Checkbox(ctx, "Enable Spread gaps (reverb/delay space)", state.spread_enabled)

  -- Units selector
  if r.ImGui_BeginCombo(ctx, "Gap units", state.spread_units) then
    if r.ImGui_Selectable(ctx, "seconds", state.spread_units == "seconds") then state.spread_units = "seconds" end
    if r.ImGui_Selectable(ctx, "beats", state.spread_units == "beats") then state.spread_units = "beats" end
    r.ImGui_EndCombo(ctx)
  end
  help_marker("Seconds = absolute time gaps.\nBeats = tempo-synced gaps (converted using TimeMap2_beatsToTime).")

  r.ImGui_PushItemWidth(ctx, 140)
  rv, state.spread_min = r.ImGui_InputDouble(ctx, "Min gap", state.spread_min, 0.1, 1.0, "%.3f")
  rv, state.spread_max = r.ImGui_InputDouble(ctx, "Max gap", state.spread_max, 0.1, 1.0, "%.3f")
  r.ImGui_PopItemWidth(ctx)

  if state.spread_max < state.spread_min then state.spread_max = state.spread_min end

  rv, state.spread_random = r.ImGui_Checkbox(ctx, "Randomize between min/max", state.spread_random)

  if r.ImGui_BeginCombo(ctx, "Start reference", state.spread_start) then
    if r.ImGui_Selectable(ctx, "cursor", state.spread_start == "cursor") then state.spread_start = "cursor" end
    if r.ImGui_Selectable(ctx, "first", state.spread_start == "first") then state.spread_start = "first" end
    r.ImGui_EndCombo(ctx)
  end

  r.ImGui_Spacing(ctx)
  if r.ImGui_Button(ctx, "Apply settings (save)") then
    -- If beats, convert to seconds for tools that assume seconds.
    if state.spread_units == "beats" then
      state.spread_min = beats_to_time(state.spread_min)
      state.spread_max = beats_to_time(state.spread_max)
      state.spread_units = "seconds"
    end
    persist_state()
    bridge_postfx_settings()
  end

  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, "Run TailTrim tool now") then
    if file_exists(PATH_TAILTRIM) then run_script(PATH_TAILTRIM) else r.MB("TailTrim tool not found:\n"..PATH_TAILTRIM, "IFLS Panel", 0) end
  end
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, "Run Spread tool now") then
    if file_exists(PATH_SPREAD) then run_script(PATH_SPREAD) else r.MB("Spread tool not found:\n"..PATH_SPREAD, "IFLS Panel", 0) end
  end
end

local function ui_advanced()
  r.ImGui_Text(ctx, "Advanced Hooks")
  r.ImGui_Separator(ctx)

  r.ImGui_Text(ctx, "Optional: Dynamic Split hook")
  r.ImGui_TextWrapped(ctx,
    "If you want a Dynamic Split step in the pipeline, paste the Named Command ID of a custom action/script here.\n" ..
    "Example formats: _RSxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx or _1234abcd...\n" ..
    "This is run after the pipeline, before Clickify/DroneChop.\n"
  )
  help_marker("NamedCommandLookup is the safe way to run extension/custom actions (IDs can differ per system).")

  r.ImGui_PushItemWidth(ctx, -1)
  local rv, txt = r.ImGui_InputText(ctx, "##dynsplit", state.dynsplit_named)
  if rv then state.dynsplit_named = txt end
  r.ImGui_PopItemWidth(ctx)

  if r.ImGui_Button(ctx, "Save hook") then persist_state() end
  r.ImGui_SameLine(ctx)
  if r.ImGui_Button(ctx, "Run hook now") then run_named_command(state.dynsplit_named) end

  r.ImGui_Spacing(ctx)
  r.ImGui_Text(ctx, "Diagnostics")
  if r.ImGui_Button(ctx, "Check required scripts exist") then
    local missing = {}
    local paths = {PATH_PIPELINE, PATH_SELECT_SLICES, PATH_CLICKIFY, PATH_DRONECHOP}
    for _,p in ipairs(paths) do if not file_exists(p) then missing[#missing+1]=p end end
    if #missing == 0 then
      r.MB("All required scripts found.", "IFLS Panel", 0)
    else
      r.MB("Missing:\n\n"..table.concat(missing, "\n"), "IFLS Panel", 0)
    end
  end
end

local function frame()
  r.ImGui_SetNextWindowSize(ctx, size_w, size_h, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS Slicing Control Panel", true, r.ImGui_WindowFlags_MenuBar())

  if visible then
    if r.ImGui_BeginMenuBar(ctx) then
      if r.ImGui_BeginMenu(ctx, "File") then
        if r.ImGui_MenuItem(ctx, "Run selected mode", "Enter") then run_mode() end
        if r.ImGui_MenuItem(ctx, "Save settings") then persist_state(); bridge_postfx_settings() end
        if r.ImGui_MenuItem(ctx, "Close") then open = false end
        r.ImGui_EndMenu(ctx)
      end
      if r.ImGui_BeginMenu(ctx, "Help") then
        if r.ImGui_MenuItem(ctx, "Show install tip") then
          r.MB(
            "ReaImGui is distributed via ReaPack (ReaTeam Extensions).\n" ..
            "Install: Extensions -> ReaPack -> Browse packages -> search 'ReaImGui'.\n\n" ..
            "IFLS scripts must be in:\n" ..
            "%APPDATA%\\REAPER\\Scripts\\IFLS_Workbench\\...\n",
            "IFLS Panel Help",
            0
          )
        end
        r.ImGui_EndMenu(ctx)
      end
      r.ImGui_EndMenuBar(ctx)
    end

    if r.ImGui_BeginTabBar(ctx, "##tabs") then
      if r.ImGui_BeginTabItem(ctx, "Modes") then ui_modes(); r.ImGui_EndTabItem(ctx) end
      if r.ImGui_BeginTabItem(ctx, "PostFX") then ui_postfx(); r.ImGui_EndTabItem(ctx) end
      if r.ImGui_BeginTabItem(ctx, "Advanced") then ui_advanced(); r.ImGui_EndTabItem(ctx) end
      r.ImGui_EndTabBar(ctx)
    end

    r.ImGui_End(ctx)
  end

  if open then
    r.defer(loop)
  else
    persist_state()
    bridge_postfx_settings()
    r.ImGui_DestroyContext(ctx)
  end
end

function loop()
  frame()
end

r.defer(loop)
