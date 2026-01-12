-- @description IFLS Workbench: Apply MicFX By TrackName v2 (default profile)
-- @version 0.1.0
-- @author IFLS (ported from DF95)
-- @about
--   Scans selected tracks, detects mic keyword from track name, applies default MicFX chain (Gain + ReaEQ + ReaComp + optional ReaFIR/Meter).

-- IFLS_Workbench_Apply_MicFX_ByTrackName_v2.lua
-- Nutzt DF95_MicProfiles.lua
-- Ziel:
--   - Alle selektierten Tracks scannen
--   - Trackname -> Mic-Key
--   - Mic-Profil "default" anwenden (JS Gain + ReaEQ + ReaComp mit HPF/EQ/Comp-Kurven)

local r = reaper

local ONLY_SELECTED = true

-- locate DF95_MicProfiles module relativ zum ResourcePath
local function load_mic_module()
  local res = r.GetResourcePath()
  local path = res .. "/Scripts/IFLS_Workbench/lib/ifls_workbench_micfx_profiles.lua"
  local ok, mod = pcall(dofile, path)
  if not ok then
    r.ShowMessageBox("DF95_MicProfiles.lua konnte nicht geladen werden:\n" .. tostring(mod), "IFLS Workbench MicFX v2", 0)
    return nil
  end
  return mod
end

local function should_process_track(tr)
  if not ONLY_SELECTED then return true end
  return r.IsTrackSelected(tr)
end

local function main()
  local Mic = load_mic_module()
  if not Mic then return end

  local proj = 0
  local track_count = r.CountTracks(proj)
  if track_count == 0 then return end

  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)

  local processed = 0

  for i = 0, track_count - 1 do
    local tr = r.GetTrack(proj, i)
    if should_process_track(tr) then
      local _, name = r.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
      local mic_key = Mic.get_mic_key_from_trackname(name)
      if mic_key then
        Mic.apply_profile(tr, mic_key, "default")
        local new_name = (name or "") .. " [Mic:" .. mic_key .. "/default]"
        r.GetSetMediaTrackInfo_String(tr, "P_NAME", new_name, true)
        processed = processed + 1
      end
    end
  end

  r.PreventUIRefresh(-1)
  r.Undo_EndBlock("IFLS Workbench Apply MicFX By TrackName v2 (default profile)", -1)

  if processed == 0 then
    r.ShowMessageBox(
      "Keine passenden Mic-Namen auf selektierten Tracks gefunden.\n\n" ..
      "Bitte Tracknamen wie 'xm8500', 'tg v35 s', 'md400', 'b1', 'ntg4+', 'c2', 'geofon', " ..
      "'cortado', 'cm300', 'ether', 'mcm' verwenden.",
      "IFLS Workbench MicFX v2",
      0
    )
  end
end

main()
