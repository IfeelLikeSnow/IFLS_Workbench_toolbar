-- @version 0.0.1

-- @description IFLS Workbench: PolyWAV Toolbox (ImGui)
-- @author I feel like snow (based on IFLSWB)
-- @version 1.0
-- @about
--   ImGui-Toolbox fÃ¼r Multichannel/PolyWAV-Items (z.B. Zoom F6).
--   Funktionen:
--   * Anzeige selektierter Multichannel-Items
--   * Explode via REAPER-Standard-Action
--   * ZoomF6-Mapping (Name/Farbe/Pan) mit Presets
--   * SampleDB Multi-UCS Bridge (ZoomF6-EintrÃ¤ge + AI-Felder)
--   * Home-Zone-Heuristik aus Pfadnamen
--   * Log-Bereich im GUI
--   * Extra-Buttons: Nur Mapping / Nur SampleDB

local r = reaper

------------------------------------------------------------
-- Basic Helpers
------------------------------------------------------------

local sep = package.config:sub(1,1)

local function basename(path)
  if not path then return "" end
  local p = path:gsub("\\", "/")
  local name = p:match(".*/(.*)$") or p
  return name
end

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

local function msg(m)
  r.ShowConsoleMsg(tostring(m) .. "\n")
end

------------------------------------------------------------
-- Log System (GUI)
------------------------------------------------------------

local log_lines = {}

