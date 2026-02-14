-- @description IFLS PSS-580 - Safe Audition Wizard (Backup Capture -> Audition -> Revert) [Auto-capture]
-- @version 1.06.0
-- @author IFLS
-- @about
--  Hardware-first stability:
--   - Auto-capture: starts recording, waits for SysEx (F0..F7) then stops immediately (or times out).
--   - Robust SysEx extraction across split MIDI events.
--   - Writes backups to Scripts/IFLS_Workbench/Docs/Reports/
--
-- Requirements: SWS (SNM_SendSysEx), ReaImGui.

local r=reaper
if not r.ImGui_CreateContext then r.MB("ReaImGui required.", "PSS Safe Audition", 0); return end
if not r.SNM_SendSysEx then r.MB("SWS required (SNM_SendSysEx).", "PSS Safe Audition", 0); return end

local root = r.GetResourcePath().."/Scripts/IFLS_Workbench"
local MidiSyx = dofile(root.."/Workbench/PSS580/Core/ifls_midi_sysex_extract.lua")

local ctx = r.ImGui_CreateContext("IFLS PSS-x80 Safe Audition")
local timeout_secs = 12
local audition_path = ""
local backup_path = r.GetExtState("IFLS_PSS580","SAFE_BACKUP_PATH") or ""
local status = ""
local hint = "Routing tip: mioXM route must ALLOW SysEx; REAPER input device enabled; track input must match the PSS port."
local cap = {active=false, start_time=0.0, track=nil, found_count=0}

local function read_all(p) local f=io.open(p,"rb"); if not f then return nil end local d=f:read("*all"); f:close(); return d end
local function write_all(p,d) local f=io.open(p,"wb"); if not f then return false end f:write(d); f:close(); return true end

local function ensure_track_selected()
  local tr=r.GetSelectedTrack(0,0)
  if tr then return tr end
  r.InsertTrackAtIndex(r.CountTracks(0), true)
  tr=r.GetTrack(0, r.CountTracks(0)-1)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", "PSS-x80 SysEx Capture", true)
  r.SetOnlyTrackSelected(tr)
  return tr
end

local function configure_track_basic(tr)
  if not tr then return end
  r.SetMediaTrackInfo_Value(tr, "I_RECARM", 1)
  r.SetMediaTrackInfo_Value(tr, "I_RECMON", 1)
  r.SetMediaTrackInfo_Value(tr, "I_RECMODE", 0)
end

local function last_item(tr)
  local c=r.CountTrackMediaItems(tr)
  if c==0 then return nil end
  return r.GetTrackMediaItem(tr, c-1)
end

local function send_file(path)
  local blob = read_all(path)
  if not blob then status="Cannot read: "..path; return end
  r.SNM_SendSysEx(blob)
  status="Sent: "..path
end

local function extract_from_last_take()
  if not cap.track then return "",0,nil end
  local item = last_item(cap.track)
  if not item then return "",0,nil end
  local take = r.GetActiveTake(item)
  if not take or not r.TakeIsMIDI(take) then return "",0,nil end
  local blob, count = MidiSyx.extract_sysex_from_take(take)
  return blob, count, take
end

local function finalize_capture(blob, count)
  if not blob or #blob==0 then
    status="No SysEx found. Check: mioXM SysEx filter OFF, REAPER MIDI input enabled, correct track input."
    return
  end
  local ts=os.date("!%Y%m%d_%H%M%S")
  local out = root.."/Docs/Reports/PSS_Backup_"..ts..".syx"
  if write_all(out, blob) then
    backup_path = out
    r.SetExtState("IFLS_PSS580","SAFE_BACKUP_PATH", backup_path, false)
    status = ("Backup captured (%d msg%s): %s"):format(count, count==1 and "" or "s", out)
  else
    status = "Failed writing backup."
  end
end

local function start_capture()
  local tr=ensure_track_selected()
  configure_track_basic(tr)
  cap.track=tr
  cap.active=true
  cap.start_time=r.time_precise()
  cap.found_count=0
  status="Recording… NOW trigger PSS transmit/dump. Auto-stops when SysEx received."
  r.Main_OnCommand(1013, 0) -- Transport: Record
end

local function stop_and_finalize()
  cap.active=false
  r.Main_OnCommand(1016, 0) -- Stop
  local blob, count = extract_from_last_take()
  finalize_capture(blob, count)
end

local function update_capture()
  if not cap.active then return end
  local dt = r.time_precise() - cap.start_time

  local blob, count = extract_from_last_take()
  cap.found_count = count or 0

  if count and count > 0 and blob and #blob > 0 then
    status=("SysEx received (%d msg) → stopping & saving backup…"):format(count)
    stop_and_finalize()
    return
  end

  if dt >= timeout_secs then
    status="Timeout reached → stopping & attempting extraction…"
    stop_and_finalize()
    return
  end

  status=("Recording… %.1fs / %ds (waiting for SysEx F0..F7)"):format(dt, timeout_secs)
end

local function pick_audition()
  local ok, p = r.GetUserFileNameForRead("", "Select audition .syx (voice or bank)", ".syx")
  if ok and p and p~="" then audition_path=p; status="Audition set." end
end

local function loop()
  update_capture()

  r.ImGui_SetNextWindowSize(ctx, 860, 520, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS PSS-x80 Safe Audition Wizard (Auto-capture)", true)
  if visible then
    r.ImGui_Text(ctx, "Backup path:")
    r.ImGui_TextWrapped(ctx, backup_path ~= "" and backup_path or "(none)")
    r.ImGui_TextWrapped(ctx, hint)
    r.ImGui_Separator(ctx)

    local ch, v = r.ImGui_SliderInt(ctx, "Timeout seconds", timeout_secs, 4, 60)
    if ch then timeout_secs=v end

    if cap.active then r.ImGui_BeginDisabled(ctx) end
    if r.ImGui_Button(ctx, "Capture Backup Now (auto-stop)", 260, 0) then
      start_capture()
    end
    if cap.active then r.ImGui_EndDisabled(ctx) end

    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Send Backup (Revert)", 220, 0) then
      if backup_path=="" then status="No backup yet." else send_file(backup_path) end
    end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Audition .syx:")
    r.ImGui_TextWrapped(ctx, audition_path ~= "" and audition_path or "(none)")

    if r.ImGui_Button(ctx, "Choose Audition File", 220, 0) then pick_audition() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Send Audition", 220, 0) then
      if audition_path=="" then status="No audition file selected." else send_file(audition_path) end
    end

    r.ImGui_Separator(ctx)
    if status~="" then
      r.ImGui_Text(ctx, "Status:")
      r.ImGui_TextWrapped(ctx, status)
    end
    r.ImGui_End(ctx)
  end
  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
