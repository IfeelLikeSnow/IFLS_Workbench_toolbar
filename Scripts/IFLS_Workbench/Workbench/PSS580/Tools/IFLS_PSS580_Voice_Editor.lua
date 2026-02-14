-- @description IFLS PSS-580 - Voice Editor (ReaImGui) + Parameter Mapping + Operator UI + Safe Random
-- @version 1.03.0
-- @author IFLS
-- @about
--   Uses VCED<->VMEM mapping (derived from PSS-Revive reference) to provide a real parameter UI.
--   Randomize works in VCED domain and preserves unknown/reserved bits for safety.

local r=reaper
if not r.ImGui_CreateContext then r.MB("ReaImGui required.", "PSS Voice Editor", 0); return end

local root = r.GetResourcePath().."/Scripts/IFLS_Workbench"
local Syx = dofile(root.."/Workbench/PSS580/Core/ifls_pss580_sysex.lua")

local ctx = r.ImGui_CreateContext("IFLS PSS-x80 Voice Editor")
math.randomseed(os.time())

local current_path=""
local vmem={}
for i=1,33 do vmem[i]=0 end
local vced = Syx.vmem_to_vced(vmem)
local locks={}   -- locks by param name
local intensity=0.55
local scope="full"
local template="(none)"
local templates={"(none)","Organ","BassDrum","Snare","HiHat","Drone","Pluck","Pad"}

local live_send=false
local throttle_ms=150
local pending_send=false
local last_change_time=0.0
local loaded_vced=nil

local function read_all(p) local f=io.open(p,"rb"); if not f then return nil end local d=f:read("*all"); f:close(); return d end
local function write_all(p, d) local f=io.open(p,"wb"); if not f then return false end f:write(d); f:close(); return true end

local function sync_vced_from_vmem()
  vced = Syx.vmem_to_vced(vmem)
end
local function sync_vmem_from_vced()
  vmem = Syx.vced_to_vmem(vced)
end

local function load_syx(path)
  local blob=read_all(path); if not blob then return false end
  local msgs=Syx.split_sysex(blob)
  for _,m in ipairs(msgs) do
    if Syx.is_pss_voice_dump(m) then
      local vv = Syx.unpack_vmem_from_voice_dump(m)
      vmem = vv
      sync_vced_from_vmem()
      current_path = path
      loaded_vced = {}
      for k,v in pairs(vced) do loaded_vced[k]=v end
      return true
    end
  end
  return false
end

local function export_syx(path)
  sync_vmem_from_vced()
  local msg = Syx.pack_voice_dump_from_vmem(vmem)
  return write_all(path, msg)
end

local function send_current()
  if not r.SNM_SendSysEx then r.MB("SWS required (SNM_SendSysEx).", "PSS Voice Editor", 0); return end
  sync_vmem_from_vced()
  local msg = Syx.pack_voice_dump_from_vmem(vmem)
  r.SNM_SendSysEx(msg)
end

local function set_defaults_safe_unknown_bits()
  -- Ensure unknown bits are kept at 0 for new sounds unless loaded from file.
  vced.D_3_7=0; vced.D_4_7=0
  vced.D_15_76=0; vced.D_15_210=0
  vced.D_16_7=0; vced.D_16_32=0
  vced.D_20_Hi=0; vced.D_21_Hi=0
  vced.D_22_7=0; vced.D_24_54=0; vced.D_24_Lo=0
  -- reserved bytes nibbles to 0
  local zeros={"D_17_Hi","D_17_Lo","D_18_Hi","D_18_Lo","D_19_Hi","D_19_Lo","D_23_Hi","D_23_Lo",
               "D_25_Hi","D_25_Lo","D_26_Hi","D_26_Lo","D_27_Hi","D_27_Lo","D_28_Hi","D_28_Lo",
               "D_29_Hi","D_29_Lo","D_30_Hi","D_30_Lo","D_31_Hi","D_31_Lo","D_32_Hi","D_32_Lo"}
  for _,k in ipairs(zeros) do vced[k]=0 end
end

