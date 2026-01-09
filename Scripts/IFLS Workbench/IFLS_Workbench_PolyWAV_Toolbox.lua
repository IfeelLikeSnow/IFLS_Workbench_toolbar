-- @description IFLS Workbench: PolyWAV Toolbox (ImGui)
-- @version 1.0.0
-- @author DF95 (ported for IFLS Workbench by I feel like snow)
-- @link GitHub https://github.com/IfeelLikeSnow/IFLS_Workbench_toolbar
-- @donation PayPal https://www.paypal.com/donate/?hosted_button_id=PK9T9DX6UFRZ8
-- @about
--   ImGui-based toolbox for field recordings / PolyWAV (e.g. Zoom F6).
--   Features are grouped in tabs (explode, channel mapping, utilities).
--
--   Requires ReaImGui (reaper.ImGui_*). If missing, the script will show a message and exit.

local r = reaper

-- ReaImGui dependency check
if not (reaper and reaper.ImGui_CreateContext) then
  reaper.MB("Missing dependency: ReaImGui (reaper.ImGui_*).\n\nInstall ReaImGui and try again.", "IFLS Workbench PolyWAV Toolbox", 0)
  return
end


------------------------------------------------------------
-- Konfiguration
------------------------------------------------------------

-- Platzhalter-ID für "Explode multichannel audio to new one-channel items"
-- Bitte anpassen, falls in deiner REAPER-Installation abweichend:
local CMD_EXPLODE_MULTICHANNEL = 40438

-- Zoom F6 Standard-Layout (6 Kanäle):
-- Diese Zuordnung kannst du bei Bedarf anpassen.
local ZOOMF6_MAPPING_6CH = {
  { ch = 1, short = "CH1", role = "Boom",  color = 0x0090FF, pan = 0.0  },  -- warm/blau-orientiert, Center
  { ch = 2, short = "CH2", role = "Lav1", color = 0x00E0FF, pan = -0.25 },  -- Lav1 leicht links
  { ch = 3, short = "CH3", role = "Lav2", color = 0x00E0FF, pan =  0.25 },  -- Lav2 leicht rechts
  { ch = 4, short = "CH4", role = "AmbL", color = 0x8080FF, pan = -1.0  },  -- Ambience links
  { ch = 5, short = "CH5", role = "AmbR", color = 0x8080FF, pan =  1.0  },  -- Ambience rechts
  { ch = 6, short = "CH6", role = "Spare",color = 0x808080, pan =  0.0  },  -- Reserve/Aux
}
------------------------------------------------------------
-- Utility-Funktionen
------------------------------------------------------------

local sep = package.config:sub(1,1)

local function basename(path)
  return (path or ""):match("([^"..sep.."]+)$") or path
end

local function get_item_channel_count(item)
  if not item then return 0 end
  local take = r.GetActiveTake(item)
  if not take then return 0 end
  local src = r.GetMediaItemTake_Source(take)
  if not src then return 0 end
  local ch = r.GetMediaSourceNumChannels(src)
  return ch or 0
end

local function collect_poly_items()
  local items = {}
  local count = r.CountSelectedMediaItems(0)
  for i = 0, count-1 do
    local it = r.GetSelectedMediaItem(0, i)
    local ch = get_item_channel_count(it)
    if ch and ch > 1 then
      local take = r.GetActiveTake(it)
      local src = take and r.GetMediaItemTake_Source(take)
      local path = src and r.GetMediaSourceFileName(src, "")
      items[#items+1] = {
        item = it,
        channels = ch,
        path = path or "",
        name = basename(path or ""),
      }
    end
  end
  return items
  end

------------------------------------------------------------
-- Zoom F6 Channel-Mapping (Tracks/Items umbenennen)
------------------------------------------------------------

local function get_track_index(tr)
  if not tr then return -1 end
  local idx = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
  if not idx then return -1 end
  return math.floor(idx - 1)
end

