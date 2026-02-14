--[[
IFLS FX Folder Generator v1.3.4
===============================
Based on v1.3.3 plus:

A) infer_fmt() improved:
   - detects file paths (.vst3/.clap/.dll/.component) in addition to REAPER prefixes

B) Optional ident normalization (matching layer):
   - Helps when EnumInstalledFX returns VST3 "Contents/binary" paths but master uses package-root (.vst3 folder).
   - You can keep master idents "raw truth" OR standardize; generator will still resolve to raw installed ident for output.

Normalization logic:
- normalize_ident("C:\...\Plugin.vst3\Contents\x86_64-win\Plugin.vst3") -> "C:\...\Plugin.vst3"
- same for .clap
- VST2 (.dll) is left unchanged

Other features:
- Hard-Preferred mode (optional) using Scanner CSV preferred=true
- Audit report (optional)
- MERGE mode (optional; backs up reaper-fxfolders.ini)
- Pseudo-hierarchy via name convention "IFLS ▸ A ▸ B ▸ C"

References:
- EnumInstalledFX: https://www.reaper.fm/sdk/reascript/reascripthelp.html
- reaper-fxfolders.ini format: https://mespotin.uber.space/Ultraschall/Reaper-Filetype-Descriptions.html

License: CC0 / Public Domain
--]]

local r = reaper

------------------------
-- utils
------------------------
local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function sanitize_ini(s)
  s = trim(s)
  s = s:gsub("[\r\n]"," ")
  s = s:gsub("=","-")
  return s
end
local function sanitize_folder_piece(s)
  s = trim(s); if s=="" then s="Uncategorized" end
  s = s:gsub("_"," ")
  s = s:gsub("=","-")
  return s
