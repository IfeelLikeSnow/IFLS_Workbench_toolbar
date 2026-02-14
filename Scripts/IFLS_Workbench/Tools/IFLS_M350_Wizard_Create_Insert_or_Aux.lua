-- @description M350 Wizard: Create Insert Track or Aux Return Template (with MIDI Control)
-- @version 1.1
-- @author Reaper DAW Ultimate Assistant
-- @about
--   Menu-driven wizard to create:
--   1) M350 Insert Track (Audio track with ReaInsert + linked MIDI Control)
--   2) M350 Aux Return Template (Return track with ReaInsert + optional send placeholder + linked MIDI Control)
--   3) MIDI Control only
--
--   Notes:
--   - Hardware I/O assignment for ReaInsert varies across REAPER versions/drivers. This script does a best-effort
--     attempt by scanning ReaInsert parameter names. If it can't set it, it will still insert ReaInsert and open its UI.
--   - MIDI HW Output is set via Track State Chunk (MIDIHWOUT) and should be reliable.

-- =========================
-- USER DEFAULTS
-- =========================
local DEFAULT_MIDI_OUT_NAME_CONTAINS = "mioXM DIN 4"
local DEFAULT_M350_MIDI_CHANNEL = 16 -- avoid OMNI on the M350
local DEFAULT_PC_NUMBER = 1          -- 1..99
local DEFAULT_CREATE_MARKER = true
local DEFAULT_MARKER_AS_REGION = false

-- Gain staging defaults
local DEFAULT_RETURN_VOL_DB = -6.0
local DEFAULT_INSERT_VOL_DB = -3.0

-- =========================
-- M350 CC list (for ReaControlMIDI lanes) - from manual page 31
-- =========================
local M350_CC = {
  {name="In Level",   cc=12},
  {name="Mix",        cc=13},
  {name="Effect Bal", cc=14},
  {name="Digi In",    cc=15},
  {name="Timing",     cc=16},
  {name="Feedback",   cc=17},
  {name="Pre Delay",  cc=18},
  {name="Decay",      cc=19},
  {name="Color",      cc=20},
  {name="Delay Type", cc=50},
  {name="Reverb Type",cc=51},
  {name="Tap",        cc=80},
  {name="Bypass",     cc=81},
  {name="DelayFX Off",cc=82},
  {name="Reverb Off", cc=83},
}

-- Preset name map is loaded from JSON (optional).
-- File: Scripts/IFLS_Workbench/Workbench/M350/Data/m350_presets.json
-- Format: { "1": "Vocal Plate", "2": "Wide Chorus Verb", ... }
local PRESET_NAMES = nil

local function wb_root()
  return reaper.GetResourcePath().."/Scripts/IFLS_Workbench"
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*all")
  f:close()
  return d
end

local function json_decode(str)
  local ok, j = pcall(function() return reaper.JSON_Decode(str) end)
  if ok and j then return j end
  local ok2, dk = pcall(require, "dkjson")
  if ok2 and dk then return dk.decode(str) end
  return nil
end

local function load_preset_names()
  local path = wb_root().."/Workbench/M350/Data/m350_presets.json"
  local raw = read_file(path)
  if not raw then return nil end
  local t = json_decode(raw)
  if type(t) ~= "table" then return nil end
  local out = {}
  for k,v in pairs(t) do
    local n = tonumber(k)
    if n and type(v) == "string" and v ~= "" then
      out[n] = v
    end
  end
  return out
end


-- =========================
-- Helpers
-- =========================
local EXT_SECTION = "IFLS_M350_WIZARD"

local function ext_get(key, default)
  local v = reaper.GetExtState(EXT_SECTION, key)
  if v == nil or v == "" then return default end
  return v
end

local function ext_set(key, value)
  reaper.SetExtState(EXT_SECTION, key, tostring(value or ""), true) -- persist
end

local function ext_get_number(key, default)
  local v = ext_get(key, "")
  local n = tonumber(v)
  if n == nil then return default end
  return n
end

