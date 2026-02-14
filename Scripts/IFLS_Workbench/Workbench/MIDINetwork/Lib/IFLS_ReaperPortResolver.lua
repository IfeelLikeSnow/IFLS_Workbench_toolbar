-- IFLS Reaper Port Resolver
-- Version: 0.80.0
--
-- Enumerates REAPER MIDI ports and matches by:
--   1) exact name (preferred)
--   2) substring contains (fallback)

local r = reaper
local M = {}

function M.list_inputs()
  local t={}
  local n=r.GetNumMIDIInputs()
  for i=0,n-1 do
    local ok,name=r.GetMIDIInputName(i,"")
    if ok then t[#t+1]={idx=i,name=name} end
  end
  return t
end

function M.list_outputs()
  local t={}
  local n=r.GetNumMIDIOutputs()
  for i=0,n-1 do
    local ok,name=r.GetMIDIOutputName(i,"")
    if ok then t[#t+1]={idx=i,name=name} end
  end
  return t
end

local function find_exact(list, name)
  if not name or name=="" then return nil end
  for _,it in ipairs(list) do
    if it.name == name then return it end
  end
  return nil
end

local function find_contains(list, needle)
  if not needle or needle=="" then return nil end
  local n=needle:lower()
  local first=nil
  local count=0
  for _,it in ipairs(list) do
    if (it.name or ""):lower():find(n,1,true) then
      count=count+1
      if not first then first=it end
    end
  end
  return first, count
end

function M.match_input(in_exact, in_contains)
  local ins=M.list_inputs()
  local hit=find_exact(ins, in_exact)
  if hit then return hit, "exact", 1 end
  local h,c=find_contains(ins, in_contains)
  if h then return h, "contains", c end
  return nil, "none", 0
end

function M.match_output(out_exact, out_contains)
  local outs=M.list_outputs()
  local hit=find_exact(outs, out_exact)
  if hit then return hit, "exact", 1 end
  local h,c=find_contains(outs, out_contains)
  if h then return h, "contains", c end
  return nil, "none", 0
end

return M
