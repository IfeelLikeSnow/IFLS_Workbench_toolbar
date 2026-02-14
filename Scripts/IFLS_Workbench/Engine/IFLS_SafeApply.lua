-- @description IFLS Workbench - Engine/IFLS_SafeApply.lua
-- @version 0.63.0
-- @author IfeelLikeSnow


-- IFLS_Workbench/Engine/IFLS_SafeApply.lua
-- V53: Safe apply wrapper for destructive operations (routing, recall, project modifications).
--
-- Features:
-- - Undo block
-- - Optional UI refresh suppression
-- - Centralized error handling (pcall)
-- - Optional rollback callback

local r = reaper
local M = {}

local function default_opts(opts)
  opts = opts or {}
  if opts.no_ui == nil then opts.no_ui = true end
  return opts
end

function M.run(action_name, fn, opts)
  opts = default_opts(opts)
  local proj = 0

  r.Undo_BeginBlock2(proj)
  if opts.no_ui then r.PreventUIRefresh(1) end

  local ok, err = pcall(fn)

  if opts.no_ui then r.PreventUIRefresh(-1) end
  r.UpdateArrange()

  if ok then
    r.Undo_EndBlock2(proj, action_name or "IFLS Safe Apply", -1)
    return true
  end

  if opts.rollback and type(opts.rollback) == "function" then
    pcall(opts.rollback, err)
  end

  r.Undo_EndBlock2(proj, (action_name or "IFLS Safe Apply") .. " (FAILED)", -1)
  r.MB("Operation failed:\n\n"..tostring(err), "IFLS Safe Apply", 0)
  return false, err
end

return M