local function apply_template(name)
  set_defaults_safe_unknown_bits()
  -- conservative templates in VCED domain (2-op FM)
  if name=="Organ" then
    vced.M_MUL=1; vced.C_MUL=1
    vced.M_TL=40; vced.C_TL=10
    vced.M_AR=50; vced.C_AR=55
    vced.M_D1R=10; vced.C_D1R=8
    vced.M_D2R=6;  vced.C_D2R=6
    vced.M_D1L=10; vced.C_D1L=12
    vced.M_RR=6;   vced.C_RR=6
    vced.M_SIN_TBL=0; vced.C_SIN_TBL=0
    vced.M_FB=2
  elseif name=="BassDrum" then
    vced.C_MUL=1; vced.M_MUL=2
    vced.C_TL=8;  vced.M_TL=60
    vced.C_AR=60; vced.M_AR=55
    vced.C_D1R=40; vced.M_D1R=35
    vced.C_D2R=30; vced.M_D2R=25
    vced.C_D1L=0;  vced.M_D1L=0
    vced.C_RR=10;  vced.M_RR=10
    vced.M_FB=5
  elseif name=="Snare" then
    vced.C_MUL=1; vced.M_MUL=8
    vced.C_TL=20; vced.M_TL=40
    vced.C_AR=55; vced.M_AR=55
    vced.C_D1R=45; vced.M_D1R=55
    vced.C_D2R=40; vced.M_D2R=50
    vced.C_D1L=2;  vced.M_D1L=2
    vced.C_RR=12;  vced.M_RR=12
    vced.M_SIN_TBL=3
    vced.M_FB=6
  elseif name=="HiHat" then
    vced.C_MUL=12; vced.M_MUL=15
    vced.C_TL=30;  vced.M_TL=20
    vced.C_AR=63;  vced.M_AR=63
    vced.C_D1R=60; vced.M_D1R=63
    vced.C_D2R=55; vced.M_D2R=63
    vced.C_D1L=0;  vced.M_D1L=0
    vced.C_RR=15;  vced.M_RR=15
    vced.M_SIN_TBL=3; vced.C_SIN_TBL=3
    vced.M_FB=7
  elseif name=="Drone" then
    vced.C_MUL=1; vced.M_MUL=1
    vced.C_TL=15; vced.M_TL=30
    vced.C_AR=20; vced.M_AR=18
    vced.C_D1R=4;  vced.M_D1R=3
    vced.C_D2R=1;  vced.M_D2R=1
    vced.C_D1L=15; vced.M_D1L=15
    vced.C_RR=2;   vced.M_RR=2
    vced.M_FB=1
    vced.PMS=2; vced.AMS=1
  elseif name=="Pluck" then
    vced.C_MUL=1; vced.M_MUL=3
    vced.C_TL=10; vced.M_TL=55
    vced.C_AR=63; vced.M_AR=55
    vced.C_D1R=50; vced.M_D1R=40
    vced.C_D2R=30; vced.M_D2R=20
    vced.C_D1L=0;  vced.M_D1L=3
    vced.C_RR=10;  vced.M_RR=10
    vced.M_FB=3
  elseif name=="Pad" then
    vced.C_MUL=1; vced.M_MUL=2
    vced.C_TL=25; vced.M_TL=35
    vced.C_AR=15; vced.M_AR=12
    vced.C_D1R=6;  vced.M_D1R=6
    vced.C_D2R=2;  vced.M_D2R=2
    vced.C_D1L=12; vced.M_D1L=12
    vced.C_RR=4;   vced.M_RR=4
    vced.PMS=1; vced.AMS=1
    vced.M_FB=2
  end
end

local function slider_param(name, lo, hi, format)
  local v = tonumber(vced[name] or 0)
  local changed, nv = r.ImGui_SliderInt(ctx, name, v, lo, hi, format or "")
  if changed then vced[name]=nv; pending_send=true; last_change_time=reaper.time_precise() end
  r.ImGui_SameLine(ctx)
  local lc, lk = r.ImGui_Checkbox(ctx, "L##"..name, locks[name] or false)
  if lc then locks[name]=lk end
end

