-- @description IFLS WB: SamplePack GainStage (DRY one-shots peak -3 dBFS)
-- @version 1.0.0
-- @author IFLS Workbench
-- @about Applies item gain so SAMPLE PEAK reaches -3 dBFS (headroom-friendly DRY standard).
-- @provides [main] .


local r = reaper
local function db_to_amp(db) return 10^(db/20) end

local TARGET_DB = -3.0
local NORM_TO = 2 -- peak

local function get_source_bounds_seconds(item, take)
  local startoffs = r.GetMediaItemTakeInfo_Value(take, "D_STARTOFFS")
  local playrate  = r.GetMediaItemTakeInfo_Value(take, "D_PLAYRATE")
  if playrate <= 0 then playrate = 1 end
  local len_proj  = r.GetMediaItemInfo_Value(item, "D_LENGTH")
  return startoffs, startoffs + (len_proj * playrate)
end

local function apply_gain(item, gain_db)
  local take = r.GetActiveTake(item)
  if not take or r.TakeIsMIDI(take) then return false end
  local cur = r.GetMediaItemTakeInfo_Value(take, "D_VOL")
  if cur <= 0 then cur = 1 end
  r.SetMediaItemTakeInfo_Value(take, "D_VOL", cur * db_to_amp(gain_db))
  return true
end

local function main()
  local n = r.CountSelectedMediaItems(0)
  if n == 0 then
    r.MB("Select audio items to gain-stage.", "IFLSWB GainStage DRY", 0)
    return
  end

  for i=0,n-1 do
    local item = r.GetSelectedMediaItem(0,i)
    local take = r.GetActiveTake(item)
    if take and not r.TakeIsMIDI(take) then
      local src = r.GetMediaItemTake_Source(take)
      if src then
        local a,b = get_source_bounds_seconds(item, take)
        local gain_db = r.CalculateNormalization(src, NORM_TO, TARGET_DB, a, b) or 0
        apply_gain(item, gain_db)
      end
    end
  end

  r.UpdateArrange()
end

r.Undo_BeginBlock()
main()
r.Undo_EndBlock("IFLS WB: SamplePack GainStage DRY (peak -3)", -1)