local function ext_get_bool(key, default)
  local v = ext_get(key, "")
  if v == "" then return default end
  return v == "1" or v:lower() == "true"
end

local function ext_set_bool(key, b)
  ext_set(key, b and "1" or "0")
end

local function db_to_vol(db) return 10^(db/20) end

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

local function setTrackMidiHwOutViaChunk(track, devIndex, channel)
  local ok, chunk = reaper.GetTrackStateChunk(track, "", false)
  if not ok then return false end
  local dev = tonumber(devIndex) or 0
  local chan = math.max(0, math.min(15, (tonumber(channel) or 1) - 1))

  if chunk:find("\nMIDIHWOUT%s") then
    chunk = chunk:gsub("\nMIDIHWOUT%s+[%-%d]+%s+[%-%d]+", "\nMIDIHWOUT " .. dev .. " " .. chan, 1)
  else
    local firstLineEnd = chunk:find("\n")
    if firstLineEnd then
      chunk = chunk:sub(1, firstLineEnd) .. "MIDIHWOUT " .. dev .. " " .. chan .. "\n" .. chunk:sub(firstLineEnd+1)
    else
      chunk = chunk .. "\nMIDIHWOUT " .. dev .. " " .. chan .. "\n"
    end
  end
  return reaper.SetTrackStateChunk(track, chunk, false)
end

local function ensureFx(track, fxName)
  return reaper.TrackFX_AddByName(track, fxName, false, 1)
end

local function showEnvelope(env)
  if not env then return end
  reaper.SetEnvelopeInfo_Value(env, "B_VISIBLE", 1)
  reaper.SetEnvelopeInfo_Value(env, "B_SHOWINLANE", 1)
end

local function addReaControlMidiCCEnvelopes(track, fx)
  local pCount = reaper.TrackFX_GetNumParams(track, fx)
  local wanted = {}
  for _,it in ipairs(M350_CC) do wanted[tostring(it.cc)] = true end

  for p=0,pCount-1 do
    local ok, pname = reaper.TrackFX_GetParamName(track, fx, p, "")
    if ok and pname then
      local ccNum = pname:match("CC%s*#?%s*(%d+)")
      if ccNum and wanted[ccNum] then
        local env = reaper.GetFXEnvelope(track, fx, p, true)
        showEnvelope(env)
      end
    end
  end
end

local function insertProgramChangeItem(track, midiChannel, pcNumber)
  local pos = reaper.GetCursorPosition()
  local len = 0.25
  local item = reaper.CreateNewMIDIItemInProj(track, pos, pos+len, false)
  local take = reaper.GetActiveTake(item)
  if not take then return end

  local chan = math.max(0, math.min(15, (midiChannel or 1) - 1))
  local program = math.max(0, math.min(127, (pcNumber or 1) - 1))
  reaper.MIDI_InsertCC(take, false, false, 0, 0xC0, chan, program, 0)
  reaper.MIDI_Sort(take)
end

local function addPresetMarkerOrRegion(pcNumber, asRegion)
  local pos = reaper.GetCursorPosition()
  local name = PRESET_NAMES[pcNumber] or ("M350 PC " .. tostring(pcNumber))
  if asRegion then
    local rEnd = pos + 1.0
    reaper.AddProjectMarker2(0, true, pos, rEnd, name, -1, 0)
  else
    reaper.AddProjectMarker2(0, false, pos, 0, name, -1, 0)
  end
end

local function promptSettings(defaultMidiOutSub, defaultChan, defaultPC, defaultMarker, defaultAsRegion)
  local cap = "M350 Wizard settings"
  local labels = "MIDI out contains,Channel (1-16),Program Change (1-99),Create marker/region (0/1),As region (0/1)"
  local defaults = string.format("%s,%d,%d,%d,%d",
    defaultMidiOutSub or "",
    tonumber(defaultChan) or 16,
    tonumber(defaultPC) or 1,
    defaultMarker and 1 or 0,
    defaultAsRegion and 1 or 0
  )
  local ok, out = reaper.GetUserInputs(cap, 5, labels, defaults)
  if not ok then return nil end
  local a,b,c,d,e = out:match("^(.*),(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+)$")
  if not a then return nil end
  return {
    midiOutSub = a,
    chan = tonumber(b) or 16,
    pc = tonumber(c) or 1,
    mk = tonumber(d) == 1,
    asRegion = tonumber(e) == 1
  }
