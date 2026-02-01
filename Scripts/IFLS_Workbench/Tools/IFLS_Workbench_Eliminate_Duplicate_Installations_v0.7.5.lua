-- @description IFLS Workbench: Eliminate Duplicate Installations (Quarantine) v0.7.5
-- @version 0.7.5
-- @author IFLS
-- @about
--   Moves duplicate IFLS_Workbench installations out of <resource>/Scripts into <resource>/Scripts/_IFLS_QUARANTINE/<timestamp>/.
--   Canonical install folder is: <resource>/Scripts/IFLS_Workbench/
--   Optionally tries to remove quarantined scripts from the Action List.
--   Safe defaults: dry-run first, then explicit confirmation.

--
--

local r = reaper

local function msg(s) r.ShowConsoleMsg(tostring(s).."\n") end

local function join(a,b)
  if a:sub(-1) == "/" or a:sub(-1) == "\\" then return a..b end
  return a.."/"..b
end

local function norm(p)
  -- normalize to forward slashes for easier comparisons
  return (p:gsub("\\","/"))
end

local function exists(path)
  local ok = r.file_exists(path)
  return ok == true
end

local function mkdir_p(path)
  local p = norm(path)
  local acc = ""
  for part in p:gmatch("[^/]+") do
    acc = acc == "" and part or (acc.."/"..part)
    -- skip Windows drive root like C:
    if acc:match("^[A-Za-z]:$") then
      acc = acc.."/"
    else
      r.RecursiveCreateDirectory(acc, 0)
    end
  end
end

