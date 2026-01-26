-- @description IFLS Workbench: Fix Misinstalled Nested Folders (move/merge to ResourcePath root)
-- @version 0.7.9
-- @author IFLS
-- @about
--  Fixes a common manual-install mistake where the whole bundle was extracted into:
--    <ResourcePath>/Scripts/IFLS Workbench Toolbar/IFLS Workbench/
--  or:
--    <ResourcePath>/Scripts/IFLS_Workbench_toolbar/...
--  Correct layout is:
--    <ResourcePath>/Scripts/IFLS_Workbench/...
--    <ResourcePath>/Effects/IFLS_Workbench/...
--    <ResourcePath>/FXChains/IFLS_Workbench/...
--    <ResourcePath>/Data/IFLS_Workbench/...
--    <ResourcePath>/Data/toolbar_icons/...

--

local r = reaper
local sep = package.config:sub(1,1)
local function join(a,b) if a:sub(-1)==sep then return a..b end return a..sep..b end

local function dir_exists(path)
  if r.file_exists(path) then return true end
  -- Some platforms don't report dirs via file_exists, so probe with enumerate.
  return (r.EnumerateFiles(path,0) ~= nil) or (r.EnumerateSubdirectories(path,0) ~= nil)
end

local function ensure_dir(path)
  if not path or path=="" then return end
  r.RecursiveCreateDirectory(path, 0)
end

local function copy_file(src, dst)
  local f = io.open(src, "rb"); if not f then return false, "open src" end
  local data = f:read("*all"); f:close()
  ensure_dir(dst:match("^(.*"..sep..")") or "")
  local g = io.open(dst, "wb"); if not g then return false, "open dst" end
  g:write(data); g:close()
  return true
end

local function enum_dir(dir)
  local files, dirs = {}, {}
  local i=0
  while true do local fn=r.EnumerateFiles(dir,i); if not fn then break end files[#files+1]=fn; i=i+1 end
  i=0
  while true do local dn=r.EnumerateSubdirectories(dir,i); if not dn then break end dirs[#dirs+1]=dn; i=i+1 end
  return files, dirs
end

local function copy_tree(src, dst, report)
  if not dir_exists(src) then return end
  ensure_dir(dst)
  local files, dirs = enum_dir(src)
  for _,fn in ipairs(files) do
    local ok, err = copy_file(join(src, fn), join(dst, fn))
    if report then
      if ok then report.copied = report.copied + 1
      else report.failed[#report.failed+1] = src.." -> "..dst.." ("..tostring(err)..")" end
    end
  end
  for _,dn in ipairs(dirs) do
    copy_tree(join(src, dn), join(dst, dn), report)
  end
end

local function timestamp()
  local t=os.date("*t")
  return string.format("%04d%02d%02d_%02d%02d%02d", t.year,t.month,t.day,t.hour,t.min,t.sec)
end

local resource = r.GetResourcePath()
local scripts = join(resource, "Scripts")

local candidates = {
  join(join(scripts, "IFLS Workbench Toolbar"), "IFLS Workbench"),
  join(scripts, "IFLS Workbench Toolbar"),
  join(scripts, "IFLS_Workbench_toolbar"),
  join(join(scripts, "IFLS_Workbench_toolbar"), "IFLS_Workbench_toolbar"),
  join(join(scripts, "IFLS_Workbench_toolbar"), "IFLS_Workbench"),
}

local bad = nil
for _,c in ipairs(candidates) do
  if dir_exists(c) and (dir_exists(join(c,"Scripts")) or dir_exists(join(c,"Effects")) or dir_exists(join(c,"FXChains")) or dir_exists(join(c,"Data"))) then
    bad = c; break
  end
end

if not bad then
  r.MB("No nested/misinstalled IFLS bundle folder found.\n\nIf you still see a nested folder, delete it manually:\n"..scripts..sep.."IFLS Workbench Toolbar\n\nThen reinstall via ReaPack.",
    "IFLS Workbench - Fix Misinstall", 0)
  return
end

local report = {copied=0, failed={}}

r.Undo_BeginBlock()
r.PreventUIRefresh(1)

local function merge(src_rel, dst_rel)
  local src = join(bad, src_rel)
  local dst = join(resource, dst_rel)
  if dir_exists(src) then
    copy_tree(src, dst, report)
  end
end

merge("Scripts/IFLS_Workbench", "Scripts/IFLS_Workbench")
merge("Effects/IFLS_Workbench", "Effects/IFLS_Workbench")
merge("FXChains/IFLS_Workbench", "FXChains/IFLS_Workbench")
merge("Data/IFLS_Workbench", "Data/IFLS_Workbench")
merge("Data/toolbar_icons", "Data/toolbar_icons")
merge("MenuSets", "MenuSets")
merge("DOCS", "DOCS")

r.PreventUIRefresh(-1)
r.UpdateArrange()
r.Undo_EndBlock("IFLS Workbench: Fix misinstalled nested folders", -1)

local msg = "Nested install folder found:\n"..bad.."\n\nMerged files: "..tostring(report.copied)
if #report.failed>0 then msg = msg.."\nFailed copies: "..tostring(#report.failed) end
msg = msg.."\n\nMove the nested folder to a timestamped backup? (recommended)"

local ret = r.MB(msg, "IFLS Workbench - Fix Misinstall", 4)
if ret == 6 then
  local backup_parent = join(scripts, "_IFLS_BACKUP_MISINSTALL_"..timestamp())
  ensure_dir(backup_parent)
  local leaf = bad:match("[^"..sep.."]+$") or "NestedBundle"
  local backup_dst = join(backup_parent, leaf)
  local ok = os.rename(bad, backup_dst)
  if ok then
    r.MB("Moved nested folder to:\n"..backup_dst.."\n\nYou can delete it after verifying everything works.",
      "IFLS Workbench - Fix Misinstall", 0)
  else
    r.MB("Could not move automatically (file lock?).\n\nClose Explorer/REAPER and try again, or delete manually:\n"..bad,
      "IFLS Workbench - Fix Misinstall", 0)
  end
end
