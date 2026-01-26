-- @description IFLS Workbench: IFLS_Workbench_InstallDoctor_Fix_Nested_Folders
-- @version 1.0.0

ï»¿-- @description IFLS Workbench: Install Doctor (Fix nested "Scripts/IFLS Workbench Toolbar" installs)
-- @version 0.7.9
-- @author I feel like snow
-- @about
--   See README.md for usage / docs.

--   Repairs the most common manual-install mistake:
--     Unzipping the whole repository into <ResourcePath>/Scripts/
--   which creates:
--     <ResourcePath>/Scripts/IFLS Workbench Toolbar/IFLS Workbench/{Scripts,Effects,FXChains,Data,...}
--
--   This script:
--     1) Detects known "bad" folders under <ResourcePath>/Scripts/
--     2) Finds the embedded repository root (contains Scripts/Effects/FXChains/Data)
--     3) Merges those folders back into <ResourcePath>/ (correct locations)
--     4) Optionally renames the bad folder to a timestamped backup.
--
--   Safe by default: it MERGES (overwrites newer or same-name files).
--   Close REAPER before running if you want a guaranteed clean move/rename.
--

local r = reaper
local sep = package.config:sub(1,1)

local function join(a,b)
  if not a or a=="" then return b end
  local last = a:sub(-1)
  if last=="/" or last=="\\" then return a..b end
  return a..sep..b
end

local function dirname(p)
  return p:match("^(.*)[/\\].-$") or ""
end

local function dir_exists(p)
  return r.EnumerateFiles(p,0) ~= nil or r.EnumerateSubdirectories(p,0) ~= nil
end

local function file_exists(p)
  local f = io.open(p,"rb"); if f then f:close(); return true end
  return false
end

local function ensure_dir(p)
  if p=="" then return end
  r.RecursiveCreateDirectory(p, 0)
end

local function copy_file(src, dst)
  local f = io.open(src,"rb")
  if not f then return false, "open src failed" end
  local data = f:read("*all"); f:close()

  ensure_dir(dirname(dst))
  local o = io.open(dst,"wb")
  if not o then return false, "open dst failed" end
  o:write(data); o:close()
  return true
end

local function copy_tree(src_dir, dst_dir, counters)
  ensure_dir(dst_dir)

  -- files
  local i = 0
  while true do
    local fn = r.EnumerateFiles(src_dir, i)
    if not fn then break end
    local ok, err = copy_file(join(src_dir, fn), join(dst_dir, fn))
    if ok then
      counters.files = counters.files + 1
    else
      counters.errors = counters.errors + 1
      counters.err_list[#counters.err_list+1] = ("FILE: %s -> %s (%s)"):format(join(src_dir,fn), join(dst_dir,fn), tostring(err))
    end
    i = i + 1
  end

  -- subdirs
  local j = 0
  while true do
    local dn = r.EnumerateSubdirectories(src_dir, j)
    if not dn then break end
    copy_tree(join(src_dir, dn), join(dst_dir, dn), counters)
    j = j + 1
  end
end

local function looks_like_repo_root(p)
  return dir_exists(join(p,"Scripts")) and dir_exists(join(p,"Effects")) and dir_exists(join(p,"Data"))
end

local rp = r.GetResourcePath()

-- Known bad install folders (under Scripts/)
local bad_roots = {
  join(rp, "Scripts/IFLS Workbench Toolbar"),
  join(rp, "Scripts/IFLS_Workbench_toolbar"),
  join(rp, "Scripts/IFLS_Workbench_toolbar_COMPLETE"),
}

local found = {}
for _,b in ipairs(bad_roots) do
  if dir_exists(b) then found[#found+1] = b end
end

if #found == 0 then
  r.ShowMessageBox("No known nested install folder was found under:\n\n"..join(rp,"Scripts").."\n\nIf you still see odd paths, check for folders like:\n  \"IFLS Workbench Toolbar\" inside Scripts.\n\nNothing changed.", "IFLS Workbench - Install Doctor", 0)
  return
end

local report = {}
report[#report+1] = "Found possible nested install folders:\n"
for i,p in ipairs(found) do report[#report+1] = ("  %d) %s"):format(i,p) end

-- Choose first match that contains a repo root (either directly, or one level down "IFLS Workbench")
local candidate_repo_root = nil
local candidate_bad_root = nil

for _,bad in ipairs(found) do
  if looks_like_repo_root(bad) then
    candidate_repo_root, candidate_bad_root = bad, bad
    break
  end
  local nested = join(bad, "IFLS Workbench")
  if looks_like_repo_root(nested) then
    candidate_repo_root, candidate_bad_root = nested, bad
    break
  end
end

if not candidate_repo_root then
  r.ShowMessageBox(table.concat(report,"\n").."\n\nNone of these folders contained a recognizable repo layout.\nExpected to find Scripts/Effects/Data inside.\n\nNothing changed.", "IFLS Workbench - Install Doctor", 0)
  return
end

report[#report+1] = "\nRepo root detected at:\n  "..candidate_repo_root
report[#report+1] = "\nThis will MERGE these folders back into ResourcePath:\n  "..rp
report[#report+1] = "\nFolders merged: Scripts, Effects, FXChains, Data, MenuSets, DOCS (if present)."

local ret = r.ShowMessageBox(table.concat(report,"\n").."\n\nProceed?", "IFLS Workbench - Install Doctor", 4)
if ret ~= 6 then return end

local counters = { files=0, errors=0, err_list={} }
local folders = {"Scripts","Effects","FXChains","Data","MenuSets","DOCS"}
for _,n in ipairs(folders) do
  local src = join(candidate_repo_root, n)
  if dir_exists(src) then
    copy_tree(src, join(rp, n), counters)
  end
end

local msg = ("Merged %d files into:\n%s"):format(counters.files, rp)
if counters.errors > 0 then
  msg = msg .. ("\n\nErrors: %d\n(see ReaScript console)"):format(counters.errors)
  r.ShowConsoleMsg("IFLS Install Doctor errors:\n")
  for _,e in ipairs(counters.err_list) do r.ShowConsoleMsg("  "..e.."\n") end
end

-- Offer to rename the bad folder (outer)
local backup = candidate_bad_root .. "_BACKUP_" .. os.date("%Y%m%d_%H%M%S")
local ret2 = r.ShowMessageBox(msg.."\n\nRename the bad folder to:\n"..backup.."\n\n(Recommended, so it doesn't confuse future installs.)", "IFLS Workbench - Install Doctor", 4)
if ret2 == 6 then
  local ok, err = os.rename(candidate_bad_root, backup)
  if ok then
    r.ShowMessageBox("Done.\n\nBad folder renamed to:\n"..backup.."\n\nRestart REAPER now.", "IFLS Workbench - Install Doctor", 0)
  else
    r.ShowMessageBox("Merged files, but failed to rename:\n"..tostring(candidate_bad_root).."\n\nReason:\n"..tostring(err).."\n\nClose REAPER and rename/delete manually.", "IFLS Workbench - Install Doctor", 0)
  end
else
  r.ShowMessageBox("Done.\n\nFiles merged. Restart REAPER now.", "IFLS Workbench - Install Doctor", 0)
end
