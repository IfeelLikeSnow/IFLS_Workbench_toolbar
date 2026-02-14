-- @description IFLS Workbench - Tools/IFLS_Workbench_External_Insert_Wizard.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench - External Hardware Insert Wizard (Patchbay Routing Engine)
-- @version 0.1.0
-- @author IFLS
-- @about
--   Uses Data/IFLS_Workbench/patchbay.json to propose and build external hardware routing.
--   Options: (A) build send/return tracks using hardware outputs/inputs, (B) optionally add ReaInsert FX.
--   Includes conflict check + session recall (ProjExtState).
--   [main] .

local r = reaper

-- ReaImGui required
if not r.ImGui_CreateContext then
  r.MB("ReaImGui extension not found.\nInstall via ReaPack → ReaTeam Extensions → ReaImGui.", "IFLS Workbench", 0)
  return
end

-- routing engine module (relative to REAPER Scripts folder)
package.path = package.path .. ";" .. r.GetResourcePath() .. "/Scripts/?.lua"
local Engine = require("IFLS_Workbench/Engine/IFLS_Patchbay_RoutingEngine")
local SafeApply = require("IFLS_Workbench/Engine/IFLS_SafeApply")

local patch_data, patch_err = Engine.load_patchbay()
local recall = Engine.load_recall()

local ctx = r.ImGui_CreateContext("IFLS Workbench - External Insert Wizard")

-- UI state
local device_search = ""
local selected_device = nil
local mode = "stereo" -- stereo/mono
local build_method = "tracks" -- tracks / reainsert / both
local open_reainsert_ui = true
local override_conflicts = false

local suggested = { outL=nil,outR=nil,inL=nil,inR=nil, note="" }
local conflicts = {}

local function recompute()
  suggested = { outL=nil,outR=nil,inL=nil,inR=nil, note="" }
  conflicts = {}
  override_conflicts = false

  if not patch_data or patch_err then return end
  if not selected_device then return end

  local out_map = Engine.get_device_map(patch_data.outputs, selected_device) or {}
  local in_map  = Engine.get_device_map(patch_data.inputs,  selected_device) or {}

  if mode == "stereo" then
    local oL,oR,oWhy = Engine.suggest_stereo_channels(out_map)
    local iL,iR,iWhy = Engine.suggest_stereo_channels(in_map)
    suggested.outL, suggested.outR = oL,oR
    suggested.inL,  suggested.inR  = iL,iR
    suggested.note = ("Suggest: OUT(%s) / IN(%s)"):format(oWhy or "?", iWhy or "?")
    conflicts = Engine.conflicts_with_recall(recall, selected_device, "stereo", oL, oR, nil)
  else
    local o = Engine.suggest_mono_channel(out_map)
    local i = Engine.suggest_mono_channel(in_map)
    suggested.outL = o
    suggested.inL  = i
    suggested.note = "Suggest: mono first patched"
    conflicts = Engine.conflicts_with_recall(recall, selected_device, "mono", nil, nil, o)
  end
end

local function save_device_recall()
  if mode == "stereo" then
    recall[selected_device] = { mode="stereo", outL=suggested.outL, outR=suggested.outR, inL=suggested.inL, inR=suggested.inR }
  else
    recall[selected_device] = { mode="mono", out=suggested.outL, in_=suggested.inL }
  end
  Engine.save_recall(recall)
end

