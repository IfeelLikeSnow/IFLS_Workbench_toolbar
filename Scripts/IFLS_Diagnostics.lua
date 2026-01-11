-- @description IFLS Diagnostics (wrapper)
-- @version 1.0.0
-- @author I feel like snow
-- @about Wrapper for backward-compatible action paths.

local r = reaper
local this = debug.getinfo(1,'S').source:match("@(.*)$")
local dir = this:match("^(.*)[\\/][^\\/]+$")
local target = dir .. "\\IFLS\\IFLS_Diagnostics.lua"
local ok, err = pcall(dofile, target)
if not ok then r.MB("Failed to load diagnostics:\n" .. tostring(err), "IFLS", 0) end
