-- @description IFLS: Export Installed FX List (Prefer VST3, dedupe)
-- @version 1.2
-- @author IFLS
-- @about
--   Exports installed FX using EnumInstalledFX().
--   Dedupe by base name (prefix stripped) and prefer VST3/VST3i over VST/VSTi.

--   Writes to: <REAPER resource path>/IFLS_Exports/

local r = reaper

local function ensure_dir(path)
  r.RecursiveCreateDirectory(path, 0)
  return path
end

local function export_dir()
  return ensure_dir(r.GetResourcePath() .. "/IFLS_Exports")
end

local function split_prefix(name)
  local p, rest = name:match("^([%w%+%-]+):%s*(.*)$")
  if p then return p, rest end
  return "", name
end

local function norm_key(name)
  local _, rest = split_prefix(name)
  rest = rest:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  return rest:lower()
end

local function prio(prefix)
  prefix = (prefix or ""):upper()
  if prefix == "VST3I" then return 1 end
  if prefix == "VST3"  then return 2 end
  if prefix == "CLAP"  then return 3 end
  if prefix == "VSTI"  then return 4 end
  if prefix == "VST"   then return 5 end
  return 99
end

local function tsv_escape(s)
  s = tostring(s or "")
  s = s:gsub("\r"," "):gsub("\n"," ")
  return s
end

local function write_file(path, content)
  local f = io.open(path, "w")
  if not f then return false end
  f:write(content)
  f:close()
  return true
end

local function json_encode(v)
  local function esc(s)
    s = tostring(s or "")
    s = s:gsub("\\","\\\\"):gsub('"','\\"'):gsub("\r","\\r"):gsub("\n","\\n")
    return '"' .. s .. '"'
  end
  local tv = type(v)
  if tv == "nil" then return "null"
  elseif tv == "boolean" then return v and "true" or "false"
  elseif tv == "number" then return tostring(v)
  elseif tv == "string" then return esc(v)
  elseif tv == "table" then
    local is_arr = true
    local max_i = 0
    for k,_ in pairs(v) do
      if type(k) ~= "number" then is_arr = false break end
      if k > max_i then max_i = k end
    end
    if is_arr then
      local parts = {}
      for i=1,max_i do parts[#parts+1] = json_encode(v[i]) end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      for k,val in pairs(v) do
        parts[#parts+1] = esc(k) .. ":" .. json_encode(val)
      end
      table.sort(parts)
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return esc(tostring(v))
end

local function main()
  if not r.EnumInstalledFX then
    r.MB("EnumInstalledFX not available.\nPlease use REAPER 7.x.", "IFLS Export Installed FX", 0)
    return
  end

  local dir = export_dir()
  local full_tsv = { "index\ttype\tbase_name\tdisplay_name\tident" }
  local best = {} -- key -> best entry

  local idx = 0
  while true do
    local ok, name, ident = r.EnumInstalledFX(idx)
    if not ok then break end

    local prefix, base = split_prefix(name or "")
    local key = norm_key(name or "")
    local p = prio(prefix)

    full_tsv[#full_tsv+1] = table.concat({
      tostring(idx),
      tsv_escape(prefix),
      tsv_escape(base),
      tsv_escape(name),
      tsv_escape(ident)
    }, "\t")

    local cur = best[key]
    if not cur or p < cur.p then
      best[key] = { p=p, type=prefix, base=base, display=name, ident=ident }
    end

    idx = idx + 1
  end

  local dedup = {}
  for _,e in pairs(best) do dedup[#dedup+1] = e end
  table.sort(dedup, function(a,b)
    if a.p ~= b.p then return a.p < b.p end
    return (a.base or ""):lower() < (b.base or ""):lower()
  end)

  local dedup_tsv = { "type\tbase_name\tdisplay_name\tident" }
  local entries = {}
  for _,e in ipairs(dedup) do
    dedup_tsv[#dedup_tsv+1] = table.concat({
      tsv_escape(e.type), tsv_escape(e.base), tsv_escape(e.display), tsv_escape(e.ident)
    }, "\t")
    entries[#entries+1] = {
      type=e.type, base_name=e.base, display_name=e.display, ident=e.ident
    }
  end

  local full_path  = dir .. "/IFLS_InstalledFX_Full.tsv"
  local dedup_path = dir .. "/IFLS_InstalledFX_Dedup_PreferVST3.tsv"
  local json_path  = dir .. "/IFLS_InstalledFX_Dedup_PreferVST3.json"

  local ok1 = write_file(full_path, table.concat(full_tsv, "\n"))
  local ok2 = write_file(dedup_path, table.concat(dedup_tsv, "\n"))
  local ok3 = write_file(json_path, json_encode({
    generated_utc = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    reaper_version = r.GetAppVersion(),
    count_full = idx,
    count_dedup = #entries,
    entries = entries
  }))

  if ok1 and ok2 and ok3 then
    r.MB("Export complete.\n\nFolder:\n  " .. dir .. "\n\nFiles:\n  " .. full_path .. "\n  " .. dedup_path .. "\n  " .. json_path,
         "IFLS Export Installed FX", 0)
  else
    r.MB("Export failed (could not write files).\nCheck write permissions for:\n" .. dir,
         "IFLS Export Installed FX", 0)
  end
end

main()
