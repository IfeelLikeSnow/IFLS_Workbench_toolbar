-- @description IFLS: Create "M350 Control" track (set HW MIDI out to mioXM DIN 4, prep PC/CC lanes, optional preset markers/regions)
-- @version 1.1
-- @author IFLS Workbench (generated)
-- @about
--   Creates a dedicated MIDI control track for the TC Electronic M350:
--   - Sets track HW MIDI output to a chosen MIDI output device (default: mioXM DIN 4)
--   - Forces channel (default: 16) by setting the HW output channel
--   - Adds ReaControlMIDI and prepares CC automation lanes (best-effort)
--   - Inserts a tiny MIDI item with a Program Change (PC) at edit cursor
--   - Optionally creates a marker or a region for the selected preset (nameable)
--
--   Notes:
--   - Keep the M350 on a fixed MIDI channel (avoid OMNI) to prevent accidental preset changes.
--   - If you route both directions in mioXM (DIN4 IN+OUT), avoid MIDI feedback loops.

-- =========================
-- USER DEFAULTS
-- =========================
local DEFAULT_MIDI_OUT_NAME_CONTAINS = "mioXM DIN 4"
local DEFAULT_M350_CHANNEL = 16             -- 1..16
local DEFAULT_PC_NUMBER = 1                 -- 1..99 (M350 user presets typically 1..99)
local DEFAULT_CREATE_MARKER = true
local DEFAULT_CREATE_REGION = false
local DEFAULT_REGION_LENGTH_SECONDS = 4.0   -- only used if creating region
local DEFAULT_CREATE_AUDIO_SEND_RETURN = false

-- Optional: fill with your own preset names (1..99). If empty, "M350 PC <n>" is used.
local PRESET_NAMES = {
  -- [1] = "Vocal Plate",
  -- [2] = "Wide Chorus Verb",
}

-- CC list (from M350 manual "MIDI Implementation" section)
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

-- =========================
-- HELPERS
-- =========================
local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function bool_from_str(s, default)
  if s == nil then return default end
  s = tostring(s):lower():gsub("%s+", "")
  if s == "1" or s == "true" or s == "yes" or s == "y" then return true end
  if s == "0" or s == "false" or s == "no" or s == "n" then return false end
  return default
end

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
  -- Track chunk line format: "MIDIHWOUT <dev> <chan>"
  -- dev is 0-based MIDI output index; chan is 0..15
  local ok, chunk = reaper.GetTrackStateChunk(track, "", false)
  if not ok then return false end

  local dev = tonumber(devIndex) or 0
  local chan = clamp((tonumber(channel) or 1) - 1, 0, 15)

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
  return reaper.TrackFX_AddByName(track, fxName, false, 1) -- instantiate if missing
end

local function showEnvelope(env)
  if not env then return end
  reaper.SetEnvelopeInfo_Value(env, "B_VISIBLE", 1)
  reaper.SetEnvelopeInfo_Value(env, "B_SHOWINLANE", 1)
end

local function addReaControlMidiCCEnvelopes(track, fx)
  -- Best-effort: scan parameter names for "CC" + number and create envelopes.
  local pCount = reaper.TrackFX_GetNumParams(track, fx)
  local wanted = {}
  for _,it in ipairs(M350_CC) do wanted[tostring(it.cc)] = true end

  local created = 0
  for p=0,pCount-1 do
    local ok, pname = reaper.TrackFX_GetParamName(track, fx, p, "")
    if ok and pname then
      local ccNum = pname:match("CC%s*#?%s*(%d+)")
      if ccNum and wanted[ccNum] then
        local env = reaper.GetFXEnvelope(track, fx, p, true)
        showEnvelope(env)
        created = created + 1
      end
    end
  end
  return created
end

local function insertProgramChangeItem(track, chan1based, pcNumber)
  local pos = reaper.GetCursorPosition()
  local len = 0.25 -- seconds
  local item = reaper.CreateNewMIDIItemInProj(track, pos, pos+len, false)
  local take = reaper.GetActiveTake(item)
  if not take then return end

  local chan = clamp((tonumber(chan1based) or 1) - 1, 0, 15)
  local program = clamp((tonumber(pcNumber) or 1) - 1, 0, 127) -- MIDI PC 0..127

  reaper.MIDI_InsertCC(take, false, false, 0, 0xC0, chan, program, 0)
  reaper.MIDI_Sort(take)
end

local function presetLabel(pcNumber)
  local n = tonumber(pcNumber) or 1
  return PRESET_NAMES[n] or ("M350 PC " .. tostring(n))
end

local function addMarker(pcNumber)
  local pos = reaper.GetCursorPosition()
  reaper.AddProjectMarker2(0, false, pos, 0, presetLabel(pcNumber), -1, 0)