local function section_operator(title, prefix)
  r.ImGui_Separator(ctx)
  r.ImGui_Text(ctx, title)
  slider_param(prefix.."MUL", 0, 15)
  slider_param(prefix.."DT1", 0, 15)
  slider_param(prefix.."DT2", 0, 1)
  slider_param(prefix.."TL",  0, 127)
  slider_param(prefix.."AM_EN", 0, 1)
  slider_param(prefix.."SIN_TBL", 0, 3)
  slider_param(prefix.."RKS", 0, 3)
  slider_param(prefix.."LKS_HI", 0, 15)
  slider_param(prefix.."LKS_LO", 0, 15)
  slider_param(prefix.."AR", 0, 63)
  slider_param(prefix.."D1R", 0, 63)
  slider_param(prefix.."D2R", 0, 63)
  slider_param(prefix.."D1L", 0, 15)
  slider_param(prefix.."RR", 0, 15)
  slider_param(prefix.."SRR", 0, 15)
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 1040, 720, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS PSS-x80 Voice Editor (VCED)", true)
  if visible then
    r.ImGui_Text(ctx, "File: "..(current_path~="" and current_path or "(none)"))
    r.ImGui_Separator(ctx)

    if r.ImGui_Button(ctx, "Load .syx (voice)", 170, 0) then
      local ok, path = r.GetUserFileNameForRead("", "Select PSS-x80 voice .syx", ".syx")
      if ok and path~="" then
        if not load_syx(path) then r.MB("No 72-byte voice dump found.", "PSS Voice Editor", 0) end
      end
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Send to PSS (SysEx)", 170, 0) then send_current() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Export .syx", 170, 0) then
      local ok, path = r.GetUserFileNameForWrite("", "Save PSS-x80 voice .syx", ".syx")
      if ok and path~="" then
        if not export_syx(path) then r.MB("Cannot write file.", "PSS Voice Editor", 0) end
      end
    end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Templates")
    if r.ImGui_BeginCombo(ctx, "Template", template) then
      for _,t in ipairs(templates) do
        if r.ImGui_Selectable(ctx, t, t==template) then template=t end
      end
      r.ImGui_EndCombo(ctx)
    end
    if r.ImGui_Button(ctx, "Apply template", 170, 0) then
      if template~="(none)" then apply_template(template) end
    end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Realtime")
    local chls, lsv = r.ImGui_Checkbox(ctx, "Live Send (throttled)", live_send)
    if chls then live_send=lsv end
    local chtm, tms = r.ImGui_SliderInt(ctx, "Throttle ms", throttle_ms, 50, 500)
    if chtm then throttle_ms = tms end
    if r.ImGui_Button(ctx, "Send now", 170, 0) then send_current() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Show Diff vs Loaded (console)", 220, 0) then
      if loaded_vced then
        reaper.ShowConsoleMsg("=== PSS VCED Diff vs Loaded ===\n")
        for k,v in pairs(vced) do
          local ov = loaded_vced[k]
          if ov ~= nil and v ~= ov then
            reaper.ShowConsoleMsg(string.format("%s: %s -> %s\n", k, tostring(ov), tostring(v)))
          end
        end
      else
        reaper.ShowConsoleMsg("No loaded baseline. Load a .syx first.\n")
      end
    end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Randomize (safe VCED domain)")
    local ch, nv = r.ImGui_SliderDouble(ctx, "Intensity", intensity, 0.0, 1.0)
    if ch then intensity=nv end
    if r.ImGui_BeginCombo(ctx, "Scope", scope) then
      local scopes={"full","global","ops_env","ops_pitch","ops_timbre"}
      for _,s in ipairs(scopes) do
        if r.ImGui_Selectable(ctx, s, s==scope) then scope=s end
      end
      r.ImGui_EndCombo(ctx)
    end
    if r.ImGui_Button(ctx, "Randomize now", 170, 0) then
      vced = Syx.randomize_vced(vced, intensity, locks, scope)
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Clear locks", 170, 0) then
      locks={}
    end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Global")
    slider_param("BANK", 0, 7)
    slider_param("PMS", 0, 7)
    slider_param("AMS", 0, 3)
    slider_param("VDT", 0, 127)
    slider_param("V", 0, 1)
    slider_param("S", 0, 1)
    slider_param("M_FB", 0, 7) -- feedback lives in mod area in VCED

    r.ImGui_BeginChild(ctx, "ops", -1, -1, true)
    section_operator("Modulator (M_*)", "M_")
    section_operator("Carrier (C_*)", "C_")
    r.ImGui_EndChild(ctx)

    r.ImGui_End(ctx)
  end
  -- live send throttle
  if open and live_send and pending_send then
    local dt = (reaper.time_precise() - last_change_time) * 1000.0
    if dt >= throttle_ms then
      pending_send=false
      send_current()
    end
  end
  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
