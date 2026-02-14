-- @description IFLS Workbench - Workbench/ScriptsBundle/IFLS_SCRIPT_BUNDLE_ALL_REQUIRED_v1_3_4/TOOLS_IFLS_PREF_FORMAT_AND_WORKFLOW_PACK_v1_3_4/IFLS_Create_FXChains_And_TrackTemplates_v1_0.lua
-- @version 0.63.0
-- @author IfeelLikeSnow

--[[
IFLS: Create FX Chains + Track Templates (starter pack) v1.0
===========================================================
Creates a few practical starter chains/templates using ONLY plugins that exist on the system.
The script attempts to add each FX by name; if not found, it skips it.

Outputs (in REAPER resource path):
- FXChains/IFLS/*.RfxChain
- TrackTemplates/IFLS/*.RTrackTemplate

Why generated (not shipped as static files):
- REAPER writes correct chunk syntax for your platform/build.
- Avoids brittle hand-written RfxChain formats.

References:
- TrackFX_AddByName, GetTrackStateChunk: REAPER API docs / ReaScript help
  https://www.reaper.fm/sdk/reascript/reascripthelp.html

License: CC0 / Public Domain
--]]

local r = reaper

local function mkdir_p(path)
  -- create nested folders best-effort
  local sep = package.config:sub(1,1)
  local p=""
  for part in path:gmatch("[^"..sep.."]+") do
    p = (p=="" and part) or (p..sep..part)
    os.execute((sep=="\\" and ('mkdir "'..p..'" 2>nul') or ('mkdir -p "'..p..'"')))
  end
end

local function write_all(p,c)
  local f=io.open(p,"wb"); if not f then return false end
  f:write(c); f:close(); return true
end

local function add_fx_by_name(track, fxname)
  -- instantiate=-1 always create new if found
  local idx = r.TrackFX_AddByName(track, fxname, false, -1)
  return idx >= 0
end

local function extract_fxchain_chunk(track_chunk)
  -- extract the <FXCHAIN ...> ... > block (first one)
  local start = track_chunk:find("<FXCHAIN", 1, true)
  if not start then return nil end
  -- Find matching end: a line with just ">" that closes FXCHAIN.
  -- We'll scan from start and count nested "<" blocks is complex; use heuristic:
  -- find "\n>\n" after start that likely closes FXCHAIN (first closing after its body).
  local sub = track_chunk:sub(start)
  local close_pos = sub:find("\n>\n", 1, true)
  if not close_pos then close_pos = sub:find("\r\n>\r\n", 1, true) end
  if not close_pos then return nil end
  return sub:sub(1, close_pos+2) -- include closing > and newline
end

local function extract_track_chunk(track_chunk)
  -- track template is essentially the <TRACK ...> ... > block
  local start = track_chunk:find("<TRACK", 1, true)
  if not start then return nil end
  local sub = track_chunk:sub(start)
  local close_pos = sub:find("\n>\n", 1, true)
  if not close_pos then close_pos = sub:find("\r\n>\r\n", 1, true) end
  if not close_pos then return nil end
  return sub:sub(1, close_pos+2)
end

local function build_chain(name, fxnames)
  -- create temp track
  local proj = 0
  r.InsertTrackAtIndex(r.CountTracks(proj), true)
  local tr = r.GetTrack(proj, r.CountTracks(proj)-1)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)

  local added = {}
  for _,fx in ipairs(fxnames) do
    if add_fx_by_name(tr, fx) then added[#added+1]=fx end
  end

  local ok, chunk = r.GetTrackStateChunk(tr, "", false)
  local fxchunk = ok and extract_fxchain_chunk(chunk) or nil

  -- delete temp track
  r.DeleteTrack(tr)

  return fxchunk, added
end

local function build_template(name, fxnames)
  local proj = 0
  r.InsertTrackAtIndex(r.CountTracks(proj), true)
  local tr = r.GetTrack(proj, r.CountTracks(proj)-1)
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)

  local added = {}
  for _,fx in ipairs(fxnames) do
    if add_fx_by_name(tr, fx) then added[#added+1]=fx end
  end

  local ok, chunk = r.GetTrackStateChunk(tr, "", false)
  local trchunk = ok and extract_track_chunk(chunk) or nil

  r.DeleteTrack(tr)
  return trchunk, added
end

-- Define starter chains/templates (order matters)
-- Use common stock FX names that typically exist
local PACK = {
  fxchains = {
    { name="IFLS - Vocal Strip (Stock)", fx={
      "ReaEQ (Cockos)",
      "ReaComp (Cockos)",
      "ReaXcomp (Cockos)",
      "ReaVerbate (Cockos)"
    }},
    { name="IFLS - IDM Glitch (Stock)", fx={
      "ReaDelay (Cockos)",
      "ReaFIR (Cockos)",
      "JS: Time Adjustment/delay",
      "JS: Pitch Shifter"
    }},
    { name="IFLS - Drum Bus Punch (Stock)", fx={
      "ReaEQ (Cockos)",
      "ReaComp (Cockos)",
      "ReaXcomp (Cockos)"
    }},
    { name="IFLS - Master Light (Stock)", fx={
      "ReaEQ (Cockos)",
      "ReaComp (Cockos)",
      "ReaXcomp (Cockos)",
      "JS: Event Horizon Limiter/Clipper"
    }},
  },
  tracktemplates = {
    { name="IFLS - Vocal Track (Stock)", fx={
      "ReaEQ (Cockos)",
      "ReaComp (Cockos)",
      "ReaVerbate (Cockos)"
    }},
    { name="IFLS - IDM FX Track (Stock)", fx={
      "ReaDelay (Cockos)",
      "ReaFIR (Cockos)",
      "JS: Time Adjustment/delay"
    }},
  }
}

local res = r.GetResourcePath()
local sep = package.config:sub(1,1)

local fx_dir = res..sep.."FXChains"..sep.."IFLS"
local tt_dir = res..sep.."TrackTemplates"..sep.."IFLS"
mkdir_p(fx_dir); mkdir_p(tt_dir)

local report = {}
report[#report+1] = "IFLS FXChains/TrackTemplates generator report\n"

for _,c in ipairs(PACK.fxchains) do
  local fxchunk, added = build_chain(c.name, c.fx)
  if fxchunk then
    local path = fx_dir..sep..c.name..".RfxChain"
    write_all(path, fxchunk)
    report[#report+1] = ("FXChain: %s  (added %d FX)"):format(path, #added)
  else
    report[#report+1] = ("FXChain FAILED: %s"):format(c.name)
  end
end

for _,t in ipairs(PACK.tracktemplates) do
  local trchunk, added = build_template(t.name, t.fx)
  if trchunk then
    local path = tt_dir..sep..t.name..".RTrackTemplate"
    write_all(path, trchunk)
    report[#report+1] = ("TrackTemplate: %s  (added %d FX)"):format(path, #added)
  else
    report[#report+1] = ("TrackTemplate FAILED: %s"):format(t.name)
  end
end

local rep_path = res..sep.."IFLS_FXCHAINS_TRACKTEMPLATES_REPORT.txt"
write_all(rep_path, table.concat(report, "\n").."\n")

r.MB("Done.\n\nCreated FXChains and TrackTemplates in your resource path.\nReport:\n"..rep_path, "IFLS Pack", 0)
