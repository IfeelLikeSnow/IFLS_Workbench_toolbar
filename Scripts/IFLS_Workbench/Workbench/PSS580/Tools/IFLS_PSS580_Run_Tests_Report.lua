-- @description IFLS PSS-580 - Run Tests + Deterministic Report (checksum, roundtrip)
-- @version 1.04.0
-- @author IFLS
local r=reaper
local root = r.GetResourcePath().."/Scripts/IFLS_Workbench"
local Syx = dofile(root.."/Workbench/PSS580/Core/ifls_pss580_sysex.lua")
local report_dir = root.."/Docs/Reports"
local report_json = report_dir.."/PSS580_TestReport.json"
local report_md = report_dir.."/PSS580_TestReport.md"

local function ensure_dir(p)
  if r.GetOS():match("Win") then os.execute('mkdir "'..p..'" >nul 2>nul')
  else os.execute('mkdir -p "'..p..'" >/dev/null 2>&1') end
end
ensure_dir(report_dir)

local function read_all(p) local f=io.open(p,"rb"); if not f then return nil end local d=f:read("*all"); f:close(); return d end
local function write_all(p,d) local f=io.open(p,"wb"); if not f then return false end f:write(d); f:close(); return true end

local function list_syx(dir)
  local out={}
  local cmd
  if r.GetOS():match("Win") then cmd='dir /b "'..dir..'\\*.syx" 2>nul'
  else cmd='find "'..dir..'" -type f \( -iname "*.syx" -o -iname "*.SYX" \ ) 2>/dev/null' end
  local p=io.popen(cmd); if not p then return out end
  local s=p:read("*all") or ""; p:close()
  for line in s:gmatch("[^\r\n]+") do
    local name=line:match("[^/\\]+$") or line
    local full=line
    if not line:match("^/") and not line:match(":%\") then full = dir.."/"..name end
    out[#out+1]=full
  end
  table.sort(out)
  return out
end

local ok, dir = r.GetUserInputs("PSS Tests", 1, "Library folder (default=alfonse)", root.."/Workbench/PSS580/library/alfonse_pss780")
if not ok then return end
dir = dir:gsub("\\","/")

local files = list_syx(dir)
local results={}
local pass=0; local fail=0

for _,path in ipairs(files) do
  local blob=read_all(path) or ""
  local msgs=Syx.split_sysex(blob)
  local m=nil
  for _,mm in ipairs(msgs) do if Syx.is_pss_voice_dump(mm) then m=mm; break end end
  if not m then
    results[#results+1]={file=path, ok=false, reason="no_voice_dump"}
    fail=fail+1
  else
    local vmem, cs = Syx.unpack_vmem_from_voice_dump(m)
    local cs2 = Syx.checksum_vmem(vmem)
    local chk_ok = (cs==cs2)
    local vced = Syx.vmem_to_vced(vmem)
    local vmem2 = Syx.vced_to_vmem(vced)
    local same=true
    for i=1,33 do if (vmem2[i] or 0) ~= (vmem[i] or 0) then same=false; break end end
    local okall = chk_ok and same
    results[#results+1]={file=path, ok=okall, checksum_ok=chk_ok, roundtrip_ok=same, len=#m}
    if okall then pass=pass+1 else fail=fail+1 end
  end
end

local report={generated=os.date("!%Y-%m-%dT%H:%M:%SZ"), folder=dir, pass=pass, fail=fail, total=#results, results=results}
-- JSON stringify if available
local json_s
if r.JSON_Stringify then json_s = r.JSON_Stringify(report) else
  json_s = "{"..'"generated":"'..report.generated..'","folder":"'..report.folder..'","pass":'..pass..',"fail":'..fail..',"total":'..#results..'}'
end
write_all(report_json, json_s)

-- Markdown
local md={"# PSS580 Test Report","",("Generated: %s"):format(report.generated),("Folder: `%s`"):format(dir),"",("Pass: **%d**  Fail: **%d**  Total: **%d**"):format(pass,fail,#results),"", "## Failures"}
for _,it in ipairs(results) do
  if not it.ok then
    md[#md+1]=("- `%s`  checksum_ok=%s roundtrip_ok=%s reason=%s"):format(it.file, tostring(it.checksum_ok), tostring(it.roundtrip_ok), tostring(it.reason))
  end
end
if fail==0 then md[#md+1]="(none)" end
write_all(report_md, table.concat(md,"\n"))

r.MB(("Done. Pass %d / %d.\nReports written to:\n%s\n%s"):format(pass,#results,report_json,report_md), "PSS Tests", 0)
