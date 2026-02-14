-- @description IFLS PSS-580 - Library Browser (PSS-x80 .syx)
-- @version 1.01.0
-- @author IFLS
local r=reaper
local ctx = r.ImGui_CreateContext('IFLS PSS-x80 Library Browser')
local root = r.GetResourcePath().."/Scripts/IFLS_Workbench"
local Syx = dofile(root.."/Workbench/PSS580/Core/ifls_pss580_sysex.lua")

local function file_exists(p) local f=io.open(p,"rb"); if f then f:close(); return true end return false end
local function read_all(p) local f=io.open(p,"rb"); if not f then return nil end local d=f:read("*all"); f:close(); return d end

local function list_dir_syx(dir)
  local out={}
  local cmd
  if r.GetOS():match("Win") then
    cmd = 'dir /b "'..dir..'\\*.syx" 2>nul'
  else
    cmd = 'find "'..dir..'" -maxdepth 1 -type f \( -iname "*.syx" -o -iname "*.SYX" \ ) 2>/dev/null'
  end
  local p=io.popen(cmd); if not p then return out end
  local s=p:read("*all") or ""; p:close()
  for line in s:gmatch("[^\r\n]+") do
    local name=line:match("[^/\\]+$") or line
    local full = line
    if not line:match("^/") and not line:match(":%\") then
      full = dir.."/"..name
    end
    out[#out+1]={name=name, full=full}
  end
  table.sort(out, function(a,b) return a.name:lower() < b.name:lower() end)
  return out
end

local lib_root = root.."/Workbench/PSS580/library/alfonse_pss780"
local items = list_dir_syx(lib_root)
local filter = ""
local selected = 1

local function load_index()
  local p = root.."/Workbench/PSS580/library/pss_library_index.json"
  local f=io.open(p,"rb"); if not f then return {items={}} end
  local s=f:read("*all") or ""; f:close()
  local ok, t = pcall(function() return reaper.JSON_Parse(s) end)
  if ok and t and t.items then return t end
  return {items={}}
end

local index = load_index()
local fav_only = false
local type_filter = ""

local function send_blob(blob)
  if not r.SNM_SendSysEx then r.MB("SWS not found.", "PSS", 0); return end
  r.SNM_SendSysEx(blob)
end

local function send_file(path)
  local blob = read_all(path)
  if not blob then return end
  -- if file contains multiple messages, send all concatenated
  send_blob(blob)
end

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 860, 560, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, 'IFLS PSS-x80 Library Browser', true)
  if visible then
    r.ImGui_Text(ctx, "Library: "..lib_root)
    local changed, nf = r.ImGui_InputText(ctx, "Search", filter)
    if changed then filter = nf end
    local chf, fv = r.ImGui_Checkbox(ctx, "Favorites only", fav_only)
    if chf then fav_only = fv end
    local cht, tf = r.ImGui_InputText(ctx, "Type filter", type_filter)
    if cht then type_filter = tf end

    r.ImGui_Separator(ctx)
    r.ImGui_BeginChild(ctx, "list", 420, -1, true)
    local shown=0
    for i,it in ipairs(items) do
      local meta = (index.items and index.items[it.full]) or nil
      local is_fav = meta and meta.favorite or false
      local typ = meta and (meta.type or "") or ""
      local ok_filter = (filter=="" or it.name:lower():find(filter:lower(), 1, true))
      if fav_only then ok_filter = ok_filter and is_fav end
      if type_filter~="" then ok_filter = ok_filter and (typ:lower():find(type_filter:lower(),1,true)~=nil) end
      if ok_filter then
        shown=shown+1
        local label = it.name
        if meta then
          if meta.favorite then label = "★ "..label end
          if meta.type and meta.type~="" then label = label.." ["..meta.type.."]" end
        end
        if r.ImGui_Selectable(ctx, label, i==selected) then selected=i end
      end
    end
    if shown==0 then r.ImGui_Text(ctx, "(no matches)") end
    r.ImGui_EndChild(ctx)

    r.ImGui_SameLine(ctx)
    r.ImGui_BeginChild(ctx, "details", -1, -1, true)
    local it = items[selected]
    if it then
      r.ImGui_Text(ctx, it.name)
      r.ImGui_Text(ctx, it.full)
      r.ImGui_Separator(ctx)

      if r.ImGui_Button(ctx, "Open Voice Editor (Randomize/Locks)", -1, 0) then
        dofile(root.."/Workbench/PSS580/Tools/IFLS_PSS580_Voice_Editor.lua")
      end

      if r.ImGui_Button(ctx, "Analyze", -1, 0) then
        local blob=read_all(it.full)
        if blob then
          local msgs=Syx.split_sysex(blob)
          r.ShowConsoleMsg("=== PSS-x80 Analyze (from Browser) ===\n"..it.full.."\n")
          r.ShowConsoleMsg("Bytes: "..#blob.." messages="..#msgs.."\n")
          for mi,m in ipairs(msgs) do
            r.ShowConsoleMsg(string.format("#%d len=%d voice72=%s\n", mi, #m, tostring(Syx.is_pss_voice_dump(m))))
          end
        end
      end

      if r.ImGui_Button(ctx, "Tag/Favorite…", -1, 0) then
        dofile(root.."/Workbench/PSS580/Tools/IFLS_PSS580_Library_Tag_Favorite.lua")
        index = load_index()
      end

      if r.ImGui_Button(ctx, "Send to PSS (SysEx)", -1, 0) then
        if file_exists(it.full) then send_file(it.full) end
      end

      r.ImGui_Text(ctx, "Tip: use FB-01 style 'Safe Audition' approach for PSS too (see tool).")
      if r.ImGui_Button(ctx, "Safe Audition (manual backup -> audition -> revert)", -1, 0) then
        dofile(root.."/Workbench/PSS580/Tools/IFLS_PSS580_Safe_Audition_ManualBackup.lua")
      end
    end
    r.ImGui_EndChild(ctx)

    r.ImGui_End(ctx)
  end
  if open then r.defer(loop) else r.ImGui_DestroyContext(ctx) end
end
r.defer(loop)