end

local function promptAudioIO(kind)
  local cap = (kind == "insert") and "M350 Insert audio I/O" or "M350 Aux Return audio I/O"
  local labels = "HW send out pair start (e.g. 7 for 7/8),HW return in pair start (e.g. 7 for 7/8),Open ReaInsert UI (0/1)"
  local defaults = "1,1,1"
  local ok, out = reaper.GetUserInputs(cap, 3, labels, defaults)
  if not ok then return nil end
  local o,i,ui = out:match("^(%-?%d+),(%-?%d+),(%-?%d+)$")
  if not o then return nil end
  return {outStart=tonumber(o) or 1, inStart=tonumber(i) or 1, openUI=(tonumber(ui)==1)}
end

-- Best-effort: try to set ReaInsert send/return pair by scanning param names.
-- If it fails, we simply open the FX UI and let the user pick.
local function trySetReaInsertIO(track, fx, outStart, inStart)
  local pCount = reaper.TrackFX_GetNumParams(track, fx)
  local setCount = 0

  local function setByContains(contains, value)
    for p=0,pCount-1 do
      local ok, pname = reaper.TrackFX_GetParamName(track, fx, p, "")
      if ok and pname and pname:lower():find(contains, 1, true) then
        -- Some params are discrete lists; normalized mapping is unknown.
        -- We'll set only if it looks like a "channel" selector with 0..N steps.
        local minv, maxv = reaper.TrackFX_GetParamEx(track, fx, p)
        if maxv and maxv > 0 then
          local norm = value
          if value > 1 then
            -- crude mapping: assume 1..64 range => normalize
            norm = math.max(0, math.min(1, (value-1) / 63))
          end
          reaper.TrackFX_SetParam(track, fx, p, norm)
          return true
        end
      end
    end
    return false
  end

  -- We attempt likely keywords; if no match, give up.
  if setByContains("hardware send", outStart) or setByContains("send", outStart) then setCount = setCount + 1 end
  if setByContains("hardware return", inStart) or setByContains("return", inStart) then setCount = setCount + 1 end

  return setCount
end

local function insertReaInsert(track, outStart, inStart, openUI)
  local fx = ensureFx(track, "ReaInsert (Cockos)")
  trySetReaInsertIO(track, fx, outStart, inStart)
  if openUI then reaper.TrackFX_Show(track, fx, 3) end -- float
  return fx
end

local function createMidiControlTrack(afterTrackIndex, settings, devIndex)
  local idx = afterTrackIndex or reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(idx, true)
  local tr = reaper.GetTrack(0, idx)
  reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "M350 Control", true)

  setTrackMidiHwOutViaChunk(tr, devIndex, settings.chan)

  local fx = ensureFx(tr, "ReaControlMIDI (Cockos)")
  addReaControlMidiCCEnvelopes(tr, fx)

  insertProgramChangeItem(tr, settings.chan, settings.pc)

  if settings.mk then
    addPresetMarkerOrRegion(settings.pc, settings.asRegion)
  end

  return tr
end

local function createInsertTemplate(settings, devIndex)
  local io = promptAudioIO("insert")
  if not io then return end

  local trackCount = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(trackCount, true)
  local audioTr = reaper.GetTrack(0, trackCount)
  reaper.GetSetMediaTrackInfo_String(audioTr, "P_NAME", "M350 Insert (Audio)", true)
  reaper.SetMediaTrackInfo_Value(audioTr, "D_VOL", db_to_vol(DEFAULT_INSERT_VOL_DB))

  insertReaInsert(audioTr, io.outStart, io.inStart, io.openUI)

  -- Create MIDI control directly below audio track
  createMidiControlTrack(trackCount + 1, settings, devIndex)

  -- Helpful note
  local note = string.format("M350 Insert via ReaInsert. HW send out %d/%d, return in %d/%d. MIDI ch %d, PC %d.",
    io.outStart, io.outStart+1, io.inStart, io.inStart+1, settings.chan, settings.pc)
  reaper.GetSetMediaTrackInfo_String(audioTr, "P_NOTES", note, true)
