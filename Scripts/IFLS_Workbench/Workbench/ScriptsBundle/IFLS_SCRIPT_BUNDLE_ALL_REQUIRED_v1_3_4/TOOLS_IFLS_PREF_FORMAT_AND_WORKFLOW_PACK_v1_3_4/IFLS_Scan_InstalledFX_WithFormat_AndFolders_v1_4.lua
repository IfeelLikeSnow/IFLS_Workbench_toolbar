-- @description IFLS Workbench - Workbench/ScriptsBundle/IFLS_SCRIPT_BUNDLE_ALL_REQUIRED_v1_3_4/TOOLS_IFLS_PREF_FORMAT_AND_WORKFLOW_PACK_v1_3_4/IFLS_Scan_InstalledFX_WithFormat_AndFolders_v1_4.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

--[[
IFLS Installed FX Scanner v1.4
==============================
Adds:
- infer_format() also detects file paths (.vst3/.clap/.dll/.component) reliably
- optional ident normalization output:
    ident_norm = VST3/CLAP package-root (e.g. ...\Plugin.vst3) if EnumInstalledFX returns Contents/binary path
  (raw ident stays untouched in 'ident' column = "truth")

Exports:
group_name,group_key,format,preferred,preferred_reason,group_size,rank_index,ident,ident_norm,folders

Preferred order: VST3 > CLAP > VST2 > AU > JSFX > DX > AAX > unknown

References:
- EnumInstalledFX: https://www.reaper.fm/sdk/reascript/reascripthelp.html
- reaper-fxfolders.ini: https://mespotin.uber.space/Ultraschall/Reaper-Filetype-Descriptions.html

License: CC0 / Public Domain
--]]

local r = reaper

local function trim(s) return (s or ""):gsub("^%s+",""):gsub("%s+$","") end
local function esc_csv(s)
  s = tostring(s or "")
  if s:find('[,"\r\n]') then s = '"' .. s:gsub('"','""') .. '"' end
  return s
end
local function read_all(p) local f=io.open(p,"rb"); if not f then return nil end local c=f:read("*all"); f:close(); return c end
local function write_all(p,c) local f=io.open(p,"wb"); if not f then return false end f:write(c); f:close(); return true end

-- normalize ident to package-root for VST3/CLAP (optional)
local function normalize_ident(ident)
  local s = tostring(ident or "")
  local low = s:lower()
  local p = low:find("%.vst3", 1, false)
  if p then return s:sub(1, p+4) end -- include ".vst3"
  p = low:find("%.clap", 1, false)
  if p then return s:sub(1, p+4) end -- include ".clap"
  return s
end

local function infer_format(group_name, ident)
  local g = (group_name or ""):lower()
  if g:find("^vst3i:") then return "vst3i" end
  if g:find("^vsti:") then return "vsti" end
  if g:find("^vst3:") then return "vst3" end
  if g:find("^vst:") then return "vst" end
  if g:find("^clapi:") then return "clapi" end
  if g:find("^clap:") then return "clap" end
  if g:find("^au:") then return "au" end
  if g:find("^js:") then return "jsfx" end
  if g:find("^dx:") then return "dx" end
  if g:find("^aax:") then return "aax" end

  local low = tostring(ident or ""):lower()
  if low:find(".vst3", 1, true) then return "vst3" end
  if low:find(".clap", 1, true) then return "clap" end
  if low:match("%.dll$") then return "vst" end
  if low:match("%.component$") then return "au" end
  return "unknown"
end

local fmt_rank = {vst3=1, vst3i=1, clap=2, clapi=2, vst=3, au=4, jsfx=5, dx=6, aax=7, unknown=99}

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