local function rename_track_and_items_for_channel(tr, map_entry)
  if not tr or not map_entry then return end
  local base_name = string.format("F6 %s – %s", map_entry.short or ("CH"..tostring(map_entry.ch or "?")), map_entry.role or "")
  -- Trackname setzen
  r.GetSetMediaTrackInfo_String(tr, "P_NAME", base_name, true)

  -- Farbe setzen (falls definiert)
  if map_entry.color then
    r.SetTrackColor(tr, (map_entry.color | 0x1000000))
  end

  -- Pan setzen (falls definiert)
  if map_entry.pan then
    r.SetMediaTrackInfo_Value(tr, "D_PAN", map_entry.pan)
  end

  -- Alle Items auf diesem Track umbenennen (Take-Namen)
  local item_count = r.CountTrackMediaItems(tr)
  for i = 0, item_count-1 do
    local it = r.GetTrackMediaItem(tr, i)
    local take = it and r.GetActiveTake(it)
    if take then
      local _, old = r.GetSetMediaItemTakeInfo_String(take, "P_NAME", "", false)
      local newname = old
      if not newname or newname == "" then
        newname = base_name
      else
        -- Prefix hinzufügen, falls schon Name existiert
        newname = base_name .. " | " .. newname
      end
      r.GetSetMediaItemTakeInfo_String(take, "P_NAME", newname, true)
    end
  end
end

local function apply_zoomf6_mapping_to_tracks(track_infos)
  if not track_infos then return end

  -- Wir gehen davon aus:
  -- * pro Original-Track wurden N Kanäle (mono) auf denselben Track + darunter liegende Tracks verteilt
  -- * CH1 auf Original-Track, CH2..CHn auf neu erzeugten Tracks
  --
  -- Wir mappen nur, wenn Kanäle == 6 (Zoom F6 Preset)
  for _, info in ipairs(track_infos) do
    if info.channels == 6 then
      local base_idx = info.track_index or get_track_index(info.track)
      if base_idx >= 0 then
        for i = 1, 6 do
          local map_entry = ZOOMF6_MAPPING_6CH[i]
          local tr = r.GetTrack(0, base_idx + (i - 1))
          if tr and map_entry then
            rename_track_and_items_for_channel(tr, map_entry)
          end
        end
      end
    end
  end
end
 


------------------------------------------------------------
-- DF95 SampleDB Bridge (Multi-UCS)
------------------------------------------------------------

local function get_resource_path()
  return r.GetResourcePath()
end

local function join_path(a, b)
  if a:sub(-1) == sep then
    return a .. b
  else
    return a .. sep .. b
  end
end

local function get_db_path_multi_ucs()
  local res = get_resource_path()
  local dir = join_path(res, "Support")
  dir = join_path(dir, "DF95_SampleDB")
  return dir, join_path(dir, "DF95_SampleDB_Multi_UCS.json")
end

local function ensure_dir(path)
  local attr = r.GetFileAttributes and r.GetFileAttributes(path)
  if attr then return true end
  if sep == "\\" then
    os.execute(string.format('mkdir "%s"', path))
  else
    os.execute(string.format('mkdir -p "%s"', path))
  end
  return true
end

-- sehr einfacher JSON-Decoder/Encoder (wie im DF95 SampleDB Renamer),
-- ausreichend, da wir unsere eigenen Dateien schreiben/lesen.
local function json_decode_simple(str)
  local ok, res = pcall(function() return load("return " .. str, "json", "t", {})() end)
  if ok then return res end
  return nil
end

local function json_encode_simple(v, indent)
  indent = indent or ""
  local function json_escape(s)
    s = tostring(s)
    s = s:gsub("\\", "\\\\"):gsub("\"","\\\""):gsub("\n","\\n")
    return s
  end
  local function encode_any(val, ind)
    ind = ind or ""
    local next_indent = ind .. "  "
    if type(val) == "table" then
      if #val > 0 then
        local parts = {"[\n"}
        for i, item in ipairs(val) do
          table.insert(parts, next_indent .. encode_any(item, next_indent))
          if i < #val then table.insert(parts, ",") end
          table.insert(parts, "\n")
        end
        table.insert(parts, ind .. "]")
        return table.concat(parts)
      else
        local parts = {"{\n"}
        local first = true
        for k, item in pairs(val) do
          if not first then table.insert(parts, ",\n") end
          first = false
          table.insert(parts, next_indent.."\"" .. json_escape(k) .. "\": " .. encode_any(item, next_indent))
        end
        table.insert(parts, "\n"..ind.."}")
        return table.concat(parts)
      end
    elseif type(val) == "string" then
      return "\"" .. json_escape(val) .. "\""
    elseif type(val) == "number" then
      return tostring(val)
    elseif type(val) == "boolean" then
      return val and "true" or "false"
    else
      return "null"
    end
  end
  return encode_any(v, indent)