local function move_path(src, dst)
  -- try rename first; if fails, fallback to copy+delete (best effort)
  src, dst = norm(src), norm(dst)
  mkdir_p(dst:match("(.+)/[^/]+$") or dst)
  local ok = os.rename(src, dst)
  if ok then return true, "rename" end

  -- fallback: recurse copy
  local function copy_file(s, d)
    local f1 = io.open(s, "rb"); if not f1 then return false end
    local data = f1:read("*all"); f1:close()
    mkdir_p(d:match("(.+)/[^/]+$") or d)
    local f2 = io.open(d, "wb"); if not f2 then return false end
    f2:write(data); f2:close()
    return true
  end

  local function is_dir(p)
    local ok, err, code = os.rename(p, p)
    if ok then
      local f = io.open(p, "rb")
      if f then f:close(); return false end
      return true
    end
    -- On Windows, rename can fail for dirs w/out permissions; treat as maybe-dir if path endswith /
    return false
  end

  local function scan(dir, out)
    local i = 0
    while true do
      local file = r.EnumerateFiles(dir, i)
      if not file then break end
      out[#out+1] = {src = norm(dir.."/"..file), is_dir = false}
      i = i + 1
    end
    i = 0
    while true do
      local sub = r.EnumerateSubdirectories(dir, i)
      if not sub then break end
      out[#out+1] = {src = norm(dir.."/"..sub), is_dir = true}
      scan(dir.."/"..sub, out)
      i = i + 1
    end
  end

  local items = {}
  scan(src, items)

  -- create dirs first (shallow to deep)
  table.sort(items, function(a,b)
    if a.is_dir ~= b.is_dir then return a.is_dir end
    return #a.src < #b.src
  end)

  for _,it in ipairs(items) do
    local rel = it.src:sub(#src+2)
    local target = dst.."/"..rel
    if it.is_dir then
      mkdir_p(target)
    else
      local ok2 = copy_file(it.src, target)
      if not ok2 then return false, "copy_failed: "..it.src end
    end
  end

  -- delete files then dirs (deep to shallow)
  table.sort(items, function(a,b) return #a.src > #b.src end)
  for _,it in ipairs(items) do
    if it.is_dir then
      os.remove(it.src) -- will fail for non-empty, but after file deletes should succeed on most systems
    else
      os.remove(it.src)
    end
  end
  os.remove(src) -- final
  return true, "copy+delete"
end

local function collect_ifls_candidates(scripts_root)
  local hits = {}
  local function scan(dir)
    -- if folder contains IFLS_Workbench as path part, keep walking; otherwise still walk to find nested installs
    local i=0
    while true do
      local sub = r.EnumerateSubdirectories(dir, i)
      if not sub then break end
      local p = norm(dir.."/"..sub)
      if sub == "IFLS_Workbench" then
        hits[#hits+1] = p
      end
      scan(p)
      i=i+1
    end
  end
  scan(scripts_root)
  return hits
end

local function collect_ifls_scripts_under(dir)
  local scripts = {}
  local function scan(d)
    local i=0
    while true do
      local f = r.EnumerateFiles(d, i)
      if not f then break end
      if f:match("%.lua$") or f:match("%.eel$") or f:match("%.py$") then
        scripts[#scripts+1] = norm(d.."/"..f)
      end
      i=i+1
    end
    i=0
    while true do
      local sub = r.EnumerateSubdirectories(d, i)
      if not sub then break end
      scan(d.."/"..sub)
      i=i+1
    end
  end
  scan(dir)
  return scripts
end

local function remove_scripts_from_action_list(paths)
  -- remove from common sections (Main, MIDI Editor, etc.) best-effort
  local sections = {0, 32060, 32061, 32062, 32063, 32064}
  for _,sec in ipairs(sections) do
    for _,p in ipairs(paths) do
      r.AddRemoveReaScript(false, sec, p, false)
    end
  end
  -- commit (sec=0 commit=1 is enough)
  r.AddRemoveReaScript(false, 0, "", true)
end

local function main()
  r.ClearConsole()
  msg("IFLS Workbench - Eliminate Duplicate Installations v0.7.5")
  msg("------------------------------------------------------")

  local resource = norm(r.GetResourcePath())
  local scripts_root = resource.."/Scripts"
  local canonical = scripts_root.."/IFLS_Workbench"

  if not exists(canonical) then
    msg("WARNING: canonical folder not found:\n  "..canonical)
    msg("Searching for any 'IFLS_Workbench' folders...")
  end

  local candidates = collect_ifls_candidates(scripts_root)
  if #candidates == 0 then
    r.MB("No IFLS_Workbench folder found under Scripts.\nNothing to do.", "IFLS Dedupe", 0)
    return
  end

  -- pick canonical: prefer exact canonical path if present; else pick the shortest path
  local canonical_pick = canonical
  local found_canonical = false
  for _,p in ipairs(candidates) do
    if norm(p) == canonical then found_canonical = true end
  end
  if not found_canonical then
    table.sort(candidates, function(a,b) return #a < #b end)
    canonical_pick = candidates[1]
    msg("Canonical folder auto-selected:\n  "..canonical_pick)
  else
    msg("Canonical folder:\n  "..canonical_pick)
  end

  -- duplicates = all other candidates AND any folders that contain IFLS_Workbench scripts outside canonical_pick
  local duplicates = {}
  for _,p in ipairs(candidates) do
    if norm(p) ~= norm(canonical_pick) then
      duplicates[#duplicates+1] = p
    end
  end

  if #duplicates == 0 then
    r.MB("No duplicate IFLS_Workbench installations found.\nCanonical is the only one.\n\n"..canonical_pick, "IFLS Dedupe", 0)
    return
  end

  -- prepare quarantine
  local ts = os.date("%Y%m%d_%H%M%S")
  local quarantine_root = scripts_root.."/_IFLS_QUARANTINE/"..ts
  mkdir_p(quarantine_root)

  msg("Duplicates detected:")
  for _,d in ipairs(duplicates) do msg("  "..d) end
  msg("")
  msg("Quarantine target:\n  "..quarantine_root)
  msg("")

  local confirm = r.MB(
    "Found "..tostring(#duplicates).." duplicate IFLS_Workbench folder(s).\n\n"..
    "Canonical (keep):\n"..canonical_pick.."\n\n"..
    "Move duplicates into:\n"..quarantine_root.."\n\n"..
    "Proceed?",
    "IFLS Dedupe v0.7.5",
    4 -- Yes/No
  )
  if confirm ~= 6 then
    msg("Cancelled.")
    return
  end

  local moved = {}
  local failures = {}

  for _,src in ipairs(duplicates) do
    local leaf = src:match("([^/]+)$") or "IFLS_Workbench"
    -- keep parent folder name too, to preserve context
    local parent = src:match("([^/]+)/IFLS_Workbench$") or "UNKNOWN_PARENT"
    local dst = quarantine_root.."/"..parent.."__"..leaf
    local ok, how = move_path(src, dst)
    if ok then
      moved[#moved+1] = {src=src, dst=dst, how=how}
      msg("MOVED ("..how.."):\n  "..src.."\n  -> "..dst)
    else
      failures[#failures+1] = {src=src, dst=dst, err=how}
      msg("FAILED:\n  "..src.."\n  -> "..dst.."\n  err="..tostring(how))
    end
  end

  -- optional: action list cleanup
  if #moved > 0 then
    local cleanup = r.MB("Remove quarantined scripts from the Action List registrations (best effort)?", "IFLS Dedupe", 4)
    if cleanup == 6 then
      local script_paths = {}
      for _,m in ipairs(moved) do
        local scripts = collect_ifls_scripts_under(m.dst)
        for _,p in ipairs(scripts) do script_paths[#script_paths+1] = p end
      end
      remove_scripts_from_action_list(script_paths)
      msg("Action List cleanup attempted for "..tostring(#script_paths).." script files.")
    else
      msg("Skipped Action List cleanup.")
    end
  end

  -- report
  local exports = resource.."/IFLS_Exports"
  mkdir_p(exports)
  local report_path = exports.."/IFLS_DuplicateCleanup_Report_"..ts..".txt"
  local f = io.open(report_path, "w")
  if f then
    f:write("IFLS Duplicate Cleanup Report v0.7.5\n")
    f:write("Timestamp: "..ts.."\n\n")
    f:write("Canonical kept:\n"..canonical_pick.."\n\n")
    f:write("Moved:\n")
    for _,m in ipairs(moved) do
      f:write("- "..m.src.." -> "..m.dst.." ("..m.how..")\n")
    end
    f:write("\nFailures:\n")
    for _,e in ipairs(failures) do
      f:write("- "..e.src.." -> "..e.dst.." ("..tostring(e.err)..")\n")
    end
    f:close()
  end

  r.MB("Done.\n\nMoved: "..tostring(#moved).."\nFailures: "..tostring(#failures).."\n\nReport:\n"..report_path, "IFLS Dedupe", 0)
end

main()