local function create_tracks_and_routing()
  return SafeApply.run("IFLS: External Insert Wizard", function()
local idx = r.CountTracks(0)
  r.InsertTrackAtIndex(idx, true)
  local insert_tr = r.GetTrack(0, idx)
  r.GetSetMediaTrackInfo_String(insert_tr, "P_NAME", selected_device .. " (Insert)", true)
  r.SetMediaTrackInfo_Value(insert_tr, "B_MAINSEND", 0)

  -- ensure enough channels (stereo = 2, mono = 2 is fine too, keep 2)
  Engine.ensure_track_channels(insert_tr, 2)

  local ok, err = Engine.add_hw_out_send(insert_tr, suggested.outL, mode)
  if not ok then
    ", -1)
    return false, err
  end

  r.InsertTrackAtIndex(idx + 1, true)
  local ret_tr = r.GetTrack(0, idx + 1)
  r.GetSetMediaTrackInfo_String(ret_tr, "P_NAME", selected_device .. " (Return)", true)
  Engine.set_track_hw_input(ret_tr, suggested.inL)

  -- notes
  local out_txt = (mode=="stereo") and (tostring(suggested.outL).."/"..tostring(suggested.outR)) or tostring(suggested.outL)
  local in_txt  = (mode=="stereo") and (tostring(suggested.inL ).."/"..tostring(suggested.inR )) or tostring(suggested.inL)
  local notes = ("IFLS External Insert\nDevice: %s\nMode: %s\nHW OUT: %s\nHW IN: %s\n%s")
    :format(selected_device, mode, out_txt, in_txt, suggested.note or "")
  r.GetSetMediaTrackInfo_String(insert_tr, "P_NOTES", notes, true)
  r.GetSetMediaTrackInfo_String(ret_tr, "P_NOTES", notes, true)

  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()

  ", -1)
  return true
end

local function add_reainsert_only()
  local idx = r.CountTracks(0)
  r.InsertTrackAtIndex(idx, true)
  local tr = r.GetTrack(0, idx)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", selected_device .. " (ReaInsert)", true)

  local fx = Engine.add_reainsert_fx(tr, open_reainsert_ui)

  local out_txt = (mode=="stereo") and (tostring(suggested.outL).."/"..tostring(suggested.outR)) or tostring(suggested.outL)
  local in_txt  = (mode=="stereo") and (tostring(suggested.inL ).."/"..tostring(suggested.inR )) or tostring(suggested.inL)

  local notes = ("IFLS External Insert (ReaInsert)\nDevice: %s\nMode: %s\nSuggested HW OUT: %s\nSuggested HW IN: %s\n\nNOTE:\nReaInsert channel dropdowns are not reliably script-set across versions.\nThe FX has been inserted%s.\n")
    :format(selected_device, mode, out_txt, in_txt, (fx>=0) and "" or " (FAILED)")
  r.GetSetMediaTrackInfo_String(tr, "P_NOTES", notes, true)

  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()

  ", -1)
  return (fx>=0), (fx>=0 and nil or "TrackFX_AddByName failed")
end

local function apply()
  if not selected_device then return end
  save_device_recall()

  if build_method == "tracks" then
    return create_tracks_and_routing()
  elseif build_method == "reainsert" then
    return add_reainsert_only()
  else
    local ok1, e1 = create_tracks_and_routing()
    local ok2, e2 = add_reainsert_only()
    if ok1 and ok2 then return true end
    return false, (e1 or "") .. " " .. (e2 or "")
  end
end

local function begin_disabled(disabled)
  if disabled then r.ImGui_BeginDisabled(ctx, true) end
end
local function end_disabled(disabled)
  if disabled then r.ImGui_EndDisabled(ctx) end
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 760, 560, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "External Hardware Insert Wizard", true)

  if visible then
    if patch_err then
      r.ImGui_TextColored(ctx, 1.0, 0.3, 0.3, 1.0, patch_err)
      if r.ImGui_Button(ctx, "Reload patchbay.json") then
        patch_data, patch_err = Engine.load_patchbay()
        recompute()
      end
      r.ImGui_End(ctx)
      if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
      return
    end

    local devices = Engine.list_devices_common(patch_data)

    local _, ds = r.ImGui_InputText(ctx, "Device search", device_search)
    device_search = ds

    local list = Engine.filter_list(devices, device_search)

    if r.ImGui_BeginListBox(ctx, "##devices", -1, 190) then
      for _, name in ipairs(list) do
        local sel = (selected_device == name)
        if r.ImGui_Selectable(ctx, name, sel) then
          selected_device = name
          recompute()
        end
      end
      r.ImGui_EndListBox(ctx)
    end

    r.ImGui_Separator(ctx)

    -- Mode
    r.ImGui_Text(ctx, "Mode:")
    r.ImGui_SameLine(ctx)
    local stereo = (mode == "stereo")
    if r.ImGui_RadioButton(ctx, "Stereo", stereo) then mode = "stereo"; recompute() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_RadioButton(ctx, "Mono", not stereo) then mode = "mono"; recompute() end

    r.ImGui_Separator(ctx)

    -- Build method (both optional)
    r.ImGui_Text(ctx, "Build:")
    r.ImGui_SameLine(ctx)
    if r.ImGui_BeginCombo(ctx, "##build", build_method) then
      if r.ImGui_Selectable(ctx, "tracks", build_method=="tracks") then build_method="tracks" end
      if r.ImGui_Selectable(ctx, "reainsert", build_method=="reainsert") then build_method="reainsert" end
      if r.ImGui_Selectable(ctx, "both", build_method=="both") then build_method="both" end
      r.ImGui_EndCombo(ctx)
    end
    r.ImGui_SameLine(ctx)
    local _, ou = r.ImGui_Checkbox(ctx, "Open ReaInsert UI", open_reainsert_ui)
    open_reainsert_ui = ou
    if r.ImGui_IsItemHovered(ctx) then
      r.ImGui_BeginTooltip(ctx)
      r.ImGui_Text(ctx, "Only applies when Build includes ReaInsert.")
      r.ImGui_EndTooltip(ctx)
    end

    r.ImGui_Separator(ctx)

    if selected_device then
      r.ImGui_Text(ctx, "Suggested:")
      r.ImGui_Text(ctx, suggested.note or "")

      if mode == "stereo" then
        r.ImGui_Text(ctx, ("HW OUT: %s/%s    HW IN: %s/%s"):format(
          tostring(suggested.outL), tostring(suggested.outR),
          tostring(suggested.inL), tostring(suggested.inR)
        ))
      else
        r.ImGui_Text(ctx, ("HW OUT: %s    HW IN: %s"):format(
          tostring(suggested.outL), tostring(suggested.inL)
        ))
      end

      if #conflicts > 0 then
        r.ImGui_Separator(ctx)
        r.ImGui_TextColored(ctx, 1.0, 0.7, 0.2, 1.0, "Conflict(s) on OUTPUT channel(s):")
        for _, h in ipairs(conflicts) do
          r.ImGui_Text(ctx, ("ch %d already used by: %s"):format(h.ch, h.dev))
        end
        local _, ov = r.ImGui_Checkbox(ctx, "Override conflicts", override_conflicts)
        override_conflicts = ov
      end

      local can_apply = true
      if mode == "stereo" then
        if not (suggested.outL and suggested.outR and suggested.inL and suggested.inR) then can_apply = false end
      else
        if not (suggested.outL and suggested.inL) then can_apply = false end
      end
      if #conflicts > 0 and not override_conflicts then can_apply = false end

      r.ImGui_Separator(ctx)

      begin_disabled(not can_apply)
      if r.ImGui_Button(ctx, "Apply") then
        local ok, err = apply()
        if not ok then r.MB("Apply failed: " .. tostring(err), "IFLS Workbench", 0) end
      end
      end_disabled(not can_apply)

      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "Forget device (clear recall)") then
        recall[selected_device] = nil
        Engine.save_recall(recall)
        recompute()
      end

      if not can_apply then
        r.ImGui_Text(ctx, "Fix missing routing or conflicts to enable Apply.")
      end
    else
      r.ImGui_Text(ctx, "(Select a device)")
    end

    r.ImGui_End(ctx)
  end

  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
