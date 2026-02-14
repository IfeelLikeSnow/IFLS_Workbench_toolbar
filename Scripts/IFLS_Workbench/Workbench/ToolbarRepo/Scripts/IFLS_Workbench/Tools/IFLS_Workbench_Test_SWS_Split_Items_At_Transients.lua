-- @description IFLS Workbench - Workbench/ToolbarRepo/Scripts/IFLS_Workbench/Tools/IFLS_Workbench_Test_SWS_Split_Items_At_Transients.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Test SWS Xenakios Split Items At Transients
-- @version 0.7.5
-- @about
--   Verifies that the SWS action "Xenakios/SWS: Split items at transients" is available and actually produces splits.
--   Reports before/after item counts and gives troubleshooting hints if 0 splits happen.


local r = reaper

local function msg(s) r.ShowConsoleMsg(tostring(s).."\n") end

local function count_selected_items()
  return r.CountSelectedMediaItems(0)
end

local function count_items_in_track(tr)
  local n = 0
  if not tr then return 0 end
  n = r.CountTrackMediaItems(tr)
  return n
end

local function main()
  r.ClearConsole()
  msg("IFLS: Test Xenakios/SWS Split items at transients")
  msg("------------------------------------------------")

  local cmd = r.NamedCommandLookup("_XENAKIOS_SPLIT_ITEMSATRANSIENTS")
  if cmd == 0 then
    r.MB("SWS action not found:\n  _XENAKIOS_SPLIT_ITEMSATRANSIENTS\n\nInstall SWS Extension and restart REAPER.", "IFLS SWS Test", 0)
    return
  end

  local item = r.GetSelectedMediaItem(0, 0)
  if not item then
    r.MB("Select ONE audio item with clear transients (e.g. kick/snare loop) and run again.", "IFLS SWS Test", 0)
    return
  end
  local tr = r.GetMediaItemTrack(item)

  -- measure before
  local before_sel = count_selected_items()
  local before_tr = count_items_in_track(tr)

  msg("Before: selected items="..before_sel..", track items="..before_tr)
  msg("Running: Xenakios/SWS: Split items at transients ...")

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  r.Main_OnCommand(cmd, 0)

  r.PreventUIRefresh(-1)
  r.UpdateArrange()
  r.Undo_EndBlock("IFLS: Test SWS Split items at transients", -1)

  local after_sel = count_selected_items()
  local after_tr = count_items_in_track(tr)

  msg("After:  selected items="..after_sel..", track items="..after_tr)

  local delta_tr = after_tr - before_tr
  if delta_tr <= 0 then
    msg("")
    msg("RESULT: 0 new items were created.")
    msg("Troubleshooting:")
    msg("1) The transient sensitivity/threshold may be too strict.")
    msg("   Open: Extensions -> SWS -> Xenakios/SWS command parameters")
    msg("   and adjust parameters for 'Split items at transients'.")
    msg("2) Try a material with sharper transients (click/kick).")
    msg("3) If still 0, use REAPER native alternative:")
    msg("   Item: Dynamic split items... (search in Actions).")
    r.MB("0 splits detected.\n\nMost common cause: SWS transient sensitivity/threshold too strict.\n\nSee REAPER Console for hints.", "IFLS SWS Test", 0)
  else
    r.MB("OK: created "..tostring(delta_tr).." new item(s) on the track.\n\nYour SWS transient split is working.", "IFLS SWS Test", 0)
  end
end

main()