end

local function get_wav_info(path)
  local src = r.PCM_Source_CreateFromFile(path)
  if not src then return nil end

  local len = r.GetMediaSourceLength(src)
  local takepcm = r.GetMediaSourceSampleRate(src)
  local ch = r.GetMediaSourceNumChannels(src)

  r.PCM_Source_Destroy(src)

  return {
    length = len or 0,
    samplerate = takepcm or 0,
    channels = ch or 0,
  }
end

local function load_sampledb_multi_ucs()
  local dir, db_path = get_db_path_multi_ucs()
  ensure_dir(dir)
  local f = io.open(db_path, "r")
  if not f then
    -- Neu anlegen
    return {
      version = "DF95_MultiUCS_Auto",
      created = os.date("%Y-%m-%d %H:%M:%S"),
      items   = {},
    }, db_path
  end
  local content = f:read("*a")
  f:close()
  if not content or content == "" then
    return {
      version = "DF95_MultiUCS_Auto",
      created = os.date("%Y-%m-%d %H:%M:%S"),
      items   = {},
    }, db_path
  end
  local db = json_decode_simple(content)
  if type(db) ~= "table" then
    db = {
      version = "DF95_MultiUCS_Auto",
      created = os.date("%Y-%m-%d %H:%M:%S"),
      items   = {},
    }
  end
  if type(db.items) ~= "table" then
    db.items = {}
  end
  return db, db_path
end

local function save_sampledb_multi_ucs(db, db_path)
  local f = io.open(db_path, "w")
  if not f then
    r.ShowMessageBox("Kann DF95 SampleDB Multi-UCS nicht schreiben:\n"..tostring(db_path),
      "IFLS Workbench PolyWAV Toolbox – SampleDB Bridge", 0)
    return false
  end
  f:write(json_encode_simple(db, ""))
  f:close()
  return true
end

local function infer_home_zone_from_path(path)
  if not path then return nil end
  local p = path:lower()
  if p:find("kitchen") or p:find("k%c3%bcche") or p:find("küche") then
    return "KITCHEN"
  elseif p:find("bathroom") or p:find("bad") or p:find("bath") or p:find("toilet") or p:find("wc") then
    return "BATHROOM"
  elseif p:find("bedroom") or p:find("schlafzimmer") or p:find("sleep") then
    return "BEDROOM"
  elseif p:find("child") or p:find("kids") or p:find("kinderzimmer") then
    return "CHILDROOM"
  elseif p:find("livingroom") or p:find("wohnzimmer") or p:find("lounge") then
    return "LIVINGROOM"
  elseif p:find("basement") or p:find("keller") then
    return "BASEMENT"
  elseif p:find("hallway") or p:find("flur") or p:find("corridor") then
    return "HALLWAY"
  else
    return nil
  end

end

