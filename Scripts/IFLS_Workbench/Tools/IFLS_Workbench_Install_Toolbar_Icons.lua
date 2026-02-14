-- @description IFLS Workbench - Tools/IFLS_Workbench_Install_Toolbar_Icons.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Install toolbar icons (copy into REAPER/Data/toolbar_icons)
-- @version 0.7.6
-- @author IFLS
-- @about
--   Checks if IFLSWB toolbar icons are present in:
--     <ResourcePath>/Data/toolbar_icons/
--   If any are missing, copies them from the bundled assets folder:
--     <ResourcePath>/Scripts/IFLS_Workbench/Tools/_assets/toolbar_icons/
--   Shows a report: installed / already present / missing sources.
--   Why:
--   REAPER's toolbar icon selector only lists icons from Data/toolbar_icons. Put your PNGs there.
--   This installer makes manual ZIP installs foolproof.

--

local r = reaper

local function join(a,b)
  local sep = package.config:sub(1,1)
  if a:sub(-1) == sep then return a..b end
  return a..sep..b
end

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local function read_all(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*all")
  f:close()
  return d
end

local function write_all(path, data)
  local f = io.open(path, "wb")
  if not f then return false end
  f:write(data)
  f:close()
  return true
end

local function copy_file(src, dst)
  local data = read_all(src)
  if not data then return false, "read failed" end
  local ok = write_all(dst, data)
  if not ok then return false, "write failed" end
  return true
end

local function normalize_icons(list)
  -- Only manage IFLSWB_*.png icons (ignore other packs)
  local out = {}
  for _,fn in ipairs(list) do
    if fn:match("^IFLSWB_.*%.png$") then out[#out+1] = fn end
  end
  table.sort(out, function(a,b) return a:lower() < b:lower() end)
  return out
end

-- Locations
local rp = r.GetResourcePath()
local dest_dir  = join(join(rp, "Data"), "toolbar_icons")
local asset_dir = join(join(join(join(rp, "Scripts"), "IFLS_Workbench"), "Tools"), join("_assets", "toolbar_icons"))

-- Build icon list from assets (single source of truth)
local icons = {}
local i = 0
while true do
  local fn = r.EnumerateFiles(asset_dir, i)
  if not fn then break end
  icons[#icons+1] = fn
  i = i + 1
end
icons = normalize_icons(icons)

if #icons == 0 then
  r.MB(
    "No bundled icons found in:\n\n" .. asset_dir .. "\n\n" ..
    "This likely means the repo was installed without the _assets folder.\n" ..
    "Reinstall via ReaPack, or copy the repo's Data/toolbar_icons into REAPER/Data/toolbar_icons.",
    "IFLS Icons Installer",
    0
  )
  return
end

-- Ensure destination exists
r.RecursiveCreateDirectory(dest_dir, 0)

local installed, present, missing_src = {}, {}, {}

for _,fn in ipairs(icons) do
  local dst = join(dest_dir, fn)
  if file_exists(dst) then
    present[#present+1] = fn
  else
    local src = join(asset_dir, fn)
    if not file_exists(src) then
      missing_src[#missing_src+1] = fn
    else
      local ok, err = copy_file(src, dst)
      if ok then
        installed[#installed+1] = fn
      else
        missing_src[#missing_src+1] = fn .. " (" .. tostring(err) .. ")"
      end
    end
  end
end

local function list_block(title, t)
  if #t == 0 then return title .. ": (none)\n" end
  return title .. " ("..#t.."):\n  - " .. table.concat(t, "\n  - ") .. "\n"
end

local msg =
  "Destination:\n" .. dest_dir .. "\n\n" ..
  list_block("Installed", installed) .. "\n" ..
  list_block("Already present", present) .. "\n" ..
  list_block("Missing source / failed", missing_src) .. "\n\n" ..
  "Tip: Re-open the toolbar icon chooser to see the new icons.\n" ..
  "Filter by 'IFLSWB_' to find them quickly."

r.MB(msg, "IFLS Icons Installer", 0)