end

local function createAuxTemplate(settings, devIndex)
  local io = promptAudioIO("aux")
  if not io then return end

  local trackCount = reaper.CountTracks(0)

  -- Return track
  reaper.InsertTrackAtIndex(trackCount, true)
  local retTr = reaper.GetTrack(0, trackCount)
  reaper.GetSetMediaTrackInfo_String(retTr, "P_NAME", "M350 AUX Return", true)
  reaper.SetMediaTrackInfo_Value(retTr, "D_VOL", db_to_vol(DEFAULT_RETURN_VOL_DB))

  insertReaInsert(retTr, io.outStart, io.inStart, io.openUI)

  -- Optional: a "Send bus" placeholder for organization (no audio wiring)
  reaper.InsertTrackAtIndex(trackCount+1, true)
  local sendTr = reaper.GetTrack(0, trackCount+1)
  reaper.GetSetMediaTrackInfo_String(sendTr, "P_NAME", "M350 AUX Send (route sources here)", true)
  reaper.SetMediaTrackInfo_Value(sendTr, "D_VOL", 1.0)

  -- Create MIDI control below
  createMidiControlTrack(trackCount + 2, settings, devIndex)

  local note = string.format("Aux template: Put sends from sources to 'M350 AUX Send', route to 'M350 AUX Return' (or send directly to Return). ReaInsert on Return: HW out %d/%d, in %d/%d. MIDI ch %d PC %d.",
    io.outStart, io.outStart+1, io.inStart, io.inStart+1, settings.chan, settings.pc)
  reaper.GetSetMediaTrackInfo_String(retTr, "P_NOTES", note, true)
end


local function findTrackByNameContains(substr)
  substr = (substr or ""):lower()
  for i=0,reaper.CountTracks(0)-1 do
    local tr = reaper.GetTrack(0,i)
    local _, name = reaper.GetTrackName(tr, "")
    if name and name:lower():find(substr, 1, true) then
      return tr
    end
  end
  return nil
end

local function findReaInsertFX(track)
  if not track then return nil end
  local fxCount = reaper.TrackFX_GetCount(track)
  for fx=0,fxCount-1 do
    local ok, fxName = reaper.TrackFX_GetFXName(track, fx, "")
    if ok and fxName and fxName:lower():find("reainsert", 1, true) then
      return fx
    end
  end
  return nil
end

local function tryTriggerReaInsertPing(track, fx)
  local pCount = reaper.TrackFX_GetNumParams(track, fx)
  local candidates = {}
  for p=0,pCount-1 do
    local ok, pname = reaper.TrackFX_GetParamName(track, fx, p, "")
    if ok and pname then
      local pl = pname:lower()
      if pl:find("ping", 1, true) or pl:find("auto", 1, true) or pl:find("detect", 1, true) then
        table.insert(candidates, p)
      end
    end
  end
  if #candidates == 0 then return false end

  -- Toggle likely button params: set to 1 then back
  for _,p in ipairs(candidates) do
    local cur = reaper.TrackFX_GetParam(track, fx, p)
    reaper.TrackFX_SetParam(track, fx, p, 1.0)
    reaper.TrackFX_SetParam(track, fx, p, cur)
  end
  return true
end

