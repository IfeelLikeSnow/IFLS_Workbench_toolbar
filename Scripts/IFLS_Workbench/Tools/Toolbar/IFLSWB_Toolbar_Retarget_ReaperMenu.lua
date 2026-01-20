-- @description IFLS WB: Retarget toolbar .ReaperMenu to another toolbar slot (TB1..TB16)
-- @version 1.0.0
-- @author IFLS Workbench
-- @about
--   This script duplicates an exported toolbar .ReaperMenu file and changes its section header
--   to another REAPER toolbar slot (e.g. "[Floating toolbar 16]" -> "[Floating toolbar 1]").
--
--   Use case:
--     You try to import a .ReaperMenu into "Floating toolbar 1" and REAPER shows:
--       "ReaperMenu file does not have menu/toolbar compatible with 'Floating toolbar 1'"
--
--   Fix:
--     The .ReaperMenu you selected was exported for another toolbar slot (often TB16).
--     Run this script, retarget to the toolbar you want, then import the newly created file.
--
--   Notes:
--     * This does NOT modify your existing toolbar. It only creates a new .ReaperMenu file.
--     * Icons are referenced by filename only. Make sure your PNGs exist in:
--         <REAPER resource path>/Data/toolbar_icons/
--
-- @changelog
--   + Initial release

local function msg(s) reaper.ShowConsoleMsg(tostring(s) .. "\n") end

local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close() return true end
  return false
end

local function read_all(p)
  local f, err = io.open(p, "rb")
  if not f then return nil, err end
  local data = f:read("*all")
  f:close()
  return data
end

local function write_all(p, data)
  local f, err = io.open(p, "wb")
  if not f then return nil, err end
  f:write(data)
  f:close()
  return true
end

local function dirname(p)
  return p:match("^(.*)[/\\][^/\\]+$") or ""
end

local function basename_noext(p)
  local name = p:match("[^/\\]+$") or p
  return (name:gsub("%.[Rr][Ee][Aa][Pp][Ee][Rr][Mm][Ee][Nn][Uu]$", ""))
end

local function normalize_newlines(s)
  -- keep original newlines if possible, but we'll work line-wise.
  s = s:gsub("\r\n", "\n")
  s = s:gsub("\r", "\n")
  return s
end

local function retarget_header(text, targetN)
  -- Find first INI section that looks like a toolbar context and replace it.
  -- Typical examples:
  --   [Floating toolbar 16]
  --   [Floating toolbar 16 (Toolbar 16)]
  --   [Main toolbar]
  --   [Media Explorer toolbar]
  --
  -- We only rewrite the first section header that contains "toolbar" (case-insensitive).
  local lines = {}
  text = normalize_newlines(text)
  for line in (text .. "\n"):gmatch("([^\n]*)\n") do
    lines[#lines+1] = line
  end

  local replaced = false
  for i = 1, #lines do
    local l = lines[i]
    if not replaced and l:match("^%b[]%s*$") then
      local inside = l:match("^%[(.*)%]%s*$") or ""
      if inside:lower():find("toolbar", 1, true) then
        -- Keep "Floating toolbar" wording to match REAPER's import context selector.
        -- We force it to "Floating toolbar N" because that's what the user is trying to import into.
        lines[i] = string.format("[Floating toolbar %d]", targetN)
        replaced = true
      end
    end
  end

  if not replaced then
    return nil, "Could not find a toolbar section header like [Floating toolbar X] in the selected file."
  end

  return table.concat(lines, "\r\n")
end

reaper.ClearConsole()

-- 1) Pick source file
local ok, src = reaper.GetUserFileNameForRead("", "Select source toolbar .ReaperMenu", ".ReaperMenu")
if not ok or not src or src == "" then return end
if not file_exists(src) then
  reaper.MB("Source file not found:\n\n" .. tostring(src), "IFLSWB - Retarget ReaperMenu", 0)
  return
end

-- 2) Pick target toolbar number
local ok2, csv = reaper.GetUserInputs("Retarget toolbar", 1, "Target toolbar number (1-16):", "1")
if not ok2 then return end
local target = tonumber((csv or ""):match("%d+"))
if not target then
  reaper.MB("Please enter a number from 1 to 16.", "IFLSWB - Retarget ReaperMenu", 0)
  return
end
if target < 1 then target = 1 end
if target > 16 then target = 16 end

-- 3) Read + retarget
local data, err = read_all(src)
if not data then
  reaper.MB("Failed reading file:\n\n" .. tostring(err), "IFLSWB - Retarget ReaperMenu", 0)
  return
end

local out, err2 = retarget_header(data, target)
if not out then
  reaper.MB(err2, "IFLSWB - Retarget ReaperMenu", 0)
  return
end

-- 4) Write output file (same folder)
local dir = dirname(src)
if dir == "" then
  dir = reaper.GetResourcePath() .. reaper.GetOS():match("Win") and "\\" or "/"
end

local base = basename_noext(src)
local dst = dir .. "\\" .. base .. string.format("_TB%d.ReaperMenu", target)
-- Avoid overwriting, just in case
if file_exists(dst) then
  dst = dir .. "\\" .. base .. string.format("_TB%d_%d.ReaperMenu", target, math.floor(reaper.time_precise()*1000))
end

local ok3, err3 = write_all(dst, out)
if not ok3 then
  reaper.MB("Failed writing file:\n\n" .. tostring(err3), "IFLSWB - Retarget ReaperMenu", 0)
  return
end

msg("Created: " .. dst)
reaper.MB(
  "Created:\n\n" .. dst ..
  "\n\nNext steps:\n" ..
  "1) Options → Customize toolbars/menus…\n" ..
  string.format("2) Select: Floating toolbar %d\n", target) ..
  "3) Import… and choose the new file\n" ..
  "4) Save, Close\n",
  "IFLSWB - Retarget ReaperMenu",
  0
)