local function log(msg)
  msg = tostring(msg or "")
  log_lines[#log_lines+1] = os.date("%H:%M:%S ") .. msg
  if #log_lines > 200 then
    table.remove(log_lines, 1)
  end
end

------------------------------------------------------------
-- PolyWAV / Item Analyse
------------------------------------------------------------

local function get_item_channel_count(item)
  if not item then return 0 end
  local take = r.GetActiveTake(item)
  if not take or not r.TakeIsMIDI(take) then
    local src = take and r.GetMediaItemTake_Source(take)
    if src then
      local ch = r.GetMediaSourceNumChannels(src)
      return ch or 0
    end
  end
  return 0
end

local function get_wav_info(path)
  local src = r.PCM_Source_CreateFromFile(path)
  if not src then return nil end
  local len = r.GetMediaSourceLength(src)
  local sr  = r.GetMediaSourceSampleRate(src)
  local ch  = r.GetMediaSourceNumChannels(src)
  r.PCM_Source_Destroy(src)
  return {
    length     = len or 0,
    samplerate = sr or 0,
    channels   = ch or 0,
  }
end

local function collect_poly_items()
  local items = {}
  local cnt = r.CountSelectedMediaItems(0)
  for i = 0, cnt-1 do
    local it = r.GetSelectedMediaItem(0, i)
    local ch = get_item_channel_count(it)
    if ch and ch > 1 then
      local take = r.GetActiveTake(it)
      local src = take and r.GetMediaItemTake_Source(take)
      local path = src and r.GetMediaSourceFileName(src, "")
      local info = path and get_wav_info(path) or nil
      items[#items+1] = {
        item       = it,
        channels   = ch,
        path       = path,
        name       = basename(path),
        length_sec = info and info.length or 0,
        samplerate = info and info.samplerate or 0,
      }
    end
  end
  return items
end

------------------------------------------------------------
-- Zoom F6 Mapping Presets
------------------------------------------------------------

local CMD_EXPLODE_MULTICHANNEL = 40438  -- ggf. im Action-List prÃ¼fen

local ZOOMF6_PRESETS = {
  ["Standard (Boom + 2 Lav + Stereo Amb)"] = {
    { ch = 1, short = "CH1", role = "Boom",  color = 0x0090FF, pan = 0.0  },
    { ch = 2, short = "CH2", role = "Lav1", color = 0x00E0FF, pan = -0.25 },
    { ch = 3, short = "CH3", role = "Lav2", color = 0x00E0FF, pan =  0.25 },
    { ch = 4, short = "CH4", role = "AmbL", color = 0x8080FF, pan = -1.0  },
    { ch = 5, short = "CH5", role = "AmbR", color = 0x8080FF, pan =  1.0  },
    { ch = 6, short = "CH6", role = "Spare",color = 0x808080, pan =  0.0  },
  },

  ["Dialog Only (Boom + Lavs)"] = {
    { ch = 1, short = "CH1", role = "Boom",  color = 0x0090FF, pan = 0.0  },
    { ch = 2, short = "CH2", role = "Lav1", color = 0x00E0FF, pan = -0.20 },
    { ch = 3, short = "CH3", role = "Lav2", color = 0x00E0FF, pan =  0.20 },
    { ch = 4, short = "CH4", role = "Spare",color = 0x808080, pan =  0.0  },
    { ch = 5, short = "CH5", role = "Spare",color = 0x808080, pan =  0.0  },
    { ch = 6, short = "CH6", role = "Spare",color = 0x808080, pan =  0.0  },
  },
}

local zoomf6_preset_names = {}
for name,_ in pairs(ZOOMF6_PRESETS) do
  zoomf6_preset_names[#zoomf6_preset_names+1] = name
end
table.sort(zoomf6_preset_names)

local zoomf6_active_preset_name = zoomf6_preset_names[1]
local zoomf6_preset_index = 1

local function get_zoomf6_mapping()
  return ZOOMF6_PRESETS[zoomf6_active_preset_name]
end

local function get_track_index(tr)
  if not tr then return -1 end
  local idx = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
  if not idx then return -1 end
  return math.floor(idx - 1)
end

local function rename_track_and_items_for_channel(tr, map_entry)
  if not tr or not map_entry then return end
  local base_name = string.format("F6 %s â€“ %s",
    map_entry.short or ("CH"..tostring(map_entry.ch or "?")),
    map_entry.role or "")

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
        newname = base_name .. " | " .. newname
      end
      r.GetSetMediaItemTakeInfo_String(take, "P_NAME", newname, true)
    end
  end
end

local function apply_zoomf6_mapping_to_tracks(track_infos)
  local mapping = get_zoomf6_mapping()
  if not mapping then return end

  for _, info in ipairs(track_infos or {}) do
    if info.channels == 6 then
      local base_idx = info.track_index or get_track_index(info.track)
      if base_idx >= 0 then
        for i, map_entry in ipairs(mapping) do
          local tr = r.GetTrack(0, base_idx + (i - 1))
          if tr and map_entry then
            rename_track_and_items_for_channel(tr, map_entry)
          end
        end
      end
    end
  end
end

local function build_zoomf6_channel_meta()
  local mapping = get_zoomf6_mapping()
  local chmeta = {}
  if mapping then
    for _, map in ipairs(mapping) do
      chmeta[#chmeta+1] = {
        ch    = map.ch,
        short = map.short,
        role  = map.role,
        pan   = map.pan,
        color = map.color,
      }
    end
  end
  return chmeta
end

------------------------------------------------------------
-- SampleDB Multi-UCS Bridge (ZoomF6)
------------------------------------------------------------

local function get_db_path_multi_ucs()
  local res = get_resource_path()
  local dir = join_path(res, "Support")
  dir = join_path(dir, "IFLSWB_SampleDB")
  return dir, join_path(dir, "IFLSWB_SampleDB_Multi_UCS.json")
end

local function ensure_dir(path)
  if r.GetFileAttributes then
    local attr = r.GetFileAttributes(path)
    if attr then return true end
  end
  if sep == "\\" then
    os.execute(string.format('mkdir "%s"', path))
  else
    os.execute(string.format('mkdir -p "%s"', path))
  end
  return true
end

local function json_decode_simple(str)
  if not str or str == "" then return nil end
  local ok, res = pcall(function()
    return load("return " .. str, "json", "t", {})()
  end)
  if ok then return res end
  return nil
end

local function json_encode_simple(v, indent)
  indent = indent or ""
  local function json_escape(s)
    s = tostring(s or "")
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
          table.insert(parts, next_indent ..
            "\"" .. json_escape(k) .. "\": " .. encode_any(item, next_indent))
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

local function load_sampledb_multi_ucs()
  local dir, db_path = get_db_path_multi_ucs()
  ensure_dir(dir)
  local f = io.open(db_path, "r")
  if not f then
    return {
      version = "IFLSWB_MultiUCS_Auto",
      created = os.date("%Y-%m-%d %H:%M:%S"),
      items   = {},
    }, db_path
  end
  local content = f:read("*a")
  f:close()
  local db = json_decode_simple(content)
  if type(db) ~= "table" then
    db = {
      version = "IFLSWB_MultiUCS_Auto",
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
    r.ShowMessageBox(
      "Kann IFLSWB SampleDB Multi-UCS nicht schreiben:\n"..tostring(db_path),
      "IFLS Workbench PolyWAV Toolbox â€“ SampleDB Bridge", 0)
    return false
  end
  f:write(json_encode_simple(db, ""))
  f:close()
  return true
end

local function infer_home_zone_from_path(path)
  if not path then return nil end
  local p = path:lower()
  if p:find("kitchen") or p:find("kÃ¼che") or p:find("k%c3%bcche") then
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
        local home_zone  = infer_home_zone_from_path(p)

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
          zoom_channels   = build_zoomf6_channel_meta(),
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
-- Extra Helpers: Remap / Only-DB
------------------------------------------------------------

local function remap_selected_tracks_as_zoomf6()
  local cnt = r.CountSelectedTracks(0)
  if cnt == 0 then
    log("Remap: keine Tracks selektiert.")
    return
  end
  local mapping = get_zoomf6_mapping()
  if not mapping then
    log("Remap: kein ZoomF6-Preset ausgewÃ¤hlt.")
    return
  end

  for i = 0, cnt-1 do
    local tr = r.GetSelectedTrack(0, i)
    local map_entry = mapping[i+1]
    if tr and map_entry then
      rename_track_and_items_for_channel(tr, map_entry)
    end
  end

  log(string.format("Remap: %d selektierte Tracks als ZoomF6 (%s) gemappt.",
    cnt, zoomf6_active_preset_name or ""))
end

local function add_selected_items_to_sampledb()
  local count = r.CountSelectedMediaItems(0)
  if count == 0 then
    log("SampleDB: keine Items selektiert.")
    return
  end
  local items = {}
  for i = 0, count-1 do
    local it = r.GetSelectedMediaItem(0, i)
    local ch = get_item_channel_count(it)
    local take = r.GetActiveTake(it)
    local src = take and r.GetMediaItemTake_Source(take)
    local path = src and r.GetMediaSourceFileName(src, "")
    if path and path ~= "" then
      items[#items+1] = {
        item     = it,
        channels = ch or 1,
        path     = path,
        name     = basename(path),
      }
    end
  end

  if #items == 0 then
    log("SampleDB: keine gÃ¼ltigen Dateien fÃ¼r Bridge gefunden.")
    return
  end

  local added = insert_zoomf6_items_into_sampledb(items)
  if added and added > 0 then
    log(string.format("SampleDB: %d Items hinzugefÃ¼gt (nur DB).", added))
  else
    log("SampleDB: keine neuen Items (nur DB).")
  end
end

------------------------------------------------------------
-- Explode + Mapping + DB
------------------------------------------------------------

local function do_explode_multichannel(opt_enable_mapping, opt_enable_sampledb)
  local items = collect_poly_items()
  if #items == 0 then
    r.ShowMessageBox(
      "Keine Multichannel-Items ausgewÃ¤hlt.\n\n" ..
      "Bitte wÃ¤hle mindestens ein Item mit mehr als einem Kanal aus\n" ..
      "(z.B. Zoom F6 PolyWAV) und versuche es erneut.",
      "IFLS Workbench PolyWAV Toolbox",
      0
    )
    return
  end

  local track_infos = {}
  local track_infos_list = {}
  for _, it in ipairs(items) do
    local tr = r.GetMediaItem_Track(it.item)
    if tr then
      local idx = get_track_index(tr)
      local existing = track_infos[tr]
      if not existing or (it.channels or 0) > (existing.channels or 0) then
        track_infos[tr] = {
          track       = tr,
          track_index = idx,
          channels    = it.channels or 0,
        }
      end
    end
  end
  for _, info in pairs(track_infos) do
    track_infos_list[#track_infos_list+1] = info
  end

  r.Undo_BeginBlock()
  r.Main_OnCommand(CMD_EXPLODE_MULTICHANNEL, 0)

  if opt_enable_mapping then
    apply_zoomf6_mapping_to_tracks(track_infos_list)
    log(string.format("Explode: ZoomF6-Mapping (%s) angewendet.", zoomf6_active_preset_name or ""))
  else
    log("Explode: ZoomF6-Mapping deaktiviert.")
  end

  if opt_enable_sampledb then
    local added = insert_zoomf6_items_into_sampledb(items)
    if added and added > 0 then
      log(string.format("Explode: %d ZoomF6-Items in SampleDB eingetragen.", added))
    else
      log("Explode: keine neuen SampleDB-EintrÃ¤ge (alles vorhanden).")
    end
  else
    log("Explode: SampleDB Bridge deaktiviert.")
  end

  r.Undo_EndBlock("IFLS Workbench PolyWAV Toolbox â€“ Explode + ZoomF6 + SampleDB", -1)
end

------------------------------------------------------------
-- ImGui Setup
------------------------------------------------------------

local ctx = nil
local opt_enable_mapping  = true
local opt_enable_sampledb = true

local function ensure_imgui()
  if ctx and r.ImGui_ValidatePtr(ctx, "ImGui_Context*") then
    return ctx
  end
  if not r.ImGui_CreateContext then
    r.ShowMessageBox(
      "ReaImGui scheint nicht installiert zu sein.\n\n" ..
      "Bitte Ã¼ber ReaPack das Paket 'ReaImGui' installieren.",
      "IFLS Workbench PolyWAV Toolbox", 0)
    return nil
  end
  ctx = r.ImGui_CreateContext("IFLS Workbench PolyWAV Toolbox")
  return ctx
end

------------------------------------------------------------
-- GUI Loop
------------------------------------------------------------

local function loop()
  local ctx = ensure_imgui()
  if not ctx then return end

  r.ImGui_SetNextWindowSize(ctx, 640, 420, r.ImGui_Cond_FirstUseEver())
  local visible, open = r.ImGui_Begin(ctx, "IFLS Workbench PolyWAV Toolbox â€“ ZoomF6", true)

  if visible then
    r.ImGui_Text(ctx, "Selektierte Multichannel-Items (z.B. Zoom F6 PolyWAV):")

    local items = collect_poly_items()
    if #items == 0 then
      r.ImGui_Text(ctx, "Keine Multichannel-Items in der Selektion.")
    else
      if r.ImGui_BeginTable(ctx, "poly_items", 4, r.ImGui_TableFlags_Borders() | r.ImGui_TableFlags_RowBg()) then
        r.ImGui_TableSetupColumn(ctx, "Datei")
        r.ImGui_TableSetupColumn(ctx, "KanÃ¤le")
        r.ImGui_TableSetupColumn(ctx, "LÃ¤nge (s)")
        r.ImGui_TableSetupColumn(ctx, "Samplerate")
        r.ImGui_TableHeadersRow(ctx)

        for _, it in ipairs(items) do
          r.ImGui_TableNextRow(ctx)
          r.ImGui_TableSetColumnIndex(ctx, 0)
          r.ImGui_Text(ctx, it.name or "(unbenannt)")
          r.ImGui_TableSetColumnIndex(ctx, 1)
          r.ImGui_Text(ctx, tostring(it.channels or 0))
          r.ImGui_TableSetColumnIndex(ctx, 2)
          r.ImGui_Text(ctx, string.format("%.2f", it.length_sec or 0))
          r.ImGui_TableSetColumnIndex(ctx, 3)
          r.ImGui_Text(ctx, tostring(it.samplerate or 0))
        end

        r.ImGui_EndTable(ctx)
      end
    end

    r.ImGui_Dummy(ctx, 0, 8)

    -- Preset-Auswahl
    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Zoom F6 Mapping Preset:")
    local combo_items = table.concat(zoomf6_preset_names, "\0") .. "\0"
    local changed, new_idx = r.ImGui_Combo(ctx, "Preset", zoomf6_preset_index-1, combo_items)
    if changed then
      zoomf6_preset_index = new_idx + 1
      zoomf6_active_preset_name = zoomf6_preset_names[zoomf6_preset_index]
      log("Preset gewechselt auf: " .. (zoomf6_active_preset_name or ""))
    end

    r.ImGui_Dummy(ctx, 0, 8)

    -- Optionen
    if r.ImGui_Checkbox(ctx, "ZoomF6 Mapping (Name/Farbe/Pan)", opt_enable_mapping) then
      opt_enable_mapping = not opt_enable_mapping
    end
    if r.ImGui_Checkbox(ctx, "SampleDB Bridge (Multi-UCS Eintrag)", opt_enable_sampledb) then
      opt_enable_sampledb = not opt_enable_sampledb
    end

    r.ImGui_Dummy(ctx, 0, 10)

    -- Haupt-Button: Explode + Mapping + DB
    if r.ImGui_Button(ctx, "Explode Multichannel Items (REAPER Action)", 0, 0) then
      do_explode_multichannel(opt_enable_mapping, opt_enable_sampledb)
    end
    r.ImGui_SameLine(ctx)
    r.ImGui_Text(ctx, "â†’ nutzt REAPER-Action + IFLSWB-Mapping/Bridge")

    r.ImGui_Dummy(ctx, 0, 8)

    -- Zusatzfunktionen
    if r.ImGui_Button(ctx, "Nur Mapping auf selektierte Tracks", 0, 0) then
      remap_selected_tracks_as_zoomf6()
    end
    r.ImGui_SameLine(ctx)
    if r.ImGui_Button(ctx, "Nur SampleDB aktualisieren (selektierte Items)", 0, 0) then
      add_selected_items_to_sampledb()
    end

    r.ImGui_Dummy(ctx, 0, 10)
    r.ImGui_Separator(ctx)
    r.ImGui_Text(ctx, "Log:")
    local child_flags = 0
    if r.ImGui_ChildFlags_Border then child_flags = r.ImGui_ChildFlags_Border() end
    if r.ImGui_ChildFlags_Borders then child_flags = r.ImGui_ChildFlags_Borders() end -- ReaImGui v0.9+ rename
    r.ImGui_BeginChild(ctx, "IFLSWB_PolyWAV_Log", -1, 100, child_flags)
    local start_idx = math.max(1, #log_lines - 50)
    for i = start_idx, #log_lines do
      r.ImGui_Text(ctx, log_lines[i])
    end
    r.ImGui_EndChild(ctx)
  end

  r.ImGui_End(ctx)

  if open then
    r.defer(loop)
  else
    -- Fenster geschlossen
  end
end

------------------------------------------------------------
-- Start
------------------------------------------------------------

loop()

