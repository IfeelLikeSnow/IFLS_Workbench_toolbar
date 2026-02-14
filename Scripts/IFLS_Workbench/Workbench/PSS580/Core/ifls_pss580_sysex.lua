-- IFLS PSS-x80 (PSS-480/580/680/780) SysEx helpers (derived from PSS-Revive reference implementation)
-- Voice dump SysEx: F0 43 76 00 <66 nibbles> <checksum> F7
-- VMEM: 33 bytes, transferred as 66 4-bit nibbles (hi nibble first).
-- checksum: ((not (sum(VMEM) & 0xFF)) & 0x7F) + 1

local M = {}

local function clamp(v,a,b) if v<a then return a elseif v>b then return b else return v end end

function M.is_pss_voice_dump(msg)
  if type(msg)~="string" then return false end
  if #msg ~= 72 then return false end
  if msg:byte(1)~=0xF0 or msg:byte(2)~=0x43 or msg:byte(3)~=0x76 or msg:byte(4)~=0x00 then return false end
  if msg:byte(#msg)~=0xF7 then return false end
  return true
end

function M.split_sysex(blob)
  local msgs={}
  local i=1
  while true do
    local s=blob:find(string.char(0xF0), i, true); if not s then break end
    local e=blob:find(string.char(0xF7), s+1, true); if not e then break end
    msgs[#msgs+1]=blob:sub(s,e)
    i=e+1
  end
  return msgs
end

function M.unpack_vmem_from_voice_dump(msg)
  assert(M.is_pss_voice_dump(msg), "not a PSS-x80 72-byte voice dump")
  local vmem={}
  local pos=5 -- after F0 43 76 00
  for i=1,33 do
    local hi = (msg:byte(pos) or 0) & 0x0F
    local lo = (msg:byte(pos+1) or 0) & 0x0F
    pos = pos + 2
    vmem[i] = (hi<<4) | lo
  end
  local checksum = msg:byte(pos) or 0
  return vmem, checksum
end

function M.checksum_vmem(vmem)
  local sum=0
  for i=1,33 do sum = sum + (vmem[i] or 0) end
  local res = ((~(sum & 0xFF)) & 0x7F) + 1
  return res & 0x7F
end

function M.pack_voice_dump_from_vmem(vmem)
  local out={ string.char(0xF0,0x43,0x76,0x00) }
  for i=1,33 do
    local b = clamp(tonumber(vmem[i] or 0), 0, 255)
    local hi = (b >> 4) & 0x0F
    local lo = b & 0x0F
    out[#out+1] = string.char(hi, lo)
  end
  local cs = M.checksum_vmem(vmem)
  out[#out+1] = string.char(cs, 0xF7)
  return table.concat(out,"")
end

-- VMEM field layout (byte indices 1..33)
-- derived from TPSSx80_VMEM_Params packed record (PSS-Revive)
local VMEM_FIELDS = {
  "BANK",
  "M_DT1_MUL","C_DT1_MUL",
  "M_TL","C_TL",
  "M_LKS_HI_LKS_LO","C_LKS_HI_LKS_LO",
  "M_RKS_AR","C_RKS_AR",
  "M_AM_EN_DT2_D1R","C_AM_EN_DT2_D1R",
  "M_SIN_TBL_D2R","C_SIN_TBL_D2R",
  "M_D1L_RR","C_D1L_RR",
  "M_FB","PMS_AMS",
  "Reserved_17","Reserved_18","Reserved_19",
  "M_SRR","C_SRR",
  "VDT","Reserved_23","V_S",
  "Reserved_25","Reserved_26","Reserved_27","Reserved_28","Reserved_29","Reserved_30","Reserved_31","Reserved_32"
}

function M.vmem_to_fields(vmem)
  local t={}
  for i=1,33 do t[VMEM_FIELDS[i]] = vmem[i] or 0 end
  return t
end

function M.fields_to_vmem(f)
  local v={}
  for i=1,33 do v[i] = clamp(tonumber(f[VMEM_FIELDS[i]] or 0), 0, 255) end
  return v
end

-- VCED params (decoded, editable)
-- derived from TPSSx80_VCED_Params and VMEMtoVCED/VCEDtoVMEM in PSS-Revive.
function M.vmem_to_vced(vmem)
  local a = M.vmem_to_fields(vmem)
  local t={}
  t.BANK = a.BANK & 7

  t.M_DT1 = (a.M_DT1_MUL >> 4) & 15
  t.M_MUL = a.M_DT1_MUL & 15
  t.M_TL  = a.M_TL & 127
  t.M_LKS_HI = (a.M_LKS_HI_LKS_LO >> 4) & 15
  t.M_LKS_LO = a.M_LKS_HI_LKS_LO & 15
  t.M_RKS = (a.M_RKS_AR >> 6) & 3
  t.M_AR  = a.M_RKS_AR & 63
  t.M_AM_EN = (a.M_AM_EN_DT2_D1R >> 7) & 1
  t.M_DT2   = (a.M_AM_EN_DT2_D1R >> 6) & 1
  t.M_D1R   = a.M_AM_EN_DT2_D1R & 63
  t.M_SIN_TBL = (a.M_SIN_TBL_D2R >> 6) & 3
  t.M_D2R     = a.M_SIN_TBL_D2R & 63
  t.M_D1L     = (a.M_D1L_RR >> 4) & 15
  t.M_RR      = a.M_D1L_RR & 15
  t.M_SRR     = a.M_SRR & 15
  t.M_FB      = (a.M_FB >> 3) & 7

  t.C_DT1 = (a.C_DT1_MUL >> 4) & 15
  t.C_MUL = a.C_DT1_MUL & 15
  t.C_TL  = a.C_TL & 127
  t.C_LKS_HI = (a.C_LKS_HI_LKS_LO >> 4) & 15
  t.C_LKS_LO = a.C_LKS_HI_LKS_LO & 15
  t.C_RKS = (a.C_RKS_AR >> 6) & 3
  t.C_AR  = a.C_RKS_AR & 63
  t.C_AM_EN = (a.C_AM_EN_DT2_D1R >> 7) & 1
  t.C_DT2   = (a.C_AM_EN_DT2_D1R >> 6) & 1
  t.C_D1R   = a.C_AM_EN_DT2_D1R & 63
  t.C_SIN_TBL = (a.C_SIN_TBL_D2R >> 6) & 3
  t.C_D2R     = a.C_SIN_TBL_D2R & 63
  t.C_D1L     = (a.C_D1L_RR >> 4) & 15
  t.C_RR      = a.C_D1L_RR & 15
  t.C_SRR     = a.C_SRR & 15

  t.PMS = (a.PMS_AMS >> 4) & 7
  t.AMS = a.PMS_AMS & 3
  t.VDT = a.VDT & 127
  t.V = (a.V_S >> 7) & 1
  t.S = (a.V_S >> 6) & 1

  -- keep "D_*" bits (reserved/unknown) preserved for safe roundtrips
  t.D_3_7    = (a.M_TL >> 7) & 1
  t.D_4_7    = (a.C_TL >> 7) & 1
  t.D_15_76  = (a.M_FB >> 6) & 3
  t.D_15_210 = a.M_FB & 7
  t.D_16_7   = (a.PMS_AMS >> 7) & 1
  t.D_16_32  = (a.PMS_AMS >> 2) & 3
  t.D_20_Hi  = (a.M_SRR >> 4) & 15
  t.D_21_Hi  = (a.C_SRR >> 4) & 15
  t.D_22_7   = (a.VDT >> 7) & 1
  t.D_24_54  = (a.V_S >> 4) & 3
  t.D_24_Lo  = a.V_S & 15

  -- nibbles from reserved bytes
  local function split_nibbles(b) return (b>>4)&15, b&15 end
  t.D_17_Hi, t.D_17_Lo = split_nibbles(a.Reserved_17)
  t.D_18_Hi, t.D_18_Lo = split_nibbles(a.Reserved_18)
  t.D_19_Hi, t.D_19_Lo = split_nibbles(a.Reserved_19)
  t.D_23_Hi, t.D_23_Lo = split_nibbles(a.Reserved_23)
  t.D_25_Hi, t.D_25_Lo = split_nibbles(a.Reserved_25)
  t.D_26_Hi, t.D_26_Lo = split_nibbles(a.Reserved_26)
  t.D_27_Hi, t.D_27_Lo = split_nibbles(a.Reserved_27)
  t.D_28_Hi, t.D_28_Lo = split_nibbles(a.Reserved_28)
  t.D_29_Hi, t.D_29_Lo = split_nibbles(a.Reserved_29)
  t.D_30_Hi, t.D_30_Lo = split_nibbles(a.Reserved_30)
  t.D_31_Hi, t.D_31_Lo = split_nibbles(a.Reserved_31)
  t.D_32_Hi, t.D_32_Lo = split_nibbles(a.Reserved_32)

  return t
end

function M.vced_to_vmem(vced)
  local a=vced or {}
  local f = {}
  -- first fill everything with 0 then set fields
  for i=1,33 do f[VMEM_FIELDS[i]] = 0 end

  -- preserve D_* bits if provided (else default to 0)
  local D3_7    = (a.D_3_7 or 0) & 1
  local D4_7    = (a.D_4_7 or 0) & 1
  local D15_76  = (a.D_15_76 or 0) & 3
  local D15_210 = (a.D_15_210 or 0) & 7
  local D16_7   = (a.D_16_7 or 0) & 1
  local D16_32  = (a.D_16_32 or 0) & 3
  local D20_Hi  = (a.D_20_Hi or 0) & 15
  local D21_Hi  = (a.D_21_Hi or 0) & 15
  local D22_7   = (a.D_22_7 or 0) & 1
  local D24_54  = (a.D_24_54 or 0) & 3
  local D24_Lo  = (a.D_24_Lo or 0) & 15

  f.BANK = (a.BANK or 0) & 7

  f.M_DT1_MUL = (((a.M_DT1 or 0) & 15) << 4) | ((a.M_MUL or 0) & 15)
  f.M_TL = ((D3_7 << 7) & 0x80) | ((a.M_TL or 0) & 0x7F)
  f.M_LKS_HI_LKS_LO = (((a.M_LKS_HI or 0) & 15) << 4) | ((a.M_LKS_LO or 0) & 15)
  f.M_RKS_AR = (((a.M_RKS or 0) & 3) << 6) | ((a.M_AR or 0) & 63)
  f.M_AM_EN_DT2_D1R = (((a.M_AM_EN or 0) & 1) << 7) | (((a.M_DT2 or 0) & 1) << 6) | ((a.M_D1R or 0) & 63)
  f.M_SIN_TBL_D2R = (((a.M_SIN_TBL or 0) & 3) << 6) | ((a.M_D2R or 0) & 63)
  f.M_D1L_RR = (((a.M_D1L or 0) & 15) << 4) | ((a.M_RR or 0) & 15)
  f.M_SRR = ((D20_Hi << 4) & 0xF0) | ((a.M_SRR or 0) & 15)
  f.M_FB = ((D15_76 << 6) & 0xC0) | (((a.M_FB or 0) << 3) & 0x38) | (D15_210 & 7)

  f.C_DT1_MUL = (((a.C_DT1 or 0) & 15) << 4) | ((a.C_MUL or 0) & 15)
  f.C_TL = ((D4_7 << 7) & 0x80) | ((a.C_TL or 0) & 0x7F)
  f.C_LKS_HI_LKS_LO = (((a.C_LKS_HI or 0) & 15) << 4) | ((a.C_LKS_LO or 0) & 15)
  f.C_RKS_AR = (((a.C_RKS or 0) & 3) << 6) | ((a.C_AR or 0) & 63)
  f.C_AM_EN_DT2_D1R = (((a.C_AM_EN or 0) & 1) << 7) | (((a.C_DT2 or 0) & 1) << 6) | ((a.C_D1R or 0) & 63)
  f.C_SIN_TBL_D2R = (((a.C_SIN_TBL or 0) & 3) << 6) | ((a.C_D2R or 0) & 63)
  f.C_D1L_RR = (((a.C_D1L or 0) & 15) << 4) | ((a.C_RR or 0) & 15)
  f.C_SRR = ((D21_Hi << 4) & 0xF0) | ((a.C_SRR or 0) & 15)

  f.PMS_AMS = ((D16_7 << 7) & 0x80) | (((a.PMS or 0) << 4) & 0x70) | ((a.AMS or 0) & 3) | ((D16_32 << 2) & 0x0C)
  f.VDT = ((D22_7 << 7) & 0x80) | ((a.VDT or 0) & 0x7F)
  f.V_S = (((a.V or 0) & 1) << 7) | (((a.S or 0) & 1) << 6) | ((D24_54 << 4) & 0x30) | (D24_Lo & 0x0F)

  local function join_nibbles(hi,lo) return ((hi & 15) << 4) | (lo & 15) end
  f.Reserved_17 = join_nibbles(a.D_17_Hi or 0, a.D_17_Lo or 0)
  f.Reserved_18 = join_nibbles(a.D_18_Hi or 0, a.D_18_Lo or 0)
  f.Reserved_19 = join_nibbles(a.D_19_Hi or 0, a.D_19_Lo or 0)
  f.Reserved_23 = join_nibbles(a.D_23_Hi or 0, a.D_23_Lo or 0)
  f.Reserved_25 = join_nibbles(a.D_25_Hi or 0, a.D_25_Lo or 0)
  f.Reserved_26 = join_nibbles(a.D_26_Hi or 0, a.D_26_Lo or 0)
  f.Reserved_27 = join_nibbles(a.D_27_Hi or 0, a.D_27_Lo or 0)
  f.Reserved_28 = join_nibbles(a.D_28_Hi or 0, a.D_28_Lo or 0)
  f.Reserved_29 = join_nibbles(a.D_29_Hi or 0, a.D_29_Lo or 0)
  f.Reserved_30 = join_nibbles(a.D_30_Hi or 0, a.D_30_Lo or 0)
  f.Reserved_31 = join_nibbles(a.D_31_Hi or 0, a.D_31_Lo or 0)
  f.Reserved_32 = join_nibbles(a.D_32_Hi or 0, a.D_32_Lo or 0)

  return M.fields_to_vmem(f)
end

-- Safe parameter ranges for randomization (decoded VCED domain)
M.VCED_RANGES = {
  BANK={0,7},
  M_DT1={0,15}, M_MUL={0,15}, M_TL={0,127}, M_LKS_HI={0,15}, M_LKS_LO={0,15}, M_RKS={0,3}, M_AR={0,63}, M_AM_EN={0,1}, M_DT2={0,1},
  M_D1R={0,63}, M_SIN_TBL={0,3}, M_D2R={0,63}, M_D1L={0,15}, M_RR={0,15}, M_SRR={0,15}, M_FB={0,7},
  C_DT1={0,15}, C_MUL={0,15}, C_TL={0,127}, C_LKS_HI={0,15}, C_LKS_LO={0,15}, C_RKS={0,3}, C_AR={0,63}, C_AM_EN={0,1}, C_DT2={0,1},
  C_D1R={0,63}, C_SIN_TBL={0,3}, C_D2R={0,63}, C_D1L={0,15}, C_RR={0,15}, C_SRR={0,15},
  PMS={0,7}, AMS={0,3}, VDT={0,127}, V={0,1}, S={0,1},
}

-- Randomize VCED with intensity, locks, and scopes (safe: preserves all unknown bits as-is).
-- locks: table[param]=true to keep unchanged
-- scope: "full"|"ops_env"|"ops_pitch"|"ops_timbre"|"global"
function M.randomize_vced(vced, intensity, locks, scope)
  local out={}
  for k,v in pairs(vced) do out[k]=v end
  intensity = tonumber(intensity) or 1.0
  if intensity<0 then intensity=0 elseif intensity>1 then intensity=1 end
  locks = locks or {}
  scope = scope or "full"

  local function in_scope(param)
    if scope=="full" then return true end
    if scope=="global" then
      return (param=="PMS" or param=="AMS" or param=="VDT" or param=="V" or param=="S" or param=="BANK")
    end
    local is_op = param:match("^[MC]_")
    if not is_op then return false end
    if scope=="ops_env" then
      return param:find("_AR") or param:find("_D1R") or param:find("_D2R") or param:find("_D1L") or param:find("_RR") or param:find("_SRR")
    end
    if scope=="ops_pitch" then
      return param:find("_MUL") or param:find("_DT1") or param:find("_DT2")
    end
    if scope=="ops_timbre" then
      return param:find("_TL") or param:find("_SIN_TBL") or param:find("_AM_EN") or param:find("_FB")
    end
    return true
  end

  for param,range in pairs(M.VCED_RANGES) do
    if in_scope(param) and not locks[param] then
      local lo,hi = range[1], range[2]
      local cur = tonumber(out[param] or 0)
      local rnd = math.random(lo,hi)
      local v = math.floor(cur*(1-intensity) + rnd*intensity + 0.5)
      out[param] = clamp(v, lo, hi)
    end
  end
  return out
end

return M
