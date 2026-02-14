-- @description IFLS PSS-580 - Bank Import/Export (5-voice .syx bank) + Batch Split/Merge
-- @version 1.04.0
-- @author IFLS
-- @about
--   PSS-x80 bank workflow compatible with classic editors:
--    - Export bank: merge 5 voice .syx (72-byte) into one multi-message bank .syx
--    - Import bank: split multi-message bank .syx into 5 voice files
--   Also supports batch folder split/merge.

local r=reaper
local root = r.GetResourcePath().."/Scripts/IFLS_Workbench"
local Syx = dofile(root.."/Workbench/PSS580/Core/ifls_pss580_sysex.lua")

local function read_all(p)
  local f=io.open(p,"rb"); if not f then return nil end
  local d=f:read("*all"); f:close(); return d
end
local function write_all(p, d)
  local f=io.open(p,"wb"); if not f then return false end
  f:write(d); f:close(); return true
end

local function pick_files_5()
  local files={}
  for i=1,5 do
    local ok, path = r.GetUserFileNameForRead("", ("Select voice %d/5 (.syx)"):format(i), ".syx")
    if not ok or path=="" then return nil end
    files[i]=path
  end
  return files
end

local function merge_5(files, outpath)
  local parts={}
  for i=1,5 do
    local blob=read_all(files[i]); if not blob then return false, "cannot read "..files[i] end
    local msgs=Syx.split_sysex(blob)
    local m=nil
    for _,mm in ipairs(msgs) do if Syx.is_pss_voice_dump(mm) then m=mm; break end end
    if not m then return false, "no voice dump found in "..files[i] end
    parts[#parts+1]=m
  end
  return write_all(outpath, table.concat(parts,""))
end

local function split_bank(inpath, outdir, prefix)
  local blob=read_all(inpath); if not blob then return false, "cannot read bank" end
  local msgs=Syx.split_sysex(blob)
  local voices={}
  for _,m in ipairs(msgs) do
    if Syx.is_pss_voice_dump(m) then voices[#voices+1]=m end
  end
  if #voices==0 then return false, "no 72-byte voice dumps found" end
  if #voices<5 then
    -- still split whatever we found
  end
  prefix = prefix or "PSS_BANK"
  for i,m in ipairs(voices) do
    local out = outdir.."/"..prefix..("_%02d.syx"):format(i)
    write_all(out, m)
  end
  return true, ("split %d voices"):format(#voices)
end

local function ensure_dir(p)
  if r.GetOS():match("Win") then
    os.execute('mkdir "'..p..'" >nul 2>nul')
  else
    os.execute('mkdir -p "'..p..'" >/dev/null 2>&1')
  end
end

local function pick_folder(title)
  local ok, path = r.JS_Dialog_BrowseForFolder and r.JS_Dialog_BrowseForFolder(title, "") or (false, "")
  if ok and path and path~="" then return path end
  -- fallback: user types
  local ok2, txt = r.GetUserInputs(title, 1, "Folder path", "")
  if ok2 and txt~="" then return txt end
  return nil
end

local ok, mode = r.GetUserInputs("PSS Bank Import/Export", 1,
  "Mode (export5|import_bank|batch_split_folder)", "export5")
if not ok then return end
mode = (mode or ""):lower()

if mode=="export5" then
  local files = pick_files_5(); if not files then return end
  local ok2, outpath = r.GetUserFileNameForWrite("", "Save bank .syx (multi-message)", ".syx")
  if not ok2 or outpath=="" then return end
  local okm, err = merge_5(files, outpath)
  if not okm then r.MB("Failed: "..tostring(err), "PSS Bank", 0) else r.MB("Saved bank:\n"..outpath, "PSS Bank", 0) end
  return
end

if mode=="import_bank" then
  local ok2, inpath = r.GetUserFileNameForRead("", "Select bank .syx (multi-message)", ".syx")
  if not ok2 or inpath=="" then return end
  local outdir = pick_folder("Select output folder for split voices")
  if not outdir then return end
  ensure_dir(outdir)
  local okm, msg = split_bank(inpath, outdir, "PSS_VOICE")
  r.MB((okm and "OK: " or "Failed: ")..tostring(msg), "PSS Bank", 0)
  return
end

if mode=="batch_split_folder" then
  local indir = pick_folder("Select folder containing .syx banks")
  if not indir then return end
  local outdir = pick_folder("Select output folder for extracted voices")
  if not outdir then return end
  ensure_dir(outdir)
  -- list .syx
  local cmd
  if r.GetOS():match("Win") then cmd='dir /b "'..indir..'\\*.syx" 2>nul'
  else cmd='find "'..indir..'" -maxdepth 1 -type f \( -iname "*.syx" -o -iname "*.SYX" \ ) 2>/dev/null' end
  local p=io.popen(cmd); if not p then return end
  local s=p:read("*all") or ""; p:close()
  local n=0; local okc=0
  for line in s:gmatch("[^\r\n]+") do
    local name=line:match("[^/\\]+$") or line
    local full=line
    if not line:match("^/") and not line:match(":%\") then full = indir.."/"..name end
    local prefix = name:gsub("%.[Ss][Yy][Xx]$","")
    local okm = split_bank(full, outdir, prefix)
    n=n+1; if okm then okc=okc+1 end
  end
  r.MB(("Done. Processed %d files. Split OK: %d"):format(n,okc), "PSS Bank", 0)
  return
end

r.MB("Unknown mode. Use export5|import_bank|batch_split_folder", "PSS Bank", 0)