end
local function split_category(cat)
  cat = trim(cat or "")
  if cat=="" then return {"Uncategorized"} end
  local parts={}
  for p in cat:gmatch("[^/]+") do parts[#parts+1]=sanitize_folder_piece(p) end
  if #parts==0 then parts={"Uncategorized"} end
  return parts
end
local function join_path(parts) return table.concat(parts, " ▸ ") end
local function read_all(p) local f=io.open(p,"rb"); if not f then return nil end local c=f:read("*all"); f:close(); return c end
local function write_all(p,c) local f=io.open(p,"wb"); if not f then return false end f:write(c); f:close(); return true end
local function table_count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end

-- normalize ident to package-root for VST3/CLAP (optional)
local function normalize_ident(ident)
  local s = tostring(ident or "")
  local low = s:lower()
  local p = low:find("%.vst3", 1, false)
  if p then return s:sub(1, p+4) end
  p = low:find("%.clap", 1, false)
  if p then return s:sub(1, p+4) end
  return s
end

------------------------
-- CSV parsing (supports quotes)
------------------------
local function parse_csv(c)
  local rows,row,field={},{},""
  local i,len,inq=1,#c,false
  local function push_field() row[#row+1]=field; field="" end
  local function push_row() if #row>0 then rows[#rows+1]=row end; row={} end
  while i<=len do
    local ch=c:sub(i,i)
    if inq then
      if ch=='"' then
        if c:sub(i+1,i+1)=='"' then field=field..'"'; i=i+1 else inq=false end
      else field=field..ch end
    else
      if ch=='"' then inq=true
      elseif ch==',' then push_field()
      elseif ch=='\n' then push_field(); push_row()
      elseif ch=='\r' then if c:sub(i+1,i+1)=='\n' then i=i+1 end push_field(); push_row()
      else field=field..ch end
    end
    i=i+1
  end
  push_field(); push_row()
  return rows
end
local function header_index(h)
  local t={}
  for i,v in ipairs(h) do v=v:gsub("^\239\187\191",""); t[trim(v)]=i end
  return t
end

------------------------
-- EnumInstalledFX
------------------------
local function enum_installed_fx(enable_norm)
  local raw={}
  local norm_to_raw = {}
  local i=0
  while true do
    local ok,nameOut,identOut = r.EnumInstalledFX(i)
    if not ok then break end
    if identOut and identOut ~= "" then
      raw[identOut:lower()] = identOut
      if enable_norm then
        local n = normalize_ident(identOut)
        norm_to_raw[n:lower()] = norm_to_raw[n:lower()] or identOut -- keep first
      end
    end
    i=i+1
  end
  return raw, norm_to_raw
end

------------------------
-- Preferred format fallback ranking
------------------------
local function infer_fmt(ident, nameOut)
  local u=(ident or ""):upper()
  local g=(nameOut or ""):upper()

  -- Prefix based
  if u:find("^VST3") or g:find("^VST3") then return "vst3" end
  if u:find("^CLAP") or g:find("^CLAP") then return "clap" end
  if u:find("^VST") or g:find("^VST") then return "vst" end
  if u:find("^AU") or g:find("^AU") then return "au" end
  if u:find("^JS") or u:find("^JS:") or g:find("^JS") then return "jsfx" end
  if u:find("^DX") or g:find("^DX") then return "dx" end
  if u:find("^AAX") or g:find("^AAX") then return "aax" end

  -- Path based
  local low=tostring(ident or ""):lower()
  if low:find(".vst3", 1, true) then return "vst3" end
  if low:find(".clap", 1, true) then return "clap" end
  if low:match("%.dll$") then return "vst" end
  if low:match("%.component$") then return "au" end

  return "unknown"
end
local fmt_rank = {vst3=1, clap=2, vst=3, au=4, jsfx=5, dx=6, aax=7, unknown=99}

local function fx_type_from_ident(ident)
  local u=(ident or ""):upper()
  if u:find("^JS") or u:find("^JS:") then return 2 end
  if u:find("^AU") then return 5 end
  if u:find("^DX") then return 0 end
  return 3
end

-- Canonical key used by the scanner and generator
local function canonical_key(nameOut, identOut)
  local s=identOut or ""
  local tail=s:match("^[^:]+:%s*(.*)$")
  tail=trim(tail or "")
  if tail~="" then
    tail=tail:gsub("%s*%(%s*x64%s*%)%s*$","")
    tail=tail:gsub("%s*%(%s*x86%s*%)%s*$","")
    return tail:lower()
  end
  return (nameOut or ""):lower()
end

------------------------
-- Load scanner CSV preferred map + audit stats
-- expected columns: group_key,preferred,ident (optional: ident_norm)
------------------------
local function load_scanner_preferred(scanner_csv_path)
  if not scanner_csv_path or scanner_csv_path=="" then return nil,nil,nil,nil end
  local txt = read_all(scanner_csv_path)
  if not txt then return nil,nil,nil,nil end
  local rows = parse_csv(txt)
  if #rows < 2 then return nil,nil,nil,nil end
  local H = header_index(rows[1])
  local c_gk, c_pref, c_ident, c_identn = H["group_key"], H["preferred"], H["ident"], H["ident_norm"]
  if not (c_gk and c_pref and c_ident) then return nil,nil,nil,nil end

  local by_group = {}
  local preferred_set_by_ident = {}
  local ident_norm_by_raw = {} -- raw_lower -> norm (if present)
  local pref_count_by_group = {}
  local group_seen = {}

  for i=2,#rows do
    local rrow = rows[i]
    local gk = trim(rrow[c_gk] or ""):lower()
    local pref = trim(rrow[c_pref] or ""):lower()
    local ident = trim(rrow[c_ident] or "")
    local identn = (c_identn and trim(rrow[c_identn] or "")) or ""
    if gk ~= "" and ident ~= "" then
      group_seen[gk] = true
      if identn ~= "" then ident_norm_by_raw[ident:lower()] = identn end
      if pref == "true" or pref == "1" or pref == "yes" then
        pref_count_by_group[gk] = (pref_count_by_group[gk] or 0) + 1
        if not by_group[gk] then
          by_group[gk] = ident
        end
        preferred_set_by_ident[ident:lower()] = true
      end
    end
  end

  local audit = {
    total_groups = table_count(group_seen),
    groups_with_preferred = table_count(by_group),
    groups_missing_preferred = 0,
    groups_multiple_preferred = 0,
    pref_count_by_group = pref_count_by_group
  }

  for gk,_ in pairs(group_seen) do
    if not by_group[gk] then audit.groups_missing_preferred = audit.groups_missing_preferred + 1 end
    if (pref_count_by_group[gk] or 0) > 1 then audit.groups_multiple_preferred = audit.groups_multiple_preferred + 1 end
  end

  return by_group, preferred_set_by_ident, ident_norm_by_raw, audit
end

------------------------
-- fxfolders.ini parse/build (merge)
------------------------
local function parse_fxfolders_ini(txt)
  local folders = {}
  if not txt or txt=="" then return folders end
  local name_by_idx,id_by_idx={}, {}
  local section=nil
  for line in txt:gmatch("[^\r\n]+") do
    local sec=line:match("^%[([^%]]+)%]$")
    if sec then section=sec end
    if section=="Folders" then
      local nidx,nval=line:match("^Name(%d+)%=(.*)$"); if nidx then name_by_idx[tonumber(nidx)]=nval end
      local iidx,ival=line:match("^Id(%d+)%=(.*)$"); if iidx then id_by_idx[tonumber(iidx)]=tonumber(ival) end
    end
  end
  local name_by_id={}
  for idx,name in pairs(name_by_idx) do local id=id_by_idx[idx]; if id~=nil then name_by_id[id]=name end end

  local folder_items_by_id={}
  section=nil; local cur=nil
  for line in txt:gmatch("[^\r\n]+") do
    local fid=line:match("^%[Folder(%d+)%]$")
    if fid then cur=tonumber(fid); section="Folder"; folder_items_by_id[cur]=folder_items_by_id[cur] or {types={},items={}} end
    if section=="Folder" and cur~=nil then
      local tIdx,tVal=line:match("^Type(%d+)%=(.*)$"); if tIdx then folder_items_by_id[cur].types[tonumber(tIdx)]=tonumber(tVal) or 3 end
      local iIdx,iVal=line:match("^Item(%d+)%=(.*)$"); if iIdx then folder_items_by_id[cur].items[tonumber(iIdx)]=iVal end
    end
  end

  local ids={}; for id,_ in pairs(name_by_id) do ids[#ids+1]=id end; table.sort(ids)
  for _,id in ipairs(ids) do
    local name=name_by_id[id]; local blk=folder_items_by_id[id]
    local items={}
    if blk then
      local maxn=0; for k,_ in pairs(blk.items) do if k>maxn then maxn=k end end
      for i=0,maxn do
        local it=blk.items[i]; local ty=blk.types[i]
        if it and ty then items[#items+1]={type=ty,item=it} end
      end
    end
    folders[#folders+1]={name=name, items=items}
  end
  return folders
end

local function build_fxfolders_ini(folders)
  local out={}
  out[#out+1]="[Folders]"
  out[#out+1]="NbFolders="..tostring(#folders)
  for i,f in ipairs(folders) do
    out[#out+1]=("Name%d=%s"):format(i-1,f.name)
    out[#out+1]=("Id%d=%d"):format(i-1,i-1)
  end
  for i,f in ipairs(folders) do
    out[#out+1]=""
    out[#out+1]=("[Folder%d]"):format(i-1)
    out[#out+1]=("Nb=%d"):format(#f.items)
    for j,it in ipairs(f.items) do
      out[#out+1]=("Type%d=%d"):format(j-1,it.type)
      out[#out+1]=("Item%d=%s"):format(j-1,it.item)
    end
  end
  return table.concat(out,"\r\n").."\r\n"
end

------------------------
-- MAIN
------------------------
r.ClearConsole()

local splitFmt = (r.MB("Create format-split leaf folders?\n\nYES = split (keeps all formats)\nNO = no split (dedup to preferred)", "IFLS v1.3.4", 4) == 6)
local mergeMode = (r.MB("MERGE mode?\n\nYES = merge into existing reaper-fxfolders.ini (replace IFLS folders only)\nNO = generate separate import file (recommended)", "IFLS v1.3.4", 4) == 6)

local doAudit = (r.MB("Write audit report?\n\nYES = create audit .txt\nNO = skip", "IFLS v1.3.4", 4) == 6)

local enableNorm = (r.MB("Enable ident normalization for matching?\n\nYES = try package-root matching for VST3/CLAP\nNO = raw ident matching only", "IFLS v1.3.4", 4) == 6)

local useScanner = (not splitFmt) and (r.MB("Use Scanner CSV for deterministic preferred selection?\n\nYES = select scanner CSV\nNO = fallback ranking", "IFLS v1.3.4", 4) == 6)

local hardPreferred = false
if useScanner then
  hardPreferred = (r.MB("Hard-Preferred mode?\n\nYES = ONLY preferred=true entries kept\nNO = preferred wins; missing preferred falls back to ranking", "IFLS v1.3.4", 4) == 6)
end

local preferred_by_group, preferred_by_ident, scanner_norm_by_raw, scanner_audit = nil, nil, nil, nil
local scan_path = nil
if useScanner then
  local okScan, p = r.GetUserFileNameForRead("", "Select Scanner CSV (preferred=true/false)", "csv")
  if okScan then
    scan_path = p
    preferred_by_group, preferred_by_ident, scanner_norm_by_raw, scanner_audit = load_scanner_preferred(p)
  end
end

local ok,csv_path=r.GetUserFileNameForRead("","Select IFLS Master CSV","csv")
if not ok then return end
local content=read_all(csv_path)
if not content then r.MB("Cannot read CSV","IFLS",0); return end
local rows=parse_csv(content)
if #rows<2 then r.MB("CSV looks empty","IFLS",0); return end

local H=header_index(rows[1])
local c_name,c_vendor,c_ident,c_cat = H["name"],H["vendor"],H["ident"],H["primary_category_v11"]
if not c_cat then r.MB("Missing primary_category_v11","IFLS",0); return end

if r.APIExists and not r.APIExists("EnumInstalledFX") then
  r.MB("EnumInstalledFX not available in this REAPER build.\nUpdate REAPER.","IFLS",0)
  return
end

local installed_fx, installed_norm = enum_installed_fx(enableNorm)
r.ShowConsoleMsg("Installed FX enumerated: "..tostring(table_count(installed_fx)).."\n")
if enableNorm then r.ShowConsoleMsg("Installed FX normalized map: "..tostring(table_count(installed_norm)).."\n") end

-- audit counters
local audit = {
  master_rows = 0,
  master_matched = 0,
  master_unmatched = 0,
  normalized_matches = 0,
  preferred_not_installed = 0,
  groups_missing_preferred = scanner_audit and scanner_audit.groups_missing_preferred or 0,
  groups_multiple_preferred = scanner_audit and scanner_audit.groups_multiple_preferred or 0,
  scan_path = scan_path,
  master_path = csv_path,
  enable_norm = enableNorm
}

if preferred_by_group then
  for gk,ident in pairs(preferred_by_group) do
    if not installed_fx[ident:lower()] then
      audit.preferred_not_installed = audit.preferred_not_installed + 1
    end
  end
end

local folder_choice = {}
local folder_seen, folder_order = {}, {}

local function ensure_folder(fname)
  if not folder_seen[fname] then
    folder_seen[fname]=true
    folder_order[#folder_order+1]=fname
    folder_choice[fname]={}
  end
end

local function consider(folder, groupKey, identOut, fxType, rank, isPreferred, canFallback)
  local cur = folder_choice[folder][groupKey]
  if isPreferred then
    folder_choice[folder][groupKey] = {ident=identOut, type=fxType, rank=rank, preferred=true}
    return
  end
  if cur and cur.preferred then return end
  if not canFallback then return end
  if not cur or rank < cur.rank then
    folder_choice[folder][groupKey] = {ident=identOut, type=fxType, rank=rank, preferred=false}
  end
end

for i=2,#rows do
  audit.master_rows = audit.master_rows + 1
  local rrow=rows[i]
  local parts=split_category(rrow[c_cat])
  local base={"IFLS"}
  for _,p in ipairs(parts) do base[#base+1]=p end
  local baseFolder = join_path(base)

  local ident_raw = (rrow[c_ident] or "")
  local ident_lower = tostring(ident_raw):lower()
  local name=(c_name and rrow[c_name]) or ""
  local vendor=(c_vendor and rrow[c_vendor]) or ""

  -- 1) Direct match
  local item = installed_fx[ident_lower]

  -- 2) Normalized match (optional)
  if (not item) and enableNorm and ident_raw ~= "" then
    local n = normalize_ident(ident_raw):lower()
    local raw_match = installed_norm[n]
    if raw_match then
      item = raw_match
      audit.normalized_matches = audit.normalized_matches + 1
    end
  end

  -- 3) loose name/vendor contains match (last resort)
  if not item then
    local n=name:lower(); local v=vendor:lower()
    if #n>=6 then
      for k,idOut in pairs(installed_fx) do
        if k:find(n,1,true) and (v=="" or k:find(v,1,true)) then item=idOut; break end
      end
    end
  end

  if not item then
    audit.master_unmatched = audit.master_unmatched + 1
  else
    audit.master_matched = audit.master_matched + 1
    item = sanitize_ini(item)
    local fxType = fx_type_from_ident(item)
    local fmt = infer_fmt(item, name)
    local rank = fmt_rank[fmt] or 99
    local gk = canonical_key(name, item)

    local isPref = false
    if preferred_by_ident and preferred_by_ident[item:lower()] then isPref = true end
    if preferred_by_group and preferred_by_group[gk] and preferred_by_group[gk]:lower()==item:lower() then isPref = true end

    if splitFmt then
      local leaf = (fmt=="vst3" and "VST3") or (fmt=="clap" and "CLAP") or (fmt=="vst" and "VST2") or fmt:upper()
      local finalFolder = baseFolder .. " ▸ " .. leaf
      ensure_folder(finalFolder)
      consider(finalFolder, gk.."::"..fmt, item, fxType, rank, true, true)
    else
      ensure_folder(baseFolder)
      local canFallback = not (useScanner and hardPreferred)
      consider(baseFolder, gk, item, fxType, rank, isPref, canFallback)
    end

    -- ensure parents exist
    local p={"IFLS"}
    for idx=1,#parts do
      p[#p+1]=parts[idx]
      ensure_folder(join_path(p))
    end
  end
end

-- materialize folders
table.sort(folder_order)
local new_folders={}
for _,fname in ipairs(folder_order) do
  local items={}
  local gm = folder_choice[fname]
  if gm then
    local idents={}
    for _,v in pairs(gm) do idents[#idents+1]=v.ident end
    table.sort(idents)
    local seen={}
    for _,ident in ipairs(idents) do
      if not seen[ident] then
        seen[ident]=true
        local ty=3
        for _,v in pairs(gm) do if v.ident==ident then ty=v.type; break end end
        items[#items+1]={type=ty,item=ident}
      end
    end
  end
  new_folders[#new_folders+1] = {name=sanitize_ini(fname), items=items}
end

local res=r.GetResourcePath()
local gen_path=res.."/reaper-fxfolders.IFLS.generated.ini"
local main=res.."/reaper-fxfolders.ini"
local bak=main..".BACKUP_"..os.date("%Y%m%d_%H%M%S")

-- audit report
if doAudit then
  local ts=os.date("%Y%m%d_%H%M%S")
  local rep=res.."/IFLS_FX_FOLDER_AUDIT_"..ts..".txt"
  local lines={}
  lines[#lines+1]="IFLS FX Folder Audit v1.3.4"
  lines[#lines+1]="Timestamp: "..ts
  lines[#lines+1]=""
  lines[#lines+1]="Master CSV: "..tostring(audit.master_path)
  if audit.scan_path then lines[#lines+1]="Scanner CSV: "..tostring(audit.scan_path) end
  lines[#lines+1]=""
  lines[#lines+1]=("Master rows processed: %d"):format(audit.master_rows)
  lines[#lines+1]=("Matched to installed FX: %d"):format(audit.master_matched)
  lines[#lines+1]=("Unmatched master rows: %d"):format(audit.master_rows - audit.master_matched)
  lines[#lines+1]=("Normalized matches used: %d"):format(audit.normalized_matches)
  lines[#lines+1]=""
  if useScanner and scanner_audit then
    lines[#lines+1]=("Scanner groups total: %d"):format(scanner_audit.total_groups or 0)
    lines[#lines+1]=("Groups with preferred row: %d"):format(scanner_audit.groups_with_preferred or 0)
    lines[#lines+1]=("Groups missing preferred row: %d"):format(audit.groups_missing_preferred)
    lines[#lines+1]=("Groups with multiple preferred rows: %d"):format(audit.groups_multiple_preferred)
    lines[#lines+1]=("Preferred idents not installed: %d"):format(audit.preferred_not_installed)
    lines[#lines+1]=""
    lines[#lines+1]="Hard-Preferred mode: "..tostring(hardPreferred)
  else
    lines[#lines+1]="Scanner CSV not used (or not loaded)."
  end
  lines[#lines+1]=""
  lines[#lines+1]="Ident normalization enabled: "..tostring(enableNorm)
  write_all(rep, table.concat(lines, "\r\n").."\r\n")
  r.ShowConsoleMsg("Audit report written: "..rep.."\n")
end

if not mergeMode then
  write_all(gen_path, build_fxfolders_ini(new_folders))
  r.MB("Generated:\n"..gen_path.."\n\nImport via Preferences > Plug-ins > FX folders.","IFLS v1.3.4",0)
  return
end

local old_txt = read_all(main) or ""
local old_folders = parse_fxfolders_ini(old_txt)
local kept={}
for _,f in ipairs(old_folders) do
  if not (f.name or ""):match("^IFLS") then kept[#kept+1]=f end
end
for _,f in ipairs(new_folders) do kept[#kept+1]=f end

if old_txt ~= "" then write_all(bak, old_txt) end
write_all(main, build_fxfolders_ini(kept))
r.MB("MERGED into:\n"..main.."\nBackup:\n"..bak.."\nRestart REAPER recommended.","IFLS v1.3.4",0)
