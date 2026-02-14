-- @description IFLS Workbench - Tools/IFLS_Workbench_HW_Conflict_View.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench - HW Conflict View (Recall + Patchbay)
-- @version 0.1.0
-- @author IFLS
-- @about
--   Shows current per-project recall (ProjExtState) and detects OUTPUT channel conflicts.
--   Requires ReaImGui.

local r = reaper

if not r.ImGui_CreateContext then
  r.MB("ReaImGui extension not found.\nInstall via ReaPack → ReaTeam Extensions → ReaImGui.", "IFLS Workbench", 0)
  return
end

package.path = package.path .. ";" .. r.GetResourcePath() .. "/Scripts/?.lua"
local Engine = require("IFLS_Workbench/Engine/IFLS_Patchbay_RoutingEngine")

local ctx = r.ImGui_CreateContext("IFLS Workbench - HW Conflicts")

local recall = Engine.load_recall()
local function reload() recall = Engine.load_recall() end

local function copy_text(text)
  if r.ImGui_SetClipboardText then
    r.ImGui_SetClipboardText(ctx, text)
  else
    r.ShowConsoleMsg(text .. "\n")
  end
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 720, 520, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "HW Conflict View (per-project recall)", true)

  if visible then
    if r.ImGui_Button(ctx, "Reload") then reload() end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Copy recall JSON") then
      -- easiest: copy the value stored in project extstate directly via EnumProjExtState
      local proj = r.EnumProjects(-1, "")
      local ok, val = r.GetProjExtState(proj, "IFLS_WORKBENCH", "HW_ROUTING")
      if ok == 1 and val and val ~= "" then copy_text(val) end
    end

    local conflicts = Engine.detect_output_conflicts(recall)

    r.ImGui_Separator(ctx)
    if #conflicts == 0 then
      r.ImGui_TextColored(ctx, 0.2, 1.0, 0.2, 1.0, "No OUTPUT conflicts detected.")
    else
      r.ImGui_TextColored(ctx, 1.0, 0.6, 0.2, 1.0, "OUTPUT conflicts detected:")
      if r.ImGui_BeginTable(ctx, "conflicts", 2, r.ImGui_TableFlags_Borders()|r.ImGui_TableFlags_RowBg()) then
        r.ImGui_TableSetupColumn(ctx, "HW OUT ch", r.ImGui_TableColumnFlags_WidthFixed(), 100)
        r.ImGui_TableSetupColumn(ctx, "Devices", r.ImGui_TableColumnFlags_WidthStretch())
        r.ImGui_TableHeadersRow(ctx)

        for _, c in ipairs(conflicts) do
          r.ImGui_TableNextRow(ctx)
          r.ImGui_TableSetColumnIndex(ctx, 0)
          r.ImGui_Text(ctx, tostring(c.ch))
          r.ImGui_TableSetColumnIndex(ctx, 1)
          r.ImGui_Text(ctx, table.concat(c.devices, ", "))
        end

        r.ImGui_EndTable(ctx)
      end
    end

    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Recall entries:")
    local devices = Engine.get_recall_devices(recall)

    if r.ImGui_BeginChild(ctx, "recall_list", 0, 0, true) then
      for _, dev in ipairs(devices) do
        local cfg = recall[dev]
        local mode = (cfg and cfg.mode) or "?"
        local out_txt = (mode=="stereo") and (tostring(cfg.outL).."/"..tostring(cfg.outR)) or tostring(cfg.out)
        local in_txt  = (mode=="stereo") and (tostring(cfg.inL ).."/"..tostring(cfg.inR )) or tostring(cfg.in_)
        local line = string.format("%s  |  %s  |  OUT %s  |  IN %s", dev, mode, out_txt, in_txt)

        if r.ImGui_Selectable(ctx, line, false) and r.ImGui_IsMouseDoubleClicked(ctx, 0) then
          copy_text(line)
        end
      end
      r.ImGui_EndChild(ctx)
    end

    r.ImGui_End(ctx)
  end

  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