local function parse_fxfolders(resource_path)
  local path=resource_path.."/reaper-fxfolders.ini"
  local txt=read_all(path)
  if not txt then return {}, path, false end

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

  local fx_to_folders={}
  section=nil; local cur=nil
  for line in txt:gmatch("[^\r\n]+") do
    local fid=line:match("^%[Folder(%d+)%]$")
    if fid then section="Folder"; cur=tonumber(fid)
    else
      if section=="Folder" and cur~=nil then
        local item=line:match("^Item%d+%=(.*)$")
        if item and item~="" then
          local folderName=name_by_id[cur] or ("Folder"..tostring(cur))
          local key=item:lower()
          fx_to_folders[key]=fx_to_folders[key] or {}
          fx_to_folders[key][folderName]=true
        end
      end
    end
  end

  local out={}
  for k,set in pairs(fx_to_folders) do
    local arr={}; for fn,_ in pairs(set) do arr[#arr+1]=fn end; table.sort(arr)
    out[k]=arr
  end
  return out, path, true
end

r.ClearConsole()
if r.APIExists and not r.APIExists("EnumInstalledFX") then
  r.MB("EnumInstalledFX not available. Update REAPER.","IFLS Scan",0); return
end

local add_norm = (r.MB("Add ident_norm column (VST3/CLAP package-root)?\n\nYES = add column\nNO = skip", "IFLS Scan v1.4", 4) == 6)

local res=r.GetResourcePath()
local folder_map, fxfolders_path = parse_fxfolders(res)

-- enumerate installed FX
local fx_list={}
local i=0
while true do
  local ok,nameOut,identOut=r.EnumInstalledFX(i)
  if not ok then break end
  if identOut and identOut~="" then
    local fmt=infer_format(nameOut or "", identOut)
    fx_list[#fx_list+1]={name=nameOut or "", ident=identOut, fmt=fmt}
  end
  i=i+1
end

-- group
local groups, order = {}, {}
for _,fx in ipairs(fx_list) do
  local ck=canonical_key(fx.name, fx.ident)
  if not groups[ck] then
    groups[ck]={entries={}, display=(fx.name~="" and fx.name or ck), key=ck}
    order[#order+1]=ck
  end
  groups[ck].entries[#groups[ck].entries+1]=fx
end
table.sort(order, function(a,b) return groups[a].display:lower() < groups[b].display:lower() end)

-- sort entries and mark preferred + rank_index + group_size
for _,k in ipairs(order) do
  table.sort(groups[k].entries, function(x,y)
    local rx,ry=fmt_rank[x.fmt] or 99, fmt_rank[y.fmt] or 99
    if rx~=ry then return rx<ry end
    return x.ident:lower() < y.ident:lower()
  end)
  local gsize = #groups[k].entries
  for idx,fx in ipairs(groups[k].entries) do
    fx.rank_index = tostring(idx)
    fx.group_size = tostring(gsize)
    fx.preferred = (idx==1) and "true" or "false"
    fx.preferred_reason = "rank:vst3>clap>vst2>au>jsfx>dx>aax>unknown"
    fx.ident_norm = add_norm and normalize_ident(fx.ident) or ""
  end
end

-- output
local out={}
out[#out+1]="group_name,group_key,format,preferred,preferred_reason,group_size,rank_index,ident,ident_norm,folders"
for _,k in ipairs(order) do
  local g=groups[k]
  for _,fx in ipairs(g.entries) do
    local folders=folder_map[fx.ident:lower()]
    local folderStr=""
    if folders and #folders>0 then folderStr=table.concat(folders," | ") end
    out[#out+1]=table.concat({
      esc_csv(g.display),
      esc_csv(g.key),
      esc_csv(fx.fmt),
      esc_csv(fx.preferred),
      esc_csv(fx.preferred_reason),
      esc_csv(fx.group_size),
      esc_csv(fx.rank_index),
      esc_csv(fx.ident),
      esc_csv(fx.ident_norm),
      esc_csv(folderStr)
    }, ",")
  end
end

local ts=os.date("%Y%m%d_%H%M%S")
local out_path=res.."/IFLS_INSTALLED_FX_WITH_FORMAT_FOLDERS_PREFERRED_"..ts..".csv"
write_all(out_path, table.concat(out,"\r\n").."\r\n")

r.MB("Export done:\n"..out_path.."\n\nFX folders file read:\n"..fxfolders_path, "IFLS Scan v1.4", 0)