local function doPingLatencySetup()
  -- prefer selected track
  local tr = reaper.GetSelectedTrack(0,0)
  if not tr then tr = findTrackByNameContains("M350 Insert") end
  if not tr then
    reaper.MB("Select the M350 Insert track (or name it containing 'M350 Insert') and run again.", "M350 Ping/Latency Setup", 0)
    return
  end

  local fx = findReaInsertFX(tr)
  if not fx then
    reaper.MB("No ReaInsert found on the selected track.\n\nAdd ReaInsert first (Wizard: Create M350 Insert Track), then run Ping/Latency Setup.", "M350 Ping/Latency Setup", 0)
    return
  end

  -- Open ReaInsert UI so user can see what's happening
  reaper.TrackFX_Show(tr, fx, 3) -- show floating window

  local ok = tryTriggerReaInsertPing(tr, fx)

  if ok then
    reaper.MB("ReaInsert ping trigger attempted.\n\nIf latency is still not detected, click ReaInsert's 'Ping'/'Auto-detect' button manually.\nTip: hardware insert latency is typically set via a 'Ping' function in ReaInsert workflows.", "M350 Ping/Latency Setup", 0)
  else
    reaper.MB("Opened ReaInsert.\n\nThis REAPER build did not expose a detectable 'Ping/Auto-detect' parameter to ReaScript.\nPlease click the Ping/Auto-detect button in ReaInsert manually.", "M350 Ping/Latency Setup", 0)
  end
end

local function showMenu()
  local last = ext_get_number("last_choice", 1)

  local items = {
    "Create M350 Insert Track",
    "Create M350 Aux Return Template",
    "Create MIDI Control Only",
    "Insert: ReaInsert Ping/Latency Setup",
  }

  -- gfx.showmenu uses '!' to check an item (not strictly a default),
  -- but it's a good visual hint and we still remember the last selection.
  for i=1,#items do
    if i == last then items[i] = "!"..items[i] end
  end

  gfx.init("M350 Wizard", 0, 0, 0, 0, 0)
  local menu = table.concat(items, "|") .. "||Cancel"
  local choice = gfx.showmenu(menu)
  gfx.quit()

  if choice >= 1 and choice <= #items then
    ext_set("last_choice", choice)
  end
  return choice
end

-- =========================
-- Main
-- =========================
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local choice = showMenu()
if choice == 0 or choice == 5 then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("M350 Wizard (cancel)", -1)
  return
end

local lastMidiOut = ext_get("midi_out_contains", DEFAULT_MIDI_OUT_NAME_CONTAINS)
local lastChan    = ext_get_number("midi_channel", DEFAULT_M350_MIDI_CHANNEL)
local lastPC      = ext_get_number("pc_number", DEFAULT_PC_NUMBER)
local lastMarker  = ext_get_bool("create_marker", DEFAULT_CREATE_MARKER)
local lastAsReg   = ext_get_bool("marker_as_region", DEFAULT_MARKER_AS_REGION)

local settings = promptSettings(
  lastMidiOut,
  lastChan,
  lastPC,
  lastMarker,
  lastAsReg
)
if not settings then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("M350 Wizard (cancel settings)", -1)
  return
end

-- persist last-used settings
ext_set("midi_out_contains", settings.midiOutSub)
ext_set("midi_channel", settings.chan)
ext_set("pc_number", settings.pc)
ext_set_bool("create_marker", settings.createMarker)
ext_set_bool("marker_as_region", settings.asRegion)

local devIndex, devName = findMidiOutIndexByName(settings.midiOutSub)
if not devIndex then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("M350 Wizard - FAILED (MIDI out not found)", -1)
  reaper.MB("MIDI Output not found containing:\n" .. settings.midiOutSub .. "\n\nCheck Preferences > MIDI Devices.", "M350 Wizard", 0)
  return
end

-- load preset names from JSON (optional)
if PRESET_NAMES == nil then
  PRESET_NAMES = load_preset_names() or {}
end


if choice == 1 then
  createInsertTemplate(settings, devIndex)
elseif choice == 2 then
  createAuxTemplate(settings, devIndex)
elseif choice == 3 then
  -- MIDI control only
  createMidiControlTrack(reaper.CountTracks(0), settings, devIndex)
elseif choice == 4 then
  -- Ping/latency setup for ReaInsert on selected (or M350 Insert) track
  doPingLatencySetup()
end

reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)
local undoName = (choice == 4) and "M350 Wizard: ReaInsert Ping/Latency Setup" or "M350 Wizard: create template + MIDI control"
reaper.Undo_EndBlock(undoName, -1)
