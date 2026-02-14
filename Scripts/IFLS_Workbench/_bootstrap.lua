-- @description IFLS Workbench - _bootstrap.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_Workbench/_bootstrap.lua
-- V53: Central bootstrap for IFLS Workbench scripts.
--
-- Responsibilities:
-- - normalize package.path so require() works from REAPER Scripts folder
-- - dependency detection (SWS, ReaImGui, JS_ReaScriptAPI)
-- - common helpers: log, mb, extstate keys, data path resolution

local r = reaper
local M = {}

M.resource_path = r.GetResourcePath()
M.scripts_root = M.resource_path .. "/Scripts"

-- Extend package.path so require("IFLS_Workbench/...") works when installed under Scripts/
do
  local p = package.path or ""
  local add = M.scripts_root .. "/?.lua;" .. M.scripts_root .. "/?/init.lua;" .. M.scripts_root .. "/?/?.lua;"
  if not p:find(M.scripts_root, 1, true) then
    package.path = add .. p
  end
end

function M.has_sws()
  return r.SNM_SendSysEx ~= nil
end

function M.has_imgui()
  return r.ImGui_CreateContext ~= nil
end

function M.has_js()
  return r.JS_Dialog_BrowseForOpenFiles ~= nil
end

function M.mb(text, title)
  r.MB(tostring(text), title or "IFLS Workbench", 0)
end

function M.log(text)
  r.ShowConsoleMsg(tostring(text) .. "\n")
end

-- Default ExtState sections
M.ext = {
  fb01_voice_macro = "IFLS_FB01_VOICE_MACRO_V5",
  fb01_dump = "IFLS_FB01_DUMP_V8",
  workbench_settings = "IFLS_WORKBENCH_SETTINGS",
}

-- Data path resolver (supports overrides via ExtState)
-- Convention: JSONs live under Scripts/IFLS_Workbench/Data/
function M.get_data_root()
  local override = r.GetExtState(M.ext.workbench_settings, "data_root")
  if override and override ~= "" then return override end
  return M.scripts_root .. "/IFLS_Workbench/Data"
end

function M.path_join(a,b)
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then return a .. b end
  return a .. "/" .. b
end

function M.data_path(rel)
  return M.path_join(M.get_data_root(), rel)
end

function M.file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

-- Require helper: shows a friendly error if module missing.
function M.safe_require(mod)
  local ok, res = pcall(require, mod)
  if ok then return res end
  M.mb("Missing module: "..tostring(mod).."\n\nError:\n"..tostring(res), "IFLS Workbench", 0)
  return nil
end

return M
