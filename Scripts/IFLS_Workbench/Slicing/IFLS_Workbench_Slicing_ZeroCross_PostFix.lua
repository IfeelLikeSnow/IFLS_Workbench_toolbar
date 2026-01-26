-- @description IFLS Workbench - Slicing: ZeroCross PostFix (safe fades)
-- @author IFLS / DF95
-- @version 0.7.6
-- @about Auto-added @about (please replace with a real description).
-- @changelog
--   + Remove unreliable/made-up action IDs (caused no-ops / errors on some systems)
--   + Safer: apply minimal fades only (prevents clicks after slicing)
--   + Preserve existing fades (only increases if needed)

-- What this does:
--   If IFLS_SLICING/ZC_RESPECT == 1, apply short fades to selected items.
--   This is a robust "click prevention" post-fix after heavy slicing (transients, remove-silence, etc).
--
-- NOTE:
--   True "snap edges to nearest zero crossing" is intentionally NOT done here
--   because reliable action IDs vary across installs and item-edge snapping can
--   break gap-filling workflows by shifting item positions.
--
-- Config (optional project extstate keys):
--   IFLS_SLICING/ZC_FADEIN_MS   (default 4)
--   IFLS_SLICING/ZC_FADEOUT_MS  (default 6)
--   IFLS_SLICING/ZC_SHAPE       (linear|slow|fast, default fast)

local r = reaper

local function get_ext(key, default)
  local v = ({r.GetProjExtState(0, "IFLS_SLICING", key)})[2]
  if v == nil or v == "" then return default end
  return v
end

local function as_number(v, default)
  local n = tonumber(v)
  if not n then return default end
  return n
end

local function shape_to_idx(shape)
  -- REAPER item fade shape indices:
  -- 0=linear, 1=slow start/end, 2=fast start, etc.
  -- We only use a conservative subset.
  if shape == "slow" then return 1 end
  if shape == "linear" then return 0 end
  return 2 -- fast
end

local function main()
  local flag = ({r.GetProjExtState(0, "IFLS_SLICING", "ZC_RESPECT")})[2]
  if flag ~= "1" then return end

  local n = r.CountSelectedMediaItems(0)
  if n == 0 then return end

  local fadein_ms  = as_number(get_ext("ZC_FADEIN_MS",  "4"), 4)
  local fadeout_ms = as_number(get_ext("ZC_FADEOUT_MS", "6"), 6)
  local shape = get_ext("ZC_SHAPE", get_ext("FADE_SHAPE", "fast"))
  local shape_idx = shape_to_idx(shape)

  local fin = math.max(0.0, fadein_ms / 1000.0)
  local fout = math.max(0.0, fadeout_ms / 1000.0)

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  for i=0, n-1 do
    local it = r.GetSelectedMediaItem(0, i)
    if it then
      local cur_in = r.GetMediaItemInfo_Value(it, "D_FADEINLEN") or 0.0
      local cur_out = r.GetMediaItemInfo_Value(it, "D_FADEOUTLEN") or 0.0

      if fin > cur_in then r.SetMediaItemInfo_Value(it, "D_FADEINLEN", fin) end
      if fout > cur_out then r.SetMediaItemInfo_Value(it, "D_FADEOUTLEN", fout) end

      r.SetMediaItemInfo_Value(it, "C_FADEINSHAPE", shape_idx)
      r.SetMediaItemInfo_Value(it, "C_FADEOUTSHAPE", shape_idx)
    end
  end

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS Slicing ZeroCross PostFix (fades)", -1)
end

main()
