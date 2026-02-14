-- @description IFLS Workbench - Tools/IFLS_Workbench_HW_Recall_Apply.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench - HW Recall Apply (to selected tracks)
-- @version 0.1.0
-- @author IFLS
-- @about
--   Applies stored per-project recall (ProjExtState) to currently selected tracks:
--   - adds hardware output send based on recalled OUT channels
--   - optionally adds ReaInsert FX
--   Requires ReaImGui.

local r = reaper

if not r.ImGui_CreateContext then
  r.MB("ReaImGui extension not found.\nInstall via ReaPack → ReaTeam Extensions → ReaImGui.", "IFLS Workbench", 0)
  return
end

package.path = package.path .. ";" .. r.GetResourcePath() .. "/Scripts/?.lua"
local Engine = require("IFLS_Workbench/Engine/IFLS_Patchbay_RoutingEngine")
local SafeApply = require("IFLS_Workbench/Engine/IFLS_SafeApply")

local ctx = r.ImGui_CreateContext("IFLS Workbench - HW Recall Apply")

local recall = Engine.load_recall()
local selected_device = nil
local method = "tracks_send_only" -- tracks_send_only / reainsert / both
local open_reainsert_ui = false
local create_return = false

local function get_selected_tracks()
  local t = {}
  local n = r.CountSelectedTracks(0)
  for i = 0, n-1 do
    t[#t+1] = r.GetSelectedTrack(0, i)
  end
  return t
end

local function create_return_track(device_name, cfg)
  local mode = cfg.mode or "stereo"
  local inL = cfg.inL or cfg.in_
  if not inL then return false, "missing input channel" end

  local idx = r.CountTracks(0)
  r.InsertTrackAtIndex(idx, true)
  local tr = r.GetTrack(0, idx)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", device_name .. " (Return)", true)
  Engine.set_track_hw_input(tr, inL)
  return true
end

local function apply_to_selected()
  local tracks = get_selected_tracks()
  if #tracks == 0 then return false, "no selected tracks" end
  if not selected_device then return false, "no device selected" end
  local cfg = recall[selected_device]
  if not cfg then return false, "no recall for device" end

  return SafeApply.run("IFLS: HW Recall Apply", function()
  for _, tr in ipairs(tracks) do
    local ok, err = Engine.apply_recall_to_track(tr, selected_device, cfg, method, open_reainsert_ui)
    if not ok then error(err or "apply_recall_to_track failed") end
  end

  if create_return then
    local ok, err = create_return_track(selected_device, cfg)
    if not ok then error(err or "create_return_track failed") end
  end

  r.TrackList_AdjustWindows(false)
  r.UpdateArrange()
end)
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 720, 440, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "HW Recall Apply (selected tracks)", true)

  if visible then
    if r.ImGui_Button(ctx, "Reload recall") then
      recall = Engine.load_recall()
    end
    r.ImGui_SameLine(ctx)
    r.ImGui_Text(ctx, ("Selected tracks: %d"):format(r.CountSelectedTracks(0)))

    local devices = Engine.get_recall_devices(recall)
    if not selected_device and #devices > 0 then selected_device = devices[1] end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Device (from recall):")
    if r.ImGui_BeginCombo(ctx, "##device", selected_device or "(none)") then
      for _, dev in ipairs(devices) do
        if r.ImGui_Selectable(ctx, dev, dev == selected_device) then
          selected_device = dev
        end
      end
      r.ImGui_EndCombo(ctx)
    end

    r.ImGui_Text(ctx, "Method:")
    if r.ImGui_BeginCombo(ctx, "##method", method) then
      if r.ImGui_Selectable(ctx, "tracks_send_only", method=="tracks_send_only") then method="tracks_send_only" end
      if r.ImGui_Selectable(ctx, "reainsert", method=="reainsert") then method="reainsert" end
      if r.ImGui_Selectable(ctx, "both", method=="both") then method="both" end
      r.ImGui_EndCombo(ctx)
    end
    local _, ou = r.ImGui_Checkbox(ctx, "Open ReaInsert UI on add", open_reainsert_ui)
    open_reainsert_ui = ou

    local _, cr = r.ImGui_Checkbox(ctx, "Create a Return track (record input) once", create_return)
    create_return = cr

    r.ImGui_Separator(ctx)

    if r.ImGui_Button(ctx, "Apply to selected tracks") then
      local ok, err = apply_to_selected()
      if not ok then r.MB("Apply failed: " .. tostring(err), "IFLS Workbench", 0) end
    end

    if selected_device and recall[selected_device] then
      local cfg = recall[selected_device]
      local mode = cfg.mode or "?"
      local out_txt = (mode=="stereo") and (tostring(cfg.outL).."/"..tostring(cfg.outR)) or tostring(cfg.out)
      local in_txt  = (mode=="stereo") and (tostring(cfg.inL ).."/"..tostring(cfg.inR )) or tostring(cfg.in_)
      r.ImGui_Text(ctx, ("Recall: %s | OUT %s | IN %s"):format(mode, out_txt, in_txt))
    end

    r.ImGui_End(ctx)
  end

  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
