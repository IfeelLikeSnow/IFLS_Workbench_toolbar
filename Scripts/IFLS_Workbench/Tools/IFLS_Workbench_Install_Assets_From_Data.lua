-- @description IFLS Workbench - Tools/IFLS_Workbench_Install_Assets_From_Data.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

-- @description IFLS Workbench: Install Assets (FXChains + MenuSets) from ReaPack Data cache
-- @version 0.7.10
-- @author I feel like snow
-- @about
--   ReaPack can install "Scripts/Effects/Data" cleanly, but it has no native package type for FXChains/MenuSets.
--   This tool copies those assets from:
--     <ResourcePath>/Data/IFLS_Workbench/_assets/{FXChains,MenuSets}
--   to:
--     <ResourcePath>/{FXChains,MenuSets}
--   so your Workbench tools (e.g. Slicing dropdown) can find them.


local r = reaper
local sep = package.config:sub(1,1)

local function join(a,b)
  if not a or a=="" then return b end
  local last=a:sub(-1)
  if last=="/" or last=="\\" then return a..b end
  return a..sep..b
end

local function norm(p) return (p or ""):gsub("\\","/") end

local function ensure_dir(path)
  if not path or path=="" then return end
  r.RecursiveCreateDirectory(path, 0)
end

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local function copy_file(src, dst)
  local dstdir = dst:match("^(.*)[/\\].-$")
  if dstdir then ensure_dir(dstdir) end
  local fin = io.open(src, "rb")
  if not fin then return false, "cannot open src: "..src end
  local data = fin:read("*a")
  fin:close()
  local fout = io.open(dst, "wb")
  if not fout then return false, "cannot open dst: "..dst end
  fout:write(data)
  fout:close()
  return true
end

local function enum_tree(dir, rel, out)
  rel = rel or ""
  out = out or {}
  local i=0
  while true do
    local fn = r.EnumerateFiles(dir, i)
    if not fn then break end
    out[#out+1] = {src=join(dir, fn), rel=join(rel, fn)}
    i=i+1
  end
  local j=0
  while true do
    local sub = r.EnumerateSubdirectories(dir, j)
    if not sub then break end
    enum_tree(join(dir, sub), join(rel, sub), out)
    j=j+1
  end
  return out
end

-- Public entry so other scripts can dofile() this file and call the installer.
function IFLSWB_InstallAssetsFromData(opts)
  opts = opts or {}
  local silent = opts.silent == true

  local res = r.GetResourcePath()
  local src_root = join(join(res, "Data"), join("IFLS_Workbench", "_assets"))
  local src_fx = join(src_root, "FXChains")
  local src_ms = join(src_root, "MenuSets")

  local function dir_exists(p)
    return (r.EnumerateFiles(p, 0) ~= nil) or (r.EnumerateSubdirectories(p, 0) ~= nil)
  end

  if not dir_exists(src_root) then
    local msg = "IFLS Workbench assets not found in Data cache:\n\n"..norm(src_root).."\n\n"..
                "Install the 'IFLS Workbench Assets' package via ReaPack first, then run this script again."
    if not silent then r.ShowMessageBox(msg, "IFLS Workbench", 0) end
    return false, msg
  end

  local report = {}
  local function log(s) report[#report+1]=s end

  local ok_all = true
  local copied = 0
  local skipped = 0

  local function copy_tree(srcBase, dstBase)
    if not dir_exists(srcBase) then
      log("SKIP (missing): "..norm(srcBase))
      return
    end
    local items = enum_tree(srcBase, "", {})
    for _,it in ipairs(items) do
      local dst = join(dstBase, it.rel)
      if file_exists(dst) then
        skipped = skipped + 1
      else
        local ok,err = copy_file(it.src, dst)
        if ok then
          copied = copied + 1
        else
          ok_all = false
          log("ERR: "..(err or "copy failed"))
        end
      end
    end
    log(("OK: %s â†’ %s (%d files)"):format(norm(srcBase), norm(dstBase), #items))
  end

  copy_tree(src_fx, join(res, "FXChains"))
  copy_tree(src_ms, join(res, "MenuSets"))

  log(("Copied: %d, Skipped(existing): %d"):format(copied, skipped))

  local msg = table.concat(report, "\n")
  if not silent then
    r.ShowMessageBox(msg, "IFLS Workbench: Assets installed", 0)
  end
  return ok_all, msg
end

-- If run directly from Action List
if not IFLSWB_ASSETS_DO_NOT_AUTORUN then
  IFLSWB_InstallAssetsFromData({silent=false})
end
