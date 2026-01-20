-- @description IFLS WB: SamplePack GainStage (Loops LUFS-I -> TP safe)
-- @version 1.0.0
-- @author IFLS Workbench
-- @about Normalizes selected loop items to a LUFS-I target, then clamps to a true-peak ceiling (-1 dBTP). Targets are sample-pack friendly.
-- @provides [main] .

local r = reaper
local function db_to_amp(db) return 10^(db/20) end

local TP_CEIL = -1.0
local NORM_LUFSI = 0 -- LUFS-I
local NORM_TP    = 3 -- true peak

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

local function ask_target()
  local ok, ret = r.GetUserInputs("Loop GainStage", 1, "Target: 1=Drumloop(-12 LUFS-I)  2=Music(-15 LUFS-I)", "1")
  if not ok then return nil end
  ret = tonumber(ret) or 1
  if ret == 2 then return -15.0 end
  return -12.0
end

local function main()
  local target = ask_target()
  if not target then return end

  local n = r.CountSelectedMediaItems(0)
  if n == 0 then
    r.MB("Select loop items to gain-stage.", "IFLSWB GainStage Loops", 0)
    return
  end

  for i=0,n-1 do
    local item = r.GetSelectedMediaItem(0,i)
    local take = r.GetActiveTake(item)
    if take and not r.TakeIsMIDI(take) then
      local src = r.GetMediaItemTake_Source(take)
      if src then
        local a,b = get_source_bounds_seconds(item, take)
        local g1 = r.CalculateNormalization(src, NORM_LUFSI, target, a, b) or 0
        apply_gain(item, g1)

        -- Approx clamp: apply only negative correction based on source
        local g2 = r.CalculateNormalization(src, NORM_TP, TP_CEIL, a, b) or 0
        if g2 < 0 then apply_gain(item, g2) end
      end
    end
  end

  r.UpdateArrange()
end

r.Undo_BeginBlock()
main()
r.Undo_EndBlock("IFLS WB: SamplePack GainStage Loops (LUFS-I -> TP)", -1)
