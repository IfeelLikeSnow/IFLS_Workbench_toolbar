-- @description IFLS PSS-580 - Safe Audition (manual backup capture -> audition -> revert)
-- @version 1.01.0
-- @author IFLS
-- @about
--   Because PSS-x80 request-dump command isn't reliably standardized across docs,
--   this tool captures a backup by recording SysEx while you manually transmit a voice from the keyboard.
--   Then it sends an audition voice and can revert by re-sending the backup.
--
-- Requirements:
--  - SWS (SNM_SendSysEx)
--  - Track input set to PSS MIDI IN (SysEx enabled)

local r=reaper
if not r.SNM_SendSysEx then r.MB("SWS not found.", "PSS Safe Audition", 0); return end

local root = r.GetResourcePath().."/Scripts/IFLS_Workbench"

local function ensure_track()
  local tr=r.GetSelectedTrack(0,0)
  if tr then return tr end
  r.InsertTrackAtIndex(r.CountTracks(0), true)
  tr=r.GetTrack(0, r.CountTracks(0)-1)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", "PSS-x80 SysEx Capture", true)
  r.SetOnlyTrackSelected(tr)
  return tr
end

local function last_item(tr)
  local c=r.CountTrackMediaItems(tr)
  if c==0 then return nil end
  return r.GetTrackMediaItem(tr, c-1)
end

local function export_item_to_syx(item, path)
  r.SelectAllMediaItems(0, false)
  r.SetMediaItemSelected(item, true)
  r.UpdateArrange()
  r.SetExtState("IFLS_PSS580","EXPORT_SYX_PATH", path, false)
  -- reuse generic exporter if present; fallback: user must export with existing FB-01 exporter won't work for PSS items
  local exporter = root.."/Workbench/FB01/Pack_v8/Scripts/IFLS_FB01_Export_SelectedItem_SysEx_To_SYX.lua"
  local f=io.open(exporter,"rb")
  if f then f:close(); dofile(exporter); return true end
  return false
end

local function send_file(path)
  local f=io.open(path,"rb"); if not f then return end
  local d=f:read("*all"); f:close()
  r.SNM_SendSysEx(d)
end

local ok, csv = r.GetUserInputs("PSS Safe Audition", 1, "Capture seconds (while you transmit voice)", "5")
if not ok then return end
local secs = tonumber(csv) or 5

local ok2, audition = r.GetUserFileNameForRead("", "Select audition voice .syx", ".syx")
if not ok2 or audition=="" then return end

local ts=os.date("!%Y%m%d_%H%M%S")
local backup_path = r.GetResourcePath().."/Scripts/IFLS_Workbench/Docs/Reports/PSS_AuditionBackup_"..ts..".syx"

local tr=ensure_track()
r.SetMediaTrackInfo_Value(tr, "I_RECARM", 1)

r.MB("Next: REAPER will record for "..secs.."s.\nDuring recording, trigger VOICE TRANSMIT/DUMP on the PSS keyboard.\nThen audition will be sent.", "PSS Safe Audition", 0)

r.Main_OnCommand(1013, 0) -- record
r.Sleep(secs*1000)
r.Main_OnCommand(1016, 0) -- stop
r.Sleep(250)

local item=last_item(tr)
if not item then r.MB("No SysEx captured. Check MIDI input.", "PSS Safe Audition", 0); return end

local okexp = export_item_to_syx(item, backup_path)
if not okexp then
  r.MB("Captured item, but exporter script not found.\nYou can still revert by keeping the recorded MIDI item.", "PSS Safe Audition", 0)
end

send_file(audition)

local ret = r.MB("Audition sent. Revert to backup now?", "PSS Safe Audition", 4)
if ret==6 then
  if okexp then send_file(backup_path) end
  r.MB("Revert done. Backup at:\n"..backup_path, "PSS Safe Audition", 0)
end
