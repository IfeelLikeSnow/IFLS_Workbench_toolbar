-- @description IFLS Workbench - Doctor v2 (Install + Dependencies + Health Report)
-- @version 0.65.0
-- @author IfeelLikeSnow

-- Doctor v2: checks install path sanity, optional dependencies, and key data files.
-- Shows a GUI if ReaImGui is available, otherwise prints to console + messagebox.

local r = reaper

local function file_exists(path)
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local function dir_exists(path)
  -- best-effort: try opening a known file pattern isn't available in Lua, so use os rename trick
  local ok, err, code = os.rename(path, path)
  if ok then return true end
  if code == 13 then return true end -- permission denied but exists
  return false
end

local function get_resource_scripts()
  return r.GetResourcePath() .. "/Scripts"
end

local function get_expected_root()
  return get_resource_scripts() .. "/IFLS_Workbench"
end

local function detect_install()
  local scripts = get_resource_scripts()
  local expected = get_expected_root()
  local has_expected = dir_exists(expected)

  -- heuristic: if this script is run from expected location, we are "correct"
  local this_path = ({r.get_action_context()})[2] or ""
  local normalized = this_path:gsub("\\", "/")
  local from_expected = normalized:find("/Scripts/IFLS_Workbench/", 1, true) ~= nil

  -- heuristic: if index.xml sits next to IFLS_Workbench folder, user unzipped repo-root into Scripts
  local index_in_scripts = file_exists(scripts.."/index.xml") or file_exists(scripts.."/index-nightly.xml")

  local mode = "unknown"
  if from_expected and has_expected then
    mode = "OK: installed under Scripts/IFLS_Workbench"
  elseif has_expected then
    mode = "Present: Scripts/IFLS_Workbench exists, but this script was launched from: "..normalized
  else
    mode = "NOT FOUND: Scripts/IFLS_Workbench missing"
  end

  return {
    scripts = scripts,
    expected = expected,
    has_expected = has_expected,
    from_expected = from_expected,
    index_in_scripts = index_in_scripts,
    this_path = normalized,
    mode = mode
  }
end

local function detect_deps()
  local deps = {}

  -- SWS
  deps.sws = {
    ok = (r.SNM_SendSysEx ~= nil) or (r.CF_GetSWSVersion ~= nil),
    detail = (r.CF_GetSWSVersion and ("SWS version: "..tostring(r.CF_GetSWSVersion()))) or (r.SNM_SendSysEx and "SWS API detected (SNM_SendSysEx)") or "not detected"
  }

  -- ReaImGui
  deps.imgui = {
    ok = (r.ImGui_CreateContext ~= nil),
    detail = (r.ImGui_CreateContext and "ReaImGui detected") or "not detected"
  }

  -- JS_ReaScriptAPI (common entry points)
  local js_ok = (r.JS_Dialog_BrowseForOpenFiles ~= nil) or (r.JS_Dialog_BrowseForSaveFile ~= nil) or (r.JS_Window_Find ~= nil)
  deps.js = {
    ok = js_ok,
    detail = js_ok and "JS_ReaScriptAPI detected" or "not detected"
  }

  -- ReaPack (no official API in ReaScript; heuristic only)
  deps.reapack = {
    ok = file_exists(r.GetResourcePath().."/UserPlugins/reapack.dll") or file_exists(r.GetResourcePath().."/UserPlugins/reapack64.dll"),
    detail = "heuristic: checks reapack dll in UserPlugins (may be false-negative on macOS/Linux)"
  }

  return deps
end

local function detect_key_files(install)
  local root = install.expected
  local out = {}
  out.bootstrap = file_exists(root.."/_bootstrap.lua")
  out.safeapply = file_exists(root.."/Engine/IFLS_SafeApply.lua") or file_exists(root.."/Engine/IFLS_SafeApply.lua")
  out.schemas = dir_exists(root.."/Docs/schemas")
  out.gear_manifest = file_exists(root.."/Workbench/PSS580/Patches/manifest.json") or file_exists(root.."/Workbench/FB01/PatchLibrary/manifest.json")
  out.full_pkg = file_exists(root.."/_packages/IFLS_Workbench_FULL.lua")
  return out
end

local function fmt_bool(b) return b and "OK" or "MISSING" end