end

local function addRegion(pcNumber, lengthSeconds)
  local pos = reaper.GetCursorPosition()
  local rEnd = pos + (tonumber(lengthSeconds) or 4.0)
  reaper.AddProjectMarker2(0, true, pos, rEnd, presetLabel(pcNumber), -1, 0)
end

local function createAudioSendReturnAfter(track)
  local idx1 = math.floor(reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")) -- 1-based
  -- Insert tracks below control track
  reaper.InsertTrackAtIndex(idx1, true)
  local sendTr = reaper.GetTrack(0, idx1)
  reaper.GetSetMediaTrackInfo_String(sendTr, "P_NAME", "M350 Send (Audio)", true)

  reaper.InsertTrackAtIndex(idx1+1, true)
  local retTr = reaper.GetTrack(0, idx1+1)
  reaper.GetSetMediaTrackInfo_String(retTr, "P_NAME", "M350 Return (Audio)", true)

  -- Keep them adjacent: Send, Return, Control (or Control then Send/Return). User can reorder as desired.
  return sendTr, retTr
end

-- =========================
-- UI PROMPT
-- =========================
local defaults = table.concat({
  DEFAULT_MIDI_OUT_NAME_CONTAINS,
  tostring(DEFAULT_M350_CHANNEL),
  tostring(DEFAULT_PC_NUMBER),
  DEFAULT_CREATE_MARKER and "1" or "0",
  DEFAULT_CREATE_REGION and "1" or "0",
  tostring(DEFAULT_REGION_LENGTH_SECONDS),
  DEFAULT_CREATE_AUDIO_SEND_RETURN and "1" or "0",
}, ",")

local ok, csv = reaper.GetUserInputs(
  "Create M350 Control Track",
  7,
  "MIDI out contains,Channel (1-16),Program Change (1-99),Create marker (1/0),Create region (1/0),Region length (s),Create audio send/return (1/0)",
  defaults
)
if not ok then return end

local fields = {}
for v in csv:gmatch("([^,]*)") do fields[#fields+1] = v end

local midiOutNeedle = fields[1] ~= "" and fields[1] or DEFAULT_MIDI_OUT_NAME_CONTAINS
local ch = clamp(tonumber(fields[2]) or DEFAULT_M350_CHANNEL, 1, 16)
local pc = clamp(tonumber(fields[3]) or DEFAULT_PC_NUMBER, 1, 99)
local mk = bool_from_str(fields[4], DEFAULT_CREATE_MARKER)
local rg = bool_from_str(fields[5], DEFAULT_CREATE_REGION)
local rgLen = tonumber(fields[6]) or DEFAULT_REGION_LENGTH_SECONDS
local makeAudioSR = bool_from_str(fields[7], DEFAULT_CREATE_AUDIO_SEND_RETURN)

local devIndex, devName = findMidiOutIndexByName(midiOutNeedle)
if not devIndex then
  reaper.MB(
    "MIDI Output not found containing:\n" .. midiOutNeedle ..
    "\n\nCheck REAPER Preferences > MIDI Devices and ensure the output is enabled.",
    "M350 Control",
    0
  )
  return
end

-- =========================
-- MAIN
-- =========================
reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- Create control track at end
local trackCount = reaper.CountTracks(0)
reaper.InsertTrackAtIndex(trackCount, true)
local tr = reaper.GetTrack(0, trackCount)
reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "M350 Control", true)

-- Set HW out
local okSet = setTrackMidiHwOutViaChunk(tr, devIndex, ch)

-- Add ReaControlMIDI
local fx = ensureFx(tr, "ReaControlMIDI (Cockos)")
local created = 0
if fx >= 0 then
  created = addReaControlMidiCCEnvelopes(tr, fx)
end

-- Insert PC item at cursor
insertProgramChangeItem(tr, ch, pc)

-- Marker/Region
if mk then addMarker(pc) end
if rg then addRegion(pc, rgLen) end

-- Optional audio send/return placeholders
if makeAudioSR then
  createAudioSendReturnAfter(tr)
end

reaper.TrackList_AdjustWindows(false)
reaper.UpdateArrange()

reaper.PreventUIRefresh(-1)
reaper.Undo_EndBlock("IFLS: Create M350 Control track + PC/CC lanes", -1)

if not okSet then
  reaper.MB("Track created, but setting HW MIDI output failed (chunk write).", "M350 Control", 0)
end

-- Small info (optional)
-- reaper.ShowConsoleMsg(("M350 Control created -> %s (ch %d), CC lanes created: %d\n"):format(devName or "MIDI out", ch, created))