local function insert_zoomf6_items_into_sampledb(poly_items)
  if not poly_items or #poly_items == 0 then return 0 end
  local db, db_path = load_sampledb_multi_ucs()
  local items = db.items or {}
  db.items = items

  -- Index nach Pfad für schnelle Suche
  local by_path = {}
  for idx, it in ipairs(items) do
    if type(it) == "table" and it.path then
      by_path[it.path] = idx
    end
  end

  local added = 0
  for _, pinfo in ipairs(poly_items) do
    local p = pinfo.path
    if p and p ~= "" then
      local existing_idx = by_path[p]
      if not existing_idx then
        local info = get_wav_info(p)
        local length_sec = info and info.length or 0
        local samplerate = info and info.samplerate or 0
        local channels   = info and info.channels or (pinfo.channels or 0)

        local home_zone = infer_home_zone_from_path(p)

        local item = {
          path            = p,
          ucs_category    = "FIELDREC",
          ucs_subcategory = "ZoomF6",
          df95_catid      = "FIELDREC_ZoomF6",
          home_zone       = home_zone,
          material        = nil,
          object_class    = "PRODUCTION",
          action          = "REC",
          length_sec      = length_sec,
          samplerate      = samplerate,
          channels        = channels,
          zoom_source     = "ZoomF6",
          zoom_role_map   = "CH1=Boom;CH2=Lav1;CH3=Lav2;CH4=AmbL;CH5=AmbR;CH6=Spare",
          ai_status       = "pending",
          ai_expected     = "zoomf6_poly_dialogue_session",
          ai_tags         = {},
          ai_model        = nil,
          ai_last_update  = nil,
        }
        table.insert(items, item)
        added = added + 1
        by_path[p] = #items
      end
    end
  end

  if added > 0 then
    save_sampledb_multi_ucs(db, db_path)
  end
  return added
end

------------------------------------------------------------
-- ImGui Setup
------------------------------------------------------------

local has_imgui = (r.ImGui_CreateContext ~= nil)
if not has_imgui then
  r.ShowMessageBox(
    "ReaImGui-API nicht gefunden.\n\n" ..
    "Bitte stelle sicher, dass die ReaImGui-Erweiterung installiert ist,\n" ..
    "damit die IFLS Workbench PolyWAV Toolbox verwendet werden kann.",
    "IFLS Workbench PolyWAV Toolbox",
    0
  )
  return
end

local ctx = r.ImGui_CreateContext('IFLS Workbench PolyWAV Toolbox', r.ImGui_ConfigFlags_DockingEnable())
local FONT_SCALE = 1.0

------------------------------------------------------------
-- Hauptlogik: Explode
------------------------------------------------------------

