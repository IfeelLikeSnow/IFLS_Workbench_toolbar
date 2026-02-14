-- IFLS MIDI SysEx extraction helpers for REAPER takes
-- Extracts SysEx messages from a MIDI take via MIDI_GetAllEvts.
-- Robust to SysEx chunks being split across multiple events.
--
-- Returns:
--   blob (string): concatenated complete F0..F7 messages
--   count (int): number of complete messages found
--
-- NOTE: Partial (unterminated) SysEx at end is discarded for safety.

local M = {}

function M.extract_sysex_from_take(take)
  if not take then return "", 0 end
  local ok, data = reaper.MIDI_GetAllEvts(take, "")
  if not ok or not data then return "", 0 end

  local pos=1
  local out={}
  local count=0

  local in_sysex=false
  local buf=""

  local function feed(chunk)
    if not chunk or #chunk==0 then return end
    local i=1
    while i <= #chunk do
      if not in_sysex then
        local s = chunk:find(string.char(0xF0), i, true)
        if not s then return end
        in_sysex=true
        buf=""
        i=s
      end
      local e = chunk:find(string.char(0xF7), i, true)
      if e then
        buf = buf .. chunk:sub(i, e)
        out[#out+1]=buf
        count = count + 1
        buf=""
        in_sysex=false
        i = e + 1
      else
        buf = buf .. chunk:sub(i)
        return
      end
    end
  end

  while pos <= #data do
    local offs, flags, msg, nextpos = string.unpack("i4Bs4", data, pos)
    pos = nextpos
    if msg and #msg > 0 then
      feed(msg)
    end
  end

  return table.concat(out, ""), count
end

return M
