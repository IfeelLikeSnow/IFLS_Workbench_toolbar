-- @description IFLSWB TestSuite - Compile all Lua scripts in a repo folder
-- @version 1.0.0
-- @author IFLS
-- @about Scans a repo root and tries to load/compile every *.lua (no execution). Prints FAIL list to console.
-- @provides [main] .

-- Set this to your repo root (absolute path). Example:
-- local REPO_ROOT = [[C:\Users\ifeel\Documents\GitHub\IFLS_Workbench_toolbar]]
local REPO_ROOT = [[]]

local R = reaper

local function msg(s) R.ShowConsoleMsg(tostring(s).."\n") end

local function norm(p) return (p:gsub("/", "\\")) end

local function file_exists(p)
  local f = io.open(p, "rb")
  if f then f:close() return true end
  return false
end

local function list_files_recursive(root)
  local files = {}
  -- Use OS dir via io.popen (Windows: dir /b /s)
  local cmd
  if package.config:sub(1,1) == "\\" then
    cmd = 'cmd.exe /c dir /b /s "'..root..'\\*.lua"'
  else
    cmd = 'sh -lc "find \\"'..root..'\\" -type f -name \\"*.lua\\""'
  end

  local p = io.popen(cmd)
  if not p then return files end
  for line in p:lines() do
    files[#files+1] = line
  end
  p:close()
  return files
end

local function main()
  if not REPO_ROOT or REPO_ROOT == "" then
    R.MB("Bitte REPO_ROOT im Script setzen (oben).", "IFLSWB CompileAll", 0)
    return
  end
  if not file_exists(REPO_ROOT) and not (reaper.EnumerateFiles(REPO_ROOT,0)) then
    -- crude existence check
  end

  msg("== IFLSWB CompileAll ==")
  msg("RepoRoot: "..REPO_ROOT)

  local files = list_files_recursive(REPO_ROOT)
  msg(("Found %d lua files"):format(#files))

  local ok, fail = 0, 0
  local fails = {}

  for _, path in ipairs(files) do
    local chunk, err = loadfile(path)
    if chunk then
      ok = ok + 1
    else
      fail = fail + 1
      fails[#fails+1] = {path=path, err=err}
    end
  end

  msg(("Compile OK: %d  FAIL: %d"):format(ok, fail))
  if fail > 0 then
    msg("-- FAIL LIST --")
    for _, f in ipairs(fails) do
      msg(norm(f.path))
      msg("  "..tostring(f.err))
    end
  end
  msg("DONE.")
end

main()
