-- @description IFLS FB-01 Core SysEx Library
-- @version 0.90.0
-- @author IFLS
-- @about
--   SysEx builders for Yamaha FB-01 (derived from open-source editors).
--   Provides parameter-change and dump-request messages.
--
--   Notes:
--   - Voice/Operator values are encoded as 8-bit values split into 2 nibbles (lo/hi), each 0..15.
--   - Instrument values are 7-bit (0..127).
--   - Checksum for bulk dumps: (-sum(data)) & 0x7F

local M = {}

-- Yamaha Manufacturer ID
local ID_YAMAHA = 0x43

-- FB-01 model group byte used by the editors
local FB01_GROUP = 0x75

-- Default SysEx channel (0..15). The editors call this SysChannel.
M.DEFAULT_SYSCH = 0 -- you can override in caller

-- Helpers
local function b(x) return string.char(x & 0xFF) end

function M.pack_nibbles(v8)
  v8 = math.floor(tonumber(v8) or 0)
  if v8 < 0 then v8 = 0 elseif v8 > 255 then v8 = 255 end
  local lo = v8 & 0x0F
  local hi = (v8 >> 4) & 0x0F
  return lo, hi
end

function M.unpack_nibbles(lo, hi)
  lo = (tonumber(lo) or 0) & 0x0F
  hi = (tonumber(hi) or 0) & 0x0F
  return (hi << 4) | lo
end

function M.checksum_neg_sum(bytes_tbl)
  local sum = 0
  for i=1,#bytes_tbl do sum = sum + (bytes_tbl[i] & 0x7F) end
  return (-sum) & 0x7F
end

-- Frame a SysEx body into a complete message
function M.frame(body)
  return b(0xF0) .. body .. b(0xF7)
end

-- Voice parameter change (8-bit value, nibble-split)
-- Format from Voice::Envoyer in both repos:
-- F0 43 75 sysCh (0x18 + (instId&7)) (0x40+param) lo hi F7
function M.voice_param(sysCh, instId, param, value8)
  sysCh = tonumber(sysCh) or M.DEFAULT_SYSCH
  instId = tonumber(instId) or 0
  param = tonumber(param) or 0
  local lo, hi = M.pack_nibbles(value8)
  local body = b(ID_YAMAHA) .. b(FB01_GROUP) .. b(sysCh & 0x0F)
            .. b(0x18 + (instId & 0x07))
            .. b(0x40 + (param & 0x7F))
            .. b(lo) .. b(hi)
  return M.frame(body)
end

-- Operator parameter change (8-bit value, nibble-split)
-- Operateur::Envoyer computes an address:
-- addr = param + (3-opId)*8 + 0x50   (since OPERATOR_LEN_SYSEX=0x10, /2 = 8)
-- Then sends same format as voice param, but address is (0x40+addr)
function M.operator_param(sysCh, instId, opId, param, value8)
  sysCh = tonumber(sysCh) or M.DEFAULT_SYSCH
  instId = tonumber(instId) or 0
  opId = tonumber(opId) or 0 -- 0..3 (OP1..OP4)
  param = tonumber(param) or 0
  local addr = (param & 0x7F) + (3 - (opId & 0x03)) * 8 + 0x50
  local lo, hi = M.pack_nibbles(value8)
  local body = b(ID_YAMAHA) .. b(FB01_GROUP) .. b(sysCh & 0x0F)
            .. b(0x18 + (instId & 0x07))
            .. b(0x40 + (addr & 0x7F))
            .. b(lo) .. b(hi)
  return M.frame(body)
end

-- Instrument parameter change (7-bit value)
-- Instrument::Envoyer: F0 43 75 sysCh (0x18+(instId&7)) (param&0x1F) value F7
function M.instrument_param(sysCh, instId, param, value7)
  sysCh = tonumber(sysCh) or M.DEFAULT_SYSCH
  instId = tonumber(instId) or 0
  param = tonumber(param) or 0
  value7 = math.floor(tonumber(value7) or 0)
  if value7 < 0 then value7=0 elseif value7>127 then value7=127 end
  local body = b(ID_YAMAHA) .. b(FB01_GROUP) .. b(sysCh & 0x0F)
            .. b(0x18 + (instId & 0x07))
            .. b(param & 0x1F)
            .. b(value7 & 0x7F)
  return M.frame(body)
end

-- Requests
-- Voice request: F0 43 75 sysCh (0x20 + ((instId+0x08)&0x0F)) 00 00 F7
function M.request_voice(sysCh, instId)
  sysCh = tonumber(sysCh) or M.DEFAULT_SYSCH
  instId = tonumber(instId) or 0
  local body = b(ID_YAMAHA) .. b(FB01_GROUP) .. b(sysCh & 0x0F)
            .. b(0x20 + ((instId + 0x08) & 0x0F))
            .. b(0x00) .. b(0x00)
  return M.frame(body)
end

-- Set request: F0 43 75 sysCh 20 01 00 F7
function M.request_set(sysCh)
  sysCh = tonumber(sysCh) or M.DEFAULT_SYSCH
  local body = b(ID_YAMAHA) .. b(FB01_GROUP) .. b(sysCh & 0x0F)
            .. b(0x20) .. b(0x01) .. b(0x00)
  return M.frame(body)
end

-- Bank request: F0 43 75 sysCh 20 00 bankId F7 (bankId 0..7)
function M.request_bank(sysCh, bankId)
  sysCh = tonumber(sysCh) or M.DEFAULT_SYSCH
  bankId = tonumber(bankId) or 0
  local body = b(ID_YAMAHA) .. b(FB01_GROUP) .. b(sysCh & 0x0F)
            .. b(0x20) .. b(0x00) .. b(bankId & 0x07)
  return M.frame(body)
end

return M
