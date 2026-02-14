-- @description IFLS Workbench - Capability Matrix Viewer (V66)
-- @version 0.66.0
-- @author IfeelLikeSnow

local r = reaper

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local d = f:read("*all"); f:close()
  return d
end

local function wb_root()
  return r.GetResourcePath().."/Scripts/IFLS_Workbench"
end

local csv_path = wb_root().."/Docs/V66_Capability_Matrix/scripts_capabilities.csv"

if not file_exists(csv_path) then
  r.MB("Missing report file:\n"..csv_path.."\n\nInstall V66 docs or regenerate the report.", "IFLS Capability Matrix", 0)
  return
end

local csv = read_file(csv_path) or ""

if not r.ImGui_CreateContext then
  r.ClearConsole()
  r.ShowConsoleMsg("IFLS Workbench Capability Matrix (CSV)\n"..csv_path.."\n\n"..csv.."\n")
  r.MB("ReaImGui not installed. Printed CSV to console.", "IFLS Capability Matrix", 0)
  return
end

local ctx = r.ImGui_CreateContext("IFLS Capability Matrix (V66)")
local search = ""
local lines = {}
for line in csv:gmatch("[^\r\n]+") do lines[#lines+1] = line end
local rows = {}
for i=2,#lines do rows[#rows+1]=lines[i] end

local function split_csv_line(line)
  local out, cur, inq = {}, "", false
  for i=1,#line do
    local ch = line:sub(i,i)
    if ch == '"' then
      inq = not inq
    elseif ch == ',' and not inq then
      out[#out+1]=cur; cur=""
    else
      cur=cur..ch
    end
  end
  out[#out+1]=cur
  return out
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 920, 560, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS Workbench Capability Matrix (V66)", true)
  if visible then
    r.ImGui_TextWrapped(ctx, "Search scripts/capabilities. Source: Docs/V66_Capability_Matrix/scripts_capabilities.csv")
    local ch, s2 = r.ImGui_InputText(ctx, "Search", search)
    if ch then search = s2 end
    r.ImGui_Separator(ctx)

    if r.ImGui_BeginTable(ctx, "cap_tbl", 2, r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_RowBg() | r.ImGui_TableFlags_Resizable()) then
      r.ImGui_TableSetupColumn(ctx, "Script", r.ImGui_TableColumnFlags_WidthStretch())
      r.ImGui_TableSetupColumn(ctx, "Capabilities", r.ImGui_TableColumnFlags_WidthStretch())
      r.ImGui_TableHeadersRow(ctx)

      local q = search:lower()
      for _,line in ipairs(rows) do
        local cols = split_csv_line(line)
        local script = cols[1] or ""
        local caps = cols[2] or ""
        if q == "" or script:lower():find(q,1,true) or caps:lower():find(q,1,true) then
          r.ImGui_TableNextRow(ctx)
          r.ImGui_TableSetColumnIndex(ctx, 0); r.ImGui_Text(ctx, script)
          r.ImGui_TableSetColumnIndex(ctx, 1); r.ImGui_Text(ctx, caps)
        end
      end
      r.ImGui_EndTable(ctx)
    end
    r.ImGui_End(ctx)
  end
  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end

r.defer(loop)
