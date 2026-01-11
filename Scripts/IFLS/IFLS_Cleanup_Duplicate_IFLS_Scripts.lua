-- @description IFLS: Cleanup duplicate IFLS scripts (safe helper)
-- @version 1.0.0
-- @author I feel like snow
-- @about
--   Finds duplicate IFLS*.lua scripts inside your REAPER/Scripts folder.
--   Optionally moves duplicates into a timestamped backup folder (no permanent delete).
--   Intended to fix "Can't load file" issues after multiple ZIP/manual installs.

local r = reaper

local function join(a,b)
  if a:sub(-1) == "\" then return a..b end
  return a .. "\" .. b
end

local scripts_root = join(r.GetResourcePath(), "Scripts")

local function list_files_recursive(dir, out)
  out = out or {}
  local i = 0
  while true do
    local fn = r.EnumerateFiles(dir, i)
    if not fn then break end
    if fn:lower():match("^ifls.*%.lua$") then
      out[#out+1] = join(dir, fn)
    end
    i = i + 1
  end
  local j = 0
  while true do
    local sub = r.EnumerateSubdirectories(dir, j)
    if not sub then break end
    -- skip the backup folders we create
    if not sub:match("^_IFLS_BACKUP_") then
      list_files_recursive(join(dir, sub), out)
    end
    j = j + 1
  end
  return out
end

local files = list_files_recursive(scripts_root, {})
local by_base = {}
for _,p in ipairs(files) do
  local base = p:match("([^\\/]+)$"):lower()
  by_base[base] = by_base[base] or {}
  by_base[base][#by_base[base]+1] = p
end

local dups = {}
for base, list in pairs(by_base) do
  if #list > 1 then
    table.sort(list)
    dups[#dups+1] = {base=base, list=list}
  end
end

table.sort(dups, function(a,b) return a.base < b.base end)

if #dups == 0 then
  r.MB("No duplicate IFLS*.lua files found in:\n" .. scripts_root, "IFLS Cleanup", 0)
  return
end

local msg = {}
msg[#msg+1] = "Found duplicate IFLS scripts:"
for _,d in ipairs(dups) do
  msg[#msg+1] = ""
  msg[#msg+1] = d.base .. " (" .. #d.list .. " copies)"
  for _,p in ipairs(d.list) do
    msg[#msg+1] = "  " .. p
  end
end

msg[#msg+1] = ""
msg[#msg+1] = "Move ALL but the first copy of each duplicate into a backup folder?"
msg[#msg+1] = "(No permanent delete. You can restore later.)"

local ret = r.MB(table.concat(msg, "\n"), "IFLS Cleanup", 4) -- Yes/No
if ret ~= 6 then return end

local ts = os.date("!%Y%m%d_%H%M%S")
local backup = join(scripts_root, "_IFLS_BACKUP_" .. ts)
r.RecursiveCreateDirectory(backup, 0)

local moved = 0
for _,d in ipairs(dups) do
  -- keep first file, move the rest
  for k=2, #d.list do
    local src = d.list[k]
    local dst = join(backup, src:match("([^\\/]+)$"))
    -- ensure unique dst name
    local n = 1
    while r.file_exists and r.file_exists(dst) do
      n = n + 1
      dst = join(backup, ("%s__%d.lua"):format(d.base:gsub("%.lua$",""), n))
    end
    os.rename(src, dst)
    moved = moved + 1
  end
end

r.MB(("Moved %d files into:\n%s\n\nRestart REAPER if actions still point to old paths."):format(moved, backup),
     "IFLS Cleanup", 0)
