-- @description IFLS Workbench - MicroFreak SysEx Librarian (Send .syx via SWS)
-- @version 0.67.0
-- @author IfeelLikeSnow

-- MicroFreak SysEx librarian:
-- Arturia does not publicly document MicroFreak preset SysEx structure.
-- This tool focuses on sending .syx files exported from Arturia MIDI Control Center (MCC).
--
-- Requirements:
-- - SWS extension (SNM_SendSysEx) for reliable SysEx transmit
-- Optional:
-- - JS_ReaScriptAPI for file dialog

local r = reaper

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local function browse_syx()
  if r.JS_Dialog_BrowseForOpenFiles then
    local rv, files = r.JS_Dialog_BrowseForOpenFiles("Select MicroFreak .syx file", "", "", "SysEx (*.syx)\0*.syx\0", false)
    if rv and files and files ~= "" then
      return files:match("^[^;]+")
    end
  end
  -- fallback: ask user to paste path
  local ok, path = r.GetUserFileNameForRead("", "Select MicroFreak .syx file", ".syx")
  if ok then return path end
  return nil
end

local function pick_midi_out()
  local n = r.GetNumMIDIOutputs()
  if n == 0 then return nil, "No MIDI outputs configured." end
  local menu = {}
  for i=0,n-1 do
    local rv, name = r.GetMIDIOutputName(i, "")
    if rv then menu[#menu+1] = name end
  end
  local choice = r.GetUserInputs("MIDI Output", 1, "MIDI output index (1-"..tostring(#menu)..")", "1")
  if not choice then return nil, "Cancelled." end
  local idx = tonumber(({choice})[1]) or tonumber(choice) or 1
  idx = math.floor(idx)
  if idx < 1 or idx > #menu then return nil, "Invalid output index." end
  return idx-1, menu[idx]
end

if not r.SNM_SendSysEx then
  r.MB("SWS not detected (SNM_SendSysEx missing).\n\nInstall SWS to send SysEx reliably.", "MicroFreak SysEx Librarian", 0)
  return
end

local out_id, out_name = pick_midi_out()
if not out_id then
  r.MB(out_name or "No output selected.", "MicroFreak SysEx Librarian", 0)
  return
end

local path = browse_syx()
if not path then return end
if not file_exists(path) then
  r.MB("File not found:\n"..tostring(path), "MicroFreak SysEx Librarian", 0)
  return
end

-- Send SysEx file via SWS
-- SNM_SendSysEx takes: (output device id, file path) in some SWS builds
local ok = r.SNM_SendSysEx(out_id, path)
if ok == 0 or ok == false then
  r.MB("SysEx send failed.\n\nCheck: MicroFreak MIDI input, MCC compatibility, and MIDI routing.", "MicroFreak SysEx Librarian", 0)
else
  r.MB("Sent SysEx to output: "..out_name.."\n\nFile:\n"..path, "MicroFreak SysEx Librarian", 0)
end
