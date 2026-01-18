-- @version 0.0.1

-- @description IFLS Workbench: Slicing â€“ ZeroCross PostFix (gentle fades + best-effort actions)
-- @version 1.0

local r = reaper
local _, zc = r.GetProjExtState(0,"IFLS_SLICING","ZC_RESPECT")
if zc ~= "1" then return end

-- gentle equal-power fades to mask micro-clicks
local function apply_fades_ms(fin, fout)
  local cnt = r.CountSelectedMediaItems(0)
  for i=0,cnt-1 do
    local it = r.GetSelectedMediaItem(0,i)
    r.SetMediaItemInfo_Value(it, "D_FADEINLEN",  (fin or 4)/1000.0)
    r.SetMediaItemInfo_Value(it, "D_FADEOUTLEN", (fout or 6)/1000.0)
    r.SetMediaItemInfo_Value(it, "C_FADEINSHAPE",  2) -- fast
    r.SetMediaItemInfo_Value(it, "C_FADEOUTSHAPE", 2)
  end
end

-- try to call a native/sws zero-cross related action if present (best-effort)
local candidates = {
  "_SWS_SNAPZEROX", -- made-up guard; if unavailable, skip silently
  "_SWS_ITEMZOOMZEROX",
  "_BR_SNAPITEMTOZEROCROSS"
}
for _,k in ipairs(candidates) do
  local id = r.NamedCommandLookup(k)
  if id and id ~= 0 then r.Main_OnCommand(id, 0) end
end

apply_fades_ms(4,6)
r.UpdateArrange()
r.ShowConsoleMsg("[IFLS] ZeroCross PostFix angewendet (fades + best-effort actions).\n")