local function build_report()
  local install = detect_install()
  local deps = detect_deps()
  local files = detect_key_files(install)

  local lines = {}
  lines[#lines+1] = "IFLS Workbench Doctor v2"
  lines[#lines+1] = "Time: "..os.date("!%Y-%m-%dT%H:%M:%SZ")
  lines[#lines+1] = ""
  lines[#lines+1] = "Install:"
  lines[#lines+1] = "  "..install.mode
  lines[#lines+1] = "  expected: "..install.expected
  lines[#lines+1] = "  this script: "..(install.this_path ~= "" and install.this_path or "(unknown)")
  lines[#lines+1] = "  repo index files in Scripts/: "..(install.index_in_scripts and "YES (you likely unzipped repo-root into Scripts/)" or "no/unknown")
  lines[#lines+1] = ""
  lines[#lines+1] = "Dependencies:"
  lines[#lines+1] = "  SWS: "..(deps.sws.ok and "OK" or "MISSING").."  ("..deps.sws.detail..")"
  lines[#lines+1] = "  ReaImGui: "..(deps.imgui.ok and "OK" or "MISSING").."  ("..deps.imgui.detail..")"
  lines[#lines+1] = "  JS_ReaScriptAPI: "..(deps.js.ok and "OK" or "MISSING").."  ("..deps.js.detail..")"
  lines[#lines+1] = "  ReaPack: "..(deps.reapack.ok and "OK" or "UNKNOWN").."  ("..deps.reapack.detail..")"
  lines[#lines+1] = ""
  lines[#lines+1] = "Key files:"
  lines[#lines+1] = "  _bootstrap.lua: "..fmt_bool(files.bootstrap)
  lines[#lines+1] = "  SafeApply: "..fmt_bool(files.safeapply)
  lines[#lines+1] = "  Docs/schemas: "..fmt_bool(files.schemas)
  lines[#lines+1] = "  Manifests present: "..fmt_bool(files.gear_manifest)
  lines[#lines+1] = "  ReaPack FULL package descriptor: "..fmt_bool(files.full_pkg)
  lines[#lines+1] = ""
  lines[#lines+1] = "Notes:"
  lines[#lines+1] = "  - If SWS is missing, SysEx tools and some advanced APIs won't work."
  lines[#lines+1] = "  - If ReaImGui is missing, GUI browsers/wizards won't open (scripts may still work headless)."
  lines[#lines+1] = "  - If JS_ReaScriptAPI is missing, file dialogs may fall back to defaults."
  lines[#lines+1] = "  - Recommended install path: REAPER/ResourcePath/Scripts/IFLS_Workbench/"

  return table.concat(lines, "\n"), install, deps, files
end

local report, install, deps, files = build_report()

-- Print to console
r.ClearConsole()
r.ShowConsoleMsg(report.."\n")

-- GUI if possible
if r.ImGui_CreateContext then
  local ctx = r.ImGui_CreateContext("IFLS Workbench Doctor v2")
  local open = true
  local function loop()
    r.ImGui_SetNextWindowSize(ctx, 840, 520, r.ImGui_Cond_FirstUseEver())
    local visible
    visible, open = r.ImGui_Begin(ctx, "IFLS Workbench Doctor v2", open)
    if visible then
      r.ImGui_TextWrapped(ctx, "This tool checks install path, optional dependencies, and key files. It also prints a full report to REAPER's console.")
      r.ImGui_Separator(ctx)

      r.ImGui_SeparatorText(ctx, "Install")
      r.ImGui_TextWrapped(ctx, install.mode)
      r.ImGui_Text(ctx, "Expected: "..install.expected)
      r.ImGui_TextWrapped(ctx, "This script: "..(install.this_path ~= "" and install.this_path or "(unknown)"))
      if install.index_in_scripts then
        r.ImGui_TextWrapped(ctx, "NOTE: index.xml found in Scripts/. If you installed via ZIP, consider moving index.xml out of Scripts/ (optional).")
      end

      r.ImGui_SeparatorText(ctx, "Dependencies")
      local function dep_line(name, ok, detail)
        r.ImGui_Text(ctx, (ok and "OK " or "MISSING ")..name)
        r.ImGui_SameLine(ctx)
        r.ImGui_TextWrapped(ctx, " - "..detail)
      end
      dep_line("SWS", deps.sws.ok, deps.sws.detail)
      dep_line("ReaImGui", deps.imgui.ok, deps.imgui.detail)
      dep_line("JS_ReaScriptAPI", deps.js.ok, deps.js.detail)
      dep_line("ReaPack", deps.reapack.ok, deps.reapack.detail)

      r.ImGui_SeparatorText(ctx, "Key files")
      local function fline(label, ok)
        r.ImGui_Text(ctx, (ok and "OK " or "MISSING ")..label)
      end
      fline("_bootstrap.lua", files.bootstrap)
      fline("SafeApply", files.safeapply)
      fline("Docs/schemas", files.schemas)
      fline("Manifests present", files.gear_manifest)
      fline("ReaPack FULL package descriptor", files.full_pkg)

      r.ImGui_Separator(ctx)
      if r.ImGui_Button(ctx, "Copy report to clipboard") then
        if r.ImGui_SetClipboardText then r.ImGui_SetClipboardText(ctx, report) end
      end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "Open console") then
        r.ShowConsoleMsg("")
      end
      r.ImGui_SameLine(ctx)
      if r.ImGui_Button(ctx, "Close") then open = false end

      r.ImGui_End(ctx)
    end

    if open then
      r.defer(loop)
    else
      r.ImGui_DestroyContext(ctx)
    end
  end
  r.defer(loop)
else
  r.MB("Doctor report written to console.\n\nOpen View -> Console to read it.", "IFLS Workbench Doctor v2", 0)
end
