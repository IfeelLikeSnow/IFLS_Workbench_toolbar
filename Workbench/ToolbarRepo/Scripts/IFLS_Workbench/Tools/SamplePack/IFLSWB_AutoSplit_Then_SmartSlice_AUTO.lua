-- @description IFLS WB: AutoSplit + SmartSlice AUTO (mixed content heuristic)
-- @version 1.0.3
-- @author IFLS Workbench
-- @about One-click: AutoSplit mixed content into HIT_/TEX_/MIX_ chunks using confidence scoring, then runs SmartSlice(Hits) for HIT and SmartSlice(Textures) for TEX+MIX. Optional PostFix HQ over the affected time-range.
-- @provides [main] .


local r = reaper

local function join(a,b)
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then return a..b end
  local sep = r.GetOS():match("Win") and "\\" or "/"
  return a..sep..b
end

local function file_exists(p)
  local f = io.open(p,"rb")
  if f then f:close(); return true end
  return false
end

local function register_and_run(relpath)
  local abs = join(r.GetResourcePath(), relpath)
  if not file_exists(abs) then return false, ("Missing: %s"):format(relpath) end
  local cmd = r.AddRemoveReaScript(true, 0, abs, true)
  if not cmd or cmd == 0 then return false, ("Could not register: %s"):format(relpath) end
  r.Main_OnCommand(cmd, 0)
  return true
end

local function get_take_name(item)
  local take = r.GetActiveTake(item)
  if not take or r.TakeIsMIDI(take) then return "" end
  local _, nm = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
  return nm or ""
end

local function is_hit_item(item)
  local nm = get_take_name(item)
  if nm:sub(1,4) == "HIT_" then return true end
  if nm:sub(1,4) == "TEX_" then return false end
  if nm:sub(1,4) == "MIX_" then return false end
  local len = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  return (len > 0 and len <= 1.25)
end

local function collect_selected_items()
  local n = r.CountSelectedMediaItems(0)
  local items = {}
  for i=0,n-1 do items[#items+1] = r.GetSelectedMediaItem(0,i) end
  return items
end

local function select_items(list)
  r.SelectAllMediaItems(0, false)
  for _,it in ipairs(list) do r.SetMediaItemSelected(it, true) end
end

local function ask_postfix()
  local ok, ret = r.GetUserInputs("AutoSplit + AutoSlice", 1, "Run PostFix HQ after slicing? (1=yes,0=no)", "1")
  if not ok then return false end
  return (tonumber(ret) or 1) ~= 0
end

local function capture_scope(items)
  -- per track: min/max time range to later re-select all affected items/slices
  local scope = {}
  for _,it in ipairs(items) do
    local tr = r.GetMediaItem_Track(it)
    local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
    local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
    local fin = pos + len
    local s = scope[tr]
    if not s then
      scope[tr] = {min=pos, max=fin}
    else
      if pos < s.min then s.min = pos end
      if fin > s.max then s.max = fin end
    end
  end
  return scope
end

local function select_scope(scope, pad_s)
  pad_s = pad_s or 0.25
  r.SelectAllMediaItems(0, false)
  for tr, s in pairs(scope) do
    local min_t = s.min - pad_s
    local max_t = s.max + pad_s
    local n = r.CountTrackMediaItems(tr)
    for i=0,n-1 do
      local it = r.GetTrackMediaItem(tr, i)
      local pos = r.GetMediaItemInfo_Value(it, "D_POSITION")
      local len = r.GetMediaItemInfo_Value(it, "D_LENGTH")
      local fin = pos + len
      if fin >= min_t and pos <= max_t then
        r.SetMediaItemSelected(it, true)
      end
    end
  end
end

local function main()
  local original = collect_selected_items()
  if #original == 0 then
    r.MB("Select one or more fieldrec items first.", "IFLSWB AutoSplit+AutoSlice", 0)
    return
  end

  local scope = capture_scope(original)
  local do_postfix = ask_postfix()

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  -- Step 1: AutoSplit (selects created chunks)
  local ok1, err1 = register_and_run("Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_AutoSplit_MixedContent.lua")
  if not ok1 then
    r.PreventUIRefresh(-1)
    r.Undo_EndBlock("IFLS WB: AutoSplit + AutoSlice AUTO (failed)", -1)
    r.MB(err1 or "AutoSplit failed.", "IFLSWB AutoSplit+AutoSlice", 0)
    return
  end

  -- Step 2: split selection into HIT/TEX lists
  local chunks = collect_selected_items()
  local hits, tex, mix = {}, {}, {}
  for _,it in ipairs(chunks) do
    local nm = get_take_name(it)
    if nm:sub(1,4) == "MIX_" then
      mix[#mix+1] = it
    elseif is_hit_item(it) then
      hits[#hits+1] = it
    else
      tex[#tex+1] = it
    end
  end

  -- Step 3: SmartSlice per group (selection-based scripts)
  if #hits > 0 then
    select_items(hits)
    register_and_run("Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_Hits.lua")
  end
  if #tex > 0 then
    select_items(tex)
    register_and_run("Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_Textures.lua")
  end
  if #mix > 0 then
    -- MIX chunks are treated as textures by default (safer / fewer micro-slices)
    select_items(mix)
    register_and_run("Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Fieldrec_SmartSlice_Textures.lua")
  end

  -- Step 4: optional PostFix HQ over affected time-range (robust)
  if do_postfix then
    select_scope(scope, 0.5)
    register_and_run("Scripts/IFLS_Workbench/Slicing/IFLS_Workbench_Slicing_PostFix_Extend_And_TailDetect.lua")
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS WB: AutoSplit + AutoSlice AUTO", -1)
end

main()