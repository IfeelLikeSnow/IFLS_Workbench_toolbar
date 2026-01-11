-- @description IFLS: Cleanup (detect duplicate IFLS scripts; no deletion)
-- @version 1.0
-- @author I feel like snow
-- @about
--   Scans REAPER's Scripts folder for duplicate IFLS scripts (same filename in multiple places).
--   SAFE: It does NOT delete anything. It prints a report and opens the Scripts folder.
--
local r = reaper
local sep = package.config:sub(1,1)
local scripts_dir = r.GetResourcePath() .. sep .. "Scripts"

local function p(msg) r.ShowConsoleMsg(tostring(msg) .. "\n") end

local function collect(dir, out)
  out = out or {}
  local i = 0
  while true do
    local fn = r.EnumerateFiles(dir, i)
    if not fn then break end
    if fn:lower():match("%.lua$") then
      out[#out+1] = dir .. sep .. fn
    end
    i = i + 1
  end
  i = 0
  while true do
    local sub = r.EnumerateSubdirectories(dir, i)
    if not sub then break end
    if sub ~= "." and sub ~= ".." then
      collect(dir .. sep .. sub, out)
    end
    i = i + 1
  end
  return out
end

local files = collect(scripts_dir, {})
local by_name = {}
for _, full in ipairs(files) do
  local name = full:match("([^"..sep.."]+)$")
  -- focus on IFLS-ish names
  if name:match("^IFLS") or full:find(sep.."IFLS"..sep) then
    by_name[name] = by_name[name] or {}
    table.insert(by_name[name], full)
  end
end

p("=== IFLS Cleanup: Duplicate script scan ===")
p("Scripts folder: " .. scripts_dir)
p("")

local dup_count = 0
for name, list in pairs(by_name) do
  if #list > 1 then
    dup_count = dup_count + 1
    p("DUPLICATE: " .. name)
    table.sort(list)
    for _, full in ipairs(list) do
      p("  - " .. full)
    end
    p("")
  end
end

if dup_count == 0 then
  p("No duplicates found.")
else
  p("Total duplicate filenames: " .. dup_count)
end
p("==========================================")

-- Open Scripts folder for manual cleanup decisions
if r.CF_ShellExecute then r.CF_ShellExecute(scripts_dir) else r.MB('SWS fehlt: Kann Ordner nicht automatisch öffnen.\n\nPfad:\n'..scripts_dir,'IFLS Cleanup',0) end
r.MB("Report steht in der Konsole.\n\nEs wurde nichts gelöscht.\nScripts-Ordner wurde geöffnet.", "IFLS Cleanup", 0)