local function do_explode_multichannel()
  local items = collect_poly_items()
  if #items == 0 then
    r.ShowMessageBox(
      "Keine Multichannel-Items ausgewählt.\n\n" ..
      "Bitte wähle mindestens ein Item mit mehr als einem Kanal aus\n" ..
      "(z.B. Zoom F6 PolyWAV) und versuche es erneut.",
      "IFLS Workbench PolyWAV Toolbox",
      0
    )
    return
  end

  -- Pro Track merken, wie viele Kanäle wir erwarten (für Zoom F6 Mapping)
  local track_infos = {}
  local track_infos_list = {}
  for _, it in ipairs(items) do
    local tr = r.GetMediaItem_Track(it.item)
    if tr then
      local idx = get_track_index(tr)
      local existing = track_infos[tr]
      if not existing or (it.channels or 0) > (existing.channels or 0) then
        track_infos[tr] = {
          track = tr,
          track_index = idx,
          channels = it.channels or 0,
        }
      end
    end
  end
  for _, info in pairs(track_infos) do
    track_infos_list[#track_infos_list+1] = info
  end

  -- Hinweis: wir rufen hier bewusst die REAPER-Standardfunktion auf.
  -- Die ID kann oben bei CMD_EXPLODE_MULTICHANNEL angepasst werden.
  r.Undo_BeginBlock()
  r.Main_OnCommand(CMD_EXPLODE_MULTICHANNEL, 0)

  -- Nach dem Explode: optional Zoom F6 Mapping auf die neuen Mono-Tracks anwenden
  if opt_enable_mapping then
    apply_zoomf6_mapping_to_tracks(track_infos_list)
  end

  -- SampleDB Bridge: ZoomF6-PolyWAVs in DF95 SampleDB Multi-UCS eintragen (optional)
  if opt_enable_sampledb then
    local added = insert_zoomf6_items_into_sampledb(items)
    if added and added > 0 then
      r.ShowConsoleMsg(string.format("IFLS Workbench PolyWAV Toolbox: %d ZoomF6-Items in SampleDB Multi-UCS ergänzt.\n", added))
    end
  end

  r.Undo_EndBlock("IFLS Workbench PolyWAV Toolbox – Explode + Zoom F6 Mapping + SampleDB Bridge", -1)
end



  ------------------------------------------------------------
-- GUI Loop
------------------------------------------------------------

------------------------------------------------------------
-- GUI State / Optionen
------------------------------------------------------------

local opt_enable_mapping   = true
local opt_enable_sampledb  = true

local function loop()
  r.ImGui_SetNextWindowSize(ctx, 600, 420, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, 'IFLS Workbench PolyWAV Toolbox', true)
  if visible then
    r.ImGui_Text(ctx, "IFLS Workbench PolyWAV Toolbox – Zoom F6 / Fieldrec")
    r.ImGui_Separator(ctx)

    r.ImGui_Text(ctx, "1. Wähle ein oder mehrere Multichannel-Items (z.B. PolyWAV vom Zoom F6).")
    r.ImGui_Text(ctx, "2. Unten siehst du eine Übersicht der selektierten Multichannel-Items.")
    r.ImGui_Text(ctx, "3. Mit dem Button kannst du REAPERs Explode-Funktion aufrufen.")
    r.ImGui_Dummy(ctx, 0, 8)

    -- Liste der gefundenen Poly-Items
    local items = collect_poly_items()
    if #items == 0 then
      r.ImGui_Text(ctx, "Keine Multichannel-Items ausgewählt.")
    else
      if r.ImGui_BeginTable(ctx, "polyitems", 3, r.ImGui_TableFlags_Borders()) then
        r.ImGui_TableSetupColumn(ctx, "Datei")
        r.ImGui_TableSetupColumn(ctx, "Kanäle")
        r.ImGui_TableSetupColumn(ctx, "Zoom F6 Hinweis")
        r.ImGui_TableHeadersRow(ctx)

        for _, it in ipairs(items) do
          r.ImGui_TableNextRow(ctx)
          r.ImGui_TableSetColumnIndex(ctx, 0)
          r.ImGui_Text(ctx, it.name ~= "" and it.name or "(unnamed)")
          r.ImGui_TableSetColumnIndex(ctx, 1)
          r.ImGui_Text(ctx, tostring(it.channels))

          r.ImGui_TableSetColumnIndex(ctx, 2)
          if it.channels == 6 then
            r.ImGui_Text(ctx, "Typischer Zoom F6: 6 Kanäle (Boom/Lav/Amb/...)")
          else
            r.ImGui_Text(ctx, "Allgemeine Multichannel-Datei")
          end
        end

        r.ImGui_EndTable(ctx)
      end
    end

    r.ImGui_Dummy(ctx, 0, 10)

    
    r.ImGui_Dummy(ctx, 0, 6)
    if r.ImGui_Checkbox(ctx, "ZoomF6 Mapping (Name/Farbe/Pan)", opt_enable_mapping) then
      opt_enable_mapping = not opt_enable_mapping
    end
    if r.ImGui_Checkbox(ctx, "SampleDB Bridge (Multi-UCS Eintrag)", opt_enable_sampledb) then
      opt_enable_sampledb = not opt_enable_sampledb
    end

    r.ImGui_Dummy(ctx, 0, 10)

    if r.ImGui_Button(ctx, "Explode Multichannel Items (REAPER Action)", 0, 0) then
      do_explode_multichannel()
    end

    r.ImGui_SameLine(ctx)
    r.ImGui_Text(ctx, "  → nutzt die REAPER-Standardfunktion (siehe Script-Kommentar).")

    r.ImGui_Dummy(ctx, 0, 12)
    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Nächste Ausbaustufen (bereits vorbereitet im Code-Design):")
    r.ImGui_BulletText(ctx, "Channel-Mapping: Boom / Lav / Ambience / EMF per Zoom F6 Layout")
    r.ImGui_BulletText(ctx, "Farbcodes & Panning-Presets pro Channel")
    r.ImGui_BulletText(ctx, "Direktes Schreiben in DF95 SampleDB / UCS-Light pro gesplittetem Kanal")
    r.ImGui_BulletText(ctx, "AI-Analyse (z.B. EMF, Water, Foley, Voice) pro Kanal")

    r.ImGui_End(ctx)
  end

  if open then
    r.defer(loop)
  else
    -- Fenster geschlossen
  end
end

r.defer(loop)