-- @description M350 Ultra-Pro Tools: Preset JSON editor, Auto-Regions from PC items, Project Doctor
-- @version 1.1
-- @author Reaper DAW Ultimate Assistant
-- @about
--   Adds "Ultra-Pro" utilities on top of the M350 Wizard:
--   1) Edit preset names stored in JSON (no external deps)
--   2) Create/update regions (or markers) from MIDI items that contain Program Change for the M350
--   3) Project Doctor: detect common MIDI hazards (mioXM DIN4 multi-send collisions, likely feedback, likely double-clock)
--
--   Designed for REAPER + mioXM + TC Electronic M350.
--
--   Tips:
--   - For zero-mess MIDI, keep M350 on a fixed channel (recommend 16) and avoid OMNI.
--   - On mioXM, avoid routing DIN4 IN back to DIN4 OUT unless filtered (feedback loop).
--

-- =========================
-- Defaults (overridden by ExtState)
-- =========================
local EXT_SECTION = "IFLS_M350_ULTRAPRO"
local DEFAULT_MIDI_OUT_NAME_CONTAINS = "mioXM DIN 4"
local DEFAULT_M350_MIDI_CHANNEL = 16
local DEFAULT_CREATE_REGIONS = true -- if false: create markers at item starts instead
local DEFAULT_REGION_PREFIX = "M350: "
local DEFAULT_PRESET_JSON_REL = "../Workbench/M350/Data/m350_presets.json" -- relative to this script file

-- =========================
-- Small utilities
-- =========================
local function msg(s) reaper.ShowConsoleMsg(tostring(s) .. "\n") end
local function trim(s) return (s or ""):match("^%s*(.-)%s*$") end

local function script_dir()
  local src = debug.getinfo(1, "S").source
  if src:sub(1,1) == "@" then src = src:sub(2) end
  return src:match("^(.*)[/\\].-$")
end

local function path_join(a,b)
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then return a .. b end
  local sep = package.config:sub(1,1)
  return a .. sep .. b
end

local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close(); return true end
  return false
end

-- =========================
-- Minimal JSON (object<string,string>) reader/writer
-- This intentionally supports only: { "1": "Name", "2": "Name2" }
-- =========================
local function json_unescape(s)
  s = s:gsub('\\"','"'):gsub("\\\\","\\"):gsub("\\/","/"):gsub("\\b","\b"):gsub("\\f","\f"):gsub("\\n","\n"):gsub("\\r","\r"):gsub("\\t","\t")
  -- Unicode escapes are left as-is (rare for preset names)
  return s
end

local function json_escape(s)
  s = tostring(s or "")
  s = s:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\b","\\b"):gsub("\f","\\f"):gsub("\n","\\n"):gsub("\r","\\r"):gsub("\t","\\t")
  return s
end

local function read_preset_json(path)
  local map = {}
  if not file_exists(path) then return map end
  local f = io.open(path, "rb")
  if not f then return map end
  local txt = f:read("*a")
  f:close()
  -- crude parse for "key":"value" pairs
  for k,v in txt:gmatch('"%s*([^"]+)%s*"%s*:%s*"%s*([^"]-)%s*"') do
    map[trim(k)] = json_unescape(v)
  end
  return map
end

local function write_preset_json(path, map)
  -- stable numeric ordering where possible
  local keys = {}
  for k,_ in pairs(map) do keys[#keys+1]=k end
  table.sort(keys, function(a,b)
    local na, nb = tonumber(a), tonumber(b)
    if na and nb then return na < nb end
    return tostring(a) < tostring(b)
  end)

  local lines = {"{"}
  for i,k in ipairs(keys) do
    local v = map[k]
    local comma = (i < #keys) and "," or ""
    lines[#lines+1] = string.format('  "%s": "%s"%s', json_escape(k), json_escape(v), comma)
  end
  lines[#lines+1] = "}"
  local f = io.open(path, "wb")
  if not f then return false, "Could not write JSON: " .. tostring(path) end
  f:write(table.concat(lines, "\n"))
  f:close()
  return true
end

-- =========================
-- ExtState helpers
-- =========================
local function ext_get(key, default)
  local v = reaper.GetExtState(EXT_SECTION, key)
  if v == nil or v == "" then return default end
  return v
end

local function ext_set(key, value)
  reaper.SetExtState(EXT_SECTION, key, tostring(value or ""), true)
end

-- =========================
-- REAPER MIDI device helpers
-- =========================
local function findMidiOutIndexByName(substr)
  local cnt = reaper.GetNumMIDIOutputs()
  substr = (substr or ""):lower()
  for i=0,cnt-1 do
    local ok, name = reaper.GetMIDIOutputName(i, "")
    if ok and name and name:lower():find(substr, 1, true) then
      return i, name
    end
  end
  return nil, nil
end

local function get_track_chunk(track)
  local ok, chunk = reaper.GetTrackStateChunk(track, "", false)
  if not ok then return nil end
  return chunk
end

local function parse_midi_hwout(chunk)
  -- returns devIndex (0-based output), chan (0..15) or nil
  if not chunk then return nil end
  local dev, chan = chunk:match("\nMIDIHWOUT%s+([%-%d]+)%s+([%-%d]+)")
  if dev then return tonumber(dev), tonumber(chan) end
  return nil
end

-- =========================
-- UI: main menu
-- =========================
local function show_menu()
  gfx.init("M350 Ultra-Pro Tools", 420, 120, 0, 200, 200)
  gfx.x, gfx.y = 10, 10
  gfx.setfont(1, "Arial", 18)
  gfx.drawstr("M350 Ultra-Pro Tools\n")
  gfx.setfont(1, "Arial", 14)
  gfx.drawstr("Choose an action from the menu...\n\n")

  local last = tonumber(ext_get("last_choice", "1")) or 1
  local menu =
    "Edit preset names (JSON)|" ..
    "Create/Update regions from preset PC items|" ..
    "Project Doctor (mioXM DIN4 / clock / loop heuristics)|" ..
    "#Options|" ..
    (DEFAULT_CREATE_REGIONS and "Toggle output: Regions (default)|" or "Toggle output: Markers (default)|") ..
    "Close"

  local sel = gfx.showmenu(menu)
  gfx.quit()
  if sel == 0 then return nil end
  ext_set("last_choice", sel)
  return sel
end

-- =========================
-- 1) Preset JSON editor (menu-driven)
-- =========================
local function presets_editor(preset_path)
  local presets = read_preset_json(preset_path)

  while true do
    local ok, csv = reaper.GetUserInputs(
      "M350 Preset JSON Editor",
      3,
      "Action (list/add/update/delete),Preset number (1-99),Preset name (blank=delete)",
      "list,1,"
    )
    if not ok then return end
    local action, num, name = csv:match("^([^,]*),([^,]*),(.*)$")
    action = trim(action):lower()
    num = trim(num)
    name = trim(name)

    if action == "list" then
      reaper.ClearConsole()
      msg("M350 presets loaded from: " .. preset_path)
      local keys = {}
      for k,_ in pairs(presets) do keys[#keys+1]=k end
      table.sort(keys, function(a,b) return (tonumber(a) or 999) < (tonumber(b) or 999) end)
      for _,k in ipairs(keys) do
        msg(string.format("%s = %s", k, presets[k]))
      end
      msg("\nTip: run again with action add/update/delete.")
    elseif action == "add" or action == "update" then
      local n = tonumber(num)
      if not n or n < 1 or n > 99 then
        reaper.MB("Preset number must be 1..99", "M350 Presets", 0)
      else
        if name == "" then
          reaper.MB("Preset name cannot be blank for add/update.", "M350 Presets", 0)
        else
          presets[tostring(n)] = name
          local wOk, err = write_preset_json(preset_path, presets)
          if not wOk then reaper.MB(err or "Write failed", "M350 Presets", 0) end
        end
      end
    elseif action == "delete" then
      local n = tonumber(num)
      if not n or n < 1 or n > 99 then
        reaper.MB("Preset number must be 1..99", "M350 Presets", 0)
      else
        presets[tostring(n)] = nil
        local wOk, err = write_preset_json(preset_path, presets)
        if not wOk then reaper.MB(err or "Write failed", "M350 Presets", 0) end
      end
    else
      reaper.MB("Unknown action. Use: list / add / update / delete", "M350 Presets", 0)
    end
  end
end

-- =========================
-- 2) Auto regions from PC items
-- =========================
local function take_has_pc_on_channel(take, targetChan0)
  -- returns pcNumber (1..128) or nil; reads first PC found
  if not take or not reaper.TakeIsMIDI(take) then return nil end
  local _, _, ccs, _ = reaper.MIDI_CountEvts(take)
  for i=0, ccs-1 do
    local ok, _, _, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if ok then
      local status = chanmsg & 0xF0
      if status == 0xC0 and chan == targetChan0 then
        local program0 = msg2 or 0
        return program0 + 1, ppqpos
      end
    end
  end
  return nil
end

local function region_exists_near(pos, tol)
  tol = tol or 0.001
  local _, num = reaper.CountProjectMarkers(0)
  for i=0, num-1 do
    local rv, isrgn, rpos, rgnend, name = reaper.EnumProjectMarkers(i)
    if rv and isrgn then
      if math.abs(rpos - pos) <= tol then
        return true, name, rpos, rgnend
      end
    end
  end
  return false
end

local function marker_exists_near(pos, tol)
  tol = tol or 0.001
  local _, num = reaper.CountProjectMarkers(0)
  for i=0, num-1 do
    local rv, isrgn, rpos, rgnend, name = reaper.EnumProjectMarkers(i)
    if rv and not isrgn then
      if math.abs(rpos - pos) <= tol then
        return true, name, rpos
      end
    end
  end
  return false
end

local function take_get_pc_events(take, targetChan0)
  -- returns list of {pc=<1..128>, ppq=<number>, time=<project time>}
  local evts = {}
  local _, _, ccCount, _ = reaper.MIDI_CountEvts(take)
  for i=0, ccCount-1 do
    local ok, _, _, ppqpos, msg1, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if ok then
      local status = msg1 & 0xF0
      local chan0 = msg1 & 0x0F
      if status == 0xC0 and chan0 == targetChan0 then
        local pc = (msg2 or 0) + 1 -- convert 0..127 -> 1..128
        local time = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
        evts[#evts+1] = {pc=pc, ppq=ppqpos, time=time}
      end
    end
  end
  table.sort(evts, function(a,b) return a.time < b.time end)
  return evts
end

local function create_regions_from_pc_items(preset_path)
  local presets = read_preset_json(preset_path)

  -- load/ask settings
  local midiOutContains = ext_get("midi_out_contains", DEFAULT_MIDI_OUT_NAME_CONTAINS)
  local chan = tonumber(ext_get("m350_midi_channel", tostring(DEFAULT_M350_MIDI_CHANNEL))) or DEFAULT_M350_MIDI_CHANNEL
  chan = math.max(1, math.min(16, chan))
  local mode = ext_get("auto_region_mode", "regions") -- regions | markers | subregions | submarkers

  local ok, csv = reaper.GetUserInputs("M350 Auto-Regions", 3,
    "MIDI out contains,M350 channel (1-16),Mode (regions/markers/subregions/submarkers)",
    string.format("%s,%d,%s", midiOutContains, chan, mode)
  )
  if not ok then return end
  local a,b,c = csv:match("^([^,]*),([^,]*),([^,]*)$")
  midiOutContains = trim(a)
  chan = tonumber(trim(b)) or chan
  chan = math.max(1, math.min(16, chan))
  mode = trim(c):lower()

  ext_set("midi_out_contains", midiOutContains)
  ext_set("m350_midi_channel", chan)
  ext_set("auto_region_mode", mode)

  local targetChan0 = chan - 1

  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)

  local created, skipped, pcEvents = 0, 0, 0

  local function label_for(pc)
    local name = presets[tostring(pc)] or ("PC " .. tostring(pc))
    return DEFAULT_REGION_PREFIX .. name
  end

  for t=0, reaper.CountTracks(0)-1 do
    local tr = reaper.GetTrack(0, t)
    local itemCount = reaper.CountTrackMediaItems(tr)
    for i=0, itemCount-1 do
      local it = reaper.GetTrackMediaItem(tr, i)
      local take = reaper.GetActiveTake(it)
      if take and reaper.TakeIsMIDI(take) then
        local evts = take_get_pc_events(take, targetChan0)
        if #evts > 0 then
          local itemPos = reaper.GetMediaItemInfo_Value(it, "D_POSITION")
          local itemEnd = itemPos + reaper.GetMediaItemInfo_Value(it, "D_LENGTH")

          pcEvents = pcEvents + #evts

          if mode == "regions" or mode == "markers" then
            -- one region/marker per item: use first PC in item
            local pc = evts[1].pc
            local pos = itemPos
            local len = reaper.GetMediaItemInfo_Value(it, "D_LENGTH")
            local label = label_for(pc)

            if mode == "regions" then
              if region_exists_near(pos, 0.0005) then skipped = skipped + 1
              else reaper.AddProjectMarker2(0, true, pos, pos+len, label, -1, 0); created = created + 1 end
            else
              if marker_exists_near(pos, 0.0005) then skipped = skipped + 1
              else reaper.AddProjectMarker2(0, false, pos, 0, label, -1, 0); created = created + 1 end
            end

          else
            -- per PC event: subregions or markers at each PC
            for e=1, #evts do
              local pc = evts[e].pc
              local startTime = evts[e].time
              -- guard: if something weird, clamp inside item
              if startTime < itemPos then startTime = itemPos end
              if startTime > itemEnd then startTime = itemEnd end

              local label = label_for(pc)

              if mode == "submarkers" then
                if marker_exists_near(startTime, 0.0005) then skipped = skipped + 1
                else reaper.AddProjectMarker2(0, false, startTime, 0, label, -1, 0); created = created + 1 end
              else
                local endTime = itemEnd
                if evts[e+1] then
                  endTime = evts[e+1].time
                  if endTime < startTime then endTime = startTime end
                  if endTime > itemEnd then endTime = itemEnd end
                end
                if region_exists_near(startTime, 0.0005) then skipped = skipped + 1
                else reaper.AddProjectMarker2(0, true, startTime, endTime, label, -1, 0); created = created + 1 end
              end
            end
          end
        end
      end
    end
  end

  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock("M350: Auto create regions/markers from PC items", -1)

  reaper.MB(string.format("Done.\nPC events found: %d\nCreated: %d\nSkipped (existing): %d", pcEvents, created, skipped), "M350 Auto-Regions", 0)
end


-- =========================
-- 3) Project Doctor (heuristics)
-- =========================
local function project_doctor(preset_path)
  local midiOutContains = ext_get("midi_out_contains", DEFAULT_MIDI_OUT_NAME_CONTAINS)
  local chan = tonumber(ext_get("m350_midi_channel", tostring(DEFAULT_M350_MIDI_CHANNEL))) or DEFAULT_M350_MIDI_CHANNEL
  chan = math.max(1, math.min(16, chan))

  local devIndex, devName = findMidiOutIndexByName(midiOutContains)

  reaper.ClearConsole()
  msg("=== IFLS M350 Project Doctor (Ultra-Pro) ===")
  msg("MIDI out contains: " .. midiOutContains)
  if devIndex then
    msg("Matched MIDI output: [" .. tostring(devIndex) .. "] " .. tostring(devName))
  else
    msg("WARNING: Could not find any MIDI output containing: " .. midiOutContains)
    msg("Check Preferences > MIDI Devices, and rename your mioXM ports if needed.")
  end
  msg("Expected M350 channel (project): " .. tostring(chan) .. " (avoid OMNI on the hardware)\n")

  -- Optional: check mioXM route dump (user-provided JSON)
  local routes_rel = "../Workbench/MIDINetwork/Data/mioxm_routes.json"
  local routes_path = path_join(script_dir(), routes_rel)
  if file_exists(routes_path) then
    local f = io.open(routes_path, "rb")
    local raw = f and f:read("*a") or ""
    if f then f:close() end

    local found_loop = false
    -- very tolerant parse: find "src":"...","dst":"..."
    for src,dst in raw:gmatch('"%s*src%s*"%s*:%s*"%s*([^"]-)%s*"%s*,%s*"%s*dst%s*"%s*:%s*"%s*([^"]-)%s*"') do
      local s = trim(src):lower()
      local d = trim(dst):lower()
      if s:find("din") and s:find("in 4") and d:find("din") and d:find("out 4") then
        found_loop = true
        msg("WARNING: mioXM routes file indicates DIN IN 4 -> DIN OUT 4 route exists.")
        msg("         This can cause MIDI feedback loops if REAPER also echoes back to DIN OUT 4.")
        break
      end
    end
    if not found_loop then
      msg("mioXM routes file found: no explicit DIN IN 4 -> DIN OUT 4 route detected.")
    end
  else
    msg("mioXM route check: no routes file found (optional).")
    msg("  To enable: export your mioXM preset(s) in Auracle X and create a simple JSON:")
    msg('  ' .. routes_rel .. ' with entries like {"src":"DIN IN 4","dst":"DIN OUT 4","notes":"..."}')
  end

  -- Scan tracks for MIDIHWOUT usage
  local users = {}
  local collisions = {}
  for t=0, reaper.CountTracks(0)-1 do
    local tr = reaper.GetTrack(0, t)
    local _, name = reaper.GetTrackName(tr)
    local chunk = get_track_chunk(tr)
    local d,c0 = parse_midi_hwout(chunk)
    if d ~= nil then
      users[#users+1] = {idx=t+1, name=name, dev=d, ch=c0}
      local key = tostring(d) .. ":" .. tostring(c0)
      collisions[key] = (collisions[key] or 0) + 1
    end
  end

  if #users == 0 then
    msg("No tracks with MIDIHWOUT found in project.")
  else
    msg("Tracks with MIDI hardware output (MIDIHWOUT):")
    for _,u in ipairs(users) do
      local ch = (u.ch and u.ch >= 0) and (u.ch + 1) or "?"
      msg(string.format("  Track %d: %s  -> dev=%s  ch=%s", u.idx, u.name, tostring(u.dev), tostring(ch)))
    end
  end

  -- Collisions on mioXM DIN4 dev
  if devIndex then
    msg("\nCollision check on matched output device:")
    local any = false
    for _,u in ipairs(users) do
      if u.dev == devIndex then any = true break end
    end
    if not any then
      msg("  No tracks are currently sending to the matched mioXM output.")
    else
      for _,u in ipairs(users) do
        if u.dev == devIndex then
          local key = tostring(u.dev) .. ":" .. tostring(u.ch)
          if (collisions[key] or 0) > 1 then
            msg(string.format("  WARNING: Multiple tracks send to %s channel %d (possible MIDI 'matsch'): %s",
              tostring(devName), (u.ch or 0)+1, u.name))
          end
        end
      end
      msg("  Tip: Keep only ONE track sending PCs/CCs to the M350 channel at a time (typically the M350 Control track).")
    end
  end

  -- Heuristic: possible MIDI feedback loop (same track has MIDIHWOUT + is armed with MIDI input)
  msg("\nHeuristic: MIDI feedback loop risk")
  local risky = 0
  for t=0, reaper.CountTracks(0)-1 do
    local tr = reaper.GetTrack(0, t)
    local chunk = get_track_chunk(tr)
    local d,c0 = parse_midi_hwout(chunk)
    if d ~= nil and chunk then
      local recinput = chunk:match("\nRECINPUT%s+([%-%d]+)")
      local mon = chunk:match("\nRECMON%s+([%-%d]+)")
      local armed = reaper.GetMediaTrackInfo_Value(tr, "I_RECARM")
      if recinput and tonumber(recinput) and armed == 1 and (tonumber(mon) or 0) > 0 then
        risky = risky + 1
        local _, name = reaper.GetTrackName(tr)
        msg(string.format("  POSSIBLE RISK: Track '%s' is armed+monitored and also has MIDIHWOUT. Verify it isn't echoing back into the same mioXM route.", name))
      end
    end
  end
  if risky == 0 then
    msg("  No obvious armed+monitored MIDIHWOUT tracks found.")
  end

  -- Heuristic: double clock senders (scan FX names)
  msg("\nHeuristic: Possible double-clock sources (FX name contains 'clock' + 'midi')")
  local clockFx = {}
  for t=0, reaper.CountTracks(0)-1 do
    local tr = reaper.GetTrack(0,t)
    local fxn = reaper.TrackFX_GetCount(tr)
    for fx=0, fxn-1 do
      local ok, fxname = reaper.TrackFX_GetFXName(tr, fx, "")
      if ok and fxname then
        local n = fxname:lower()
        if n:find("clock",1,true) and n:find("midi",1,true) then
          local _, tn = reaper.GetTrackName(tr)
          clockFx[#clockFx+1] = tn .. " :: " .. fxname
        end
      end
    end
  end
  if #clockFx == 0 then
    msg("  None found.")
  else
    for _,s in ipairs(clockFx) do msg("  " .. s) end
    msg("  If you also send MIDI clock from mioXM or OXI, make sure only ONE master clock is active.")
  end

  msg("\nChecklist (manual confirmations):")
  msg("  [ ] M350 hardware MIDI channel is NOT OMNI (set 16 or your chosen channel).")
  msg("  [ ] mioXM: DIN4 IN is not routed back to DIN4 OUT without filtering (avoid loops).")
  msg("  [ ] Only one master clock: REAPER OR OXI OR another device (not multiple).")
  msg("  [ ] If using ReaInsert: run Ping/Latency setup on your insert track after buffer/driver changes.")

  reaper.MB("Project Doctor report written to REAPER console.\n(View > Show console)", "M350 Project Doctor", 0)
end

-- =========================
-- Main
-- =========================
local base = script_dir()
local preset_path = path_join(base, DEFAULT_PRESET_JSON_REL)

-- ensure preset JSON exists
if not file_exists(preset_path) then
  -- create minimal JSON so editor has something to work with
  write_preset_json(preset_path, {})
end

local choice = show_menu()
if not choice then return end

if choice == 1 then
  presets_editor(preset_path)
elseif choice == 2 then
  create_regions_from_pc_items(preset_path)
elseif choice == 3 then
  project_doctor(preset_path)
else
  -- options/close
  return
end
