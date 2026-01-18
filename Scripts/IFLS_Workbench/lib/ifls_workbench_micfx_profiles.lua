-- @description IFLS Workbench: MicFX Profiles Library
-- @version 0.1.0
-- @noindex
-- @author IFLS (ported from DF95)
-- @about
--   Shared MicFX profile logic + mic name parsing for IFLS Workbench MicFX tools.

-- ifls_workbench_micfx_profiles.lua
-- Gemeinsame Mic-Profil-Logik (Zoom F6 / Field Recording)
-- Wird von:
--   - DF95_Apply_MicFX_ByTrackName_v2.lua
--   - DF95_MicFX_Profile_GUI.lua
-- verwendet.

local r = reaper

local M = {}

------------------------------------------------------------
-- Trackname -> Mic-Key Mapping
------------------------------------------------------------

M.MIC_NAME_MAP = {
  xm8500          = "XM8500",
  tgv35s          = "TG_V35S",
  tgv35           = "TG_V35S",
  md400           = "MD400",
  sennheisermd400 = "MD400",
  b1              = "B1",
  behringerb1     = "B1",
  ntg4            = "NTG4P",
  ntg4plus        = "NTG4P",
  ntg4p           = "NTG4P",
  c2              = "C2_MONO",
  c2mono          = "C2_MONO",
  c2stereo        = "C2_STEREO",
  geofon          = "GEOFON",
  lomgeofon       = "GEOFON",
  ether           = "ETHER",
  somaether       = "ETHER",
  cm300           = "CM300_MONO",
  cm300stereo     = "CM300_STEREO",
  cortado         = "CORTADO_MONO",
  cortadomkiii    = "CORTADO_MONO",
  cortadostereo   = "CORTADO_STEREO",
  mcm             = "MCM_TELECOIL_MONO",
  mcmtelecoil     = "MCM_TELECOIL_MONO",
}

M.MIC_MODE = {
  XM8500            = "mono",
  TG_V35S           = "mono",
  MD400             = "mono",
  B1                = "mono",
  NTG4P             = "mono",
  C2_MONO           = "mono",
  C2_STEREO         = "stereo",
  GEOFON            = "mono",
  ETHER             = "mono",
  CM300_MONO        = "mono",
  CM300_STEREO      = "stereo",
  CORTADO_MONO      = "mono",
  CORTADO_STEREO    = "stereo",
  MCM_TELECOIL_MONO = "mono",
}

------------------------------------------------------------
-- MIC_PROFILES:
-- Mehrere Varianten pro Mic-SchlÃ¼ssel
------------------------------------------------------------

M.MIC_PROFILES = {

  XM8500 = {
    desc = "Behringer XM8500 â€“ dynamisch, SM58-Ã¤hnlich",
    profiles = {
      default = {
        label = "Neutral",
        hpf_freq = 80,
        eq_bands = {
          { type="bell",      freq=250,   gain_db=-2,   q=1.0 },
          { type="bell",      freq=4000,  gain_db=-2,   q=1.2 },
          { type="bell",      freq=10000, gain_db=-2,   q=0.7 },
        },
        comp = { ratio=2.0, attack_ms=10, release_ms=150 },
      },
      dialog = {
        label = "Dialog",
        hpf_freq = 80,
        eq_bands = {
          { type="bell",      freq=220,   gain_db=-2,   q=1.0 },
          { type="bell",      freq=3500,  gain_db=-1.5, q=1.0 },
        },
        comp = { ratio=2.2, attack_ms=8, release_ms=140 },
      },
      shout = {
        label = "Shout / Screams",
        hpf_freq = 90,
        eq_bands = {
          { type="bell",      freq=250,   gain_db=-3,   q=1.0 },
          { type="bell",      freq=4000,  gain_db=-3,   q=1.2 },
          { type="bell",      freq=9000,  gain_db=-2,   q=0.8 },
        },
        comp = { ratio=3.0, attack_ms=5, release_ms=120 },
      },
    },
  },

  TG_V35S = {
    desc = "beyerdynamic TG V35 s â€“ superniere",
    profiles = {
      default = {
        label = "Neutral",
        hpf_freq = 80,
        eq_bands = {
          { type="bell", freq=220,  gain_db=-2, q=1.0 },
          { type="bell", freq=5000, gain_db=+1, q=0.9 },
        },
        comp = { ratio=2.0, attack_ms=15, release_ms=200 },
      },
      dialog = {
        label = "Dialog",
        hpf_freq = 80,
        eq_bands = {
          { type="bell", freq=220,  gain_db=-2, q=1.0 },
          { type="bell", freq=3500, gain_db=+1, q=1.0 },
        },
        comp = { ratio=2.2, attack_ms=10, release_ms=180 },
      },
    },
  },

  MD400 = {
    desc = "Sennheiser MD400 â€“ Speech/Gitarre",
    profiles = {
      default = {
        label = "Neutral",
        hpf_freq = 75,
        eq_bands = {
          { type="bell", freq=220,  gain_db=-2,   q=1.0 },
          { type="bell", freq=3500, gain_db=+1.5, q=1.0 },
        },
        comp = { ratio=2.5, attack_ms=12, release_ms=180 },
      },
      dialog = {
        label = "Dialog",
        hpf_freq = 80,
        eq_bands = {
          { type="bell", freq=200,  gain_db=-2,   q=1.0 },
          { type="bell", freq=3200, gain_db=+1.5, q=1.0 },
        },
        comp = { ratio=2.2, attack_ms=10, release_ms=160 },
      },
    },
  },

  B1 = {
    desc = "Behringer B1 â€“ LDC, eher bright",
    profiles = {
      default = {
        label = "Neutral Vox",
        hpf_freq = 80,
        eq_bands = {
          { type="bell", freq=200,  gain_db=-2, q=1.0 },
          { type="bell", freq=7500, gain_db=-2, q=0.8 },
        },
        comp = { ratio=2.0, attack_ms=8, release_ms=150 },
      },
      soft = {
        label = "Soft / Warm",
        hpf_freq = 75,
        eq_bands = {
          { type="bell", freq=200,  gain_db=-2, q=1.0 },
          { type="bell", freq=6000, gain_db=-2, q=0.8 },
        },
        comp = { ratio=2.0, attack_ms=5, release_ms=140 },
      },
    },
  },

  NTG4P = {
    desc = "Rode NTG4+ â€“ Shotgun",
    profiles = {
      default = {
        label = "Dialog",
        hpf_freq = 80,
        eq_bands = {
          { type="bell", freq=3000,  gain_db=-2,   q=1.0 },
          { type="bell", freq=11000, gain_db=-1.5, q=0.7 },
        },
        comp = { ratio=2.5, attack_ms=8, release_ms=150 },
      },
      ambience = {
        label = "Ambience",
        hpf_freq = 60,
        eq_bands = {
          { type="bell", freq=3000, gain_db=-1,   q=1.0 },
        },
        comp = { ratio=1.7, attack_ms=15, release_ms=220 },
      },
    },
  },

  C2_MONO = {
    desc = "Behringer C-2 â€“ SDC",
    profiles = {
      default = {
        label = "Neutral Overhead/FX",
        hpf_freq = 70,
        eq_bands = {
          { type="bell", freq=200,  gain_db=-3,   q=1.0 },
          { type="bell", freq=9000, gain_db=-1.5, q=0.8 },
        },
        comp = { ratio=1.8, attack_ms=20, release_ms=250 },
      },
      room = {
        label = "Room/Ambience",
        hpf_freq = 60,
        eq_bands = {
          { type="bell", freq=180,  gain_db=-2,   q=1.0 },
          { type="bell", freq=8000, gain_db=-1,   q=0.9 },
        },
        comp = { ratio=1.5, attack_ms=25, release_ms=280 },
      },
    },
  },

  C2_STEREO = {
    ref = "C2_MONO",
    desc = "C-2 Stereo-Paar",
  },

  GEOFON = {
    desc = "LOM GeofÃ³n â€“ tieffrequente Quellen",
    profiles = {
      default = {
        label = "Sub Detail",
        hpf_freq = 15,
        lpf_freq = 1500,
        eq_bands = {
          { type="shelf_low", freq=50,  gain_db=-3, q=0.7 },
          { type="bell",      freq=250, gain_db=-3, q=1.0 },
        },
        comp = { ratio=3.0, attack_ms=25, release_ms=300 },
      },
      impact = {
        label = "Impact / Hits",
        hpf_freq = 20,
        lpf_freq = 1000,
        eq_bands = {
          { type="shelf_low", freq=60,  gain_db=-2, q=0.7 },
          { type="bell",      freq=200, gain_db=-2, q=1.0 },
        },
        comp = { ratio=4.0, attack_ms=15, release_ms=320 },
      },
    },
  },

  ETHER = {
    desc = "SOMA Ether â€“ EM-Receiver",
    profiles = {
      default = {
        label = "Texture",
        hpf_freq = 50,
        lpf_freq = 12000,
        eq_bands = {
          { type="bell", freq=5000, gain_db=-3, q=1.0 },
        },
        comp = { ratio=2.0, attack_ms=8, release_ms=150 },
      },
      clean = {
        label = "Cleaner",
        hpf_freq = 60,
        lpf_freq = 10000,
        eq_bands = {
          { type="bell", freq=5000, gain_db=-4, q=1.0 },
        },
        comp = { ratio=1.7, attack_ms=12, release_ms=180 },
      },
    },
  },

  CM300_MONO = {
    desc = "Korg CM-300 â€“ Kontakt-Piezo",
    profiles = {
      default = {
        label = "Neutral Contact",
        hpf_freq = 70,
        eq_bands = {
          { type="bell", freq=220,  gain_db=-3, q=1.0 },
          { type="bell", freq=1500, gain_db=-3, q=1.2 },
        },
        comp = { ratio=2.0, attack_ms=12, release_ms=200 },
      },
      gentle = {
        label = "Gentle",
        hpf_freq = 70,
        eq_bands = {
          { type="bell", freq=220,  gain_db=-2, q=1.0 },
          { type="bell", freq=2000, gain_db=-2, q=1.2 },
        },
        comp = { ratio=1.7, attack_ms=15, release_ms=220 },
      },
    },
  },

  CM300_STEREO = {
    ref = "CM300_MONO",
    desc = "CM-300 Stereo",
  },

  CORTADO_MONO = {
    desc = "Zeppelin Cortado MkIII â€“ Kontaktmic + Preamp",
    profiles = {
      default = {
        label = "Resonant",
        hpf_freq = 60,
        eq_bands = {
          { type="bell", freq=250, gain_db=-3, q=3.0 },
          { type="bell", freq=800, gain_db=-3, q=3.0 },
        },
        comp = { ratio=2.0, attack_ms=15, release_ms=200 },
      },
      controlled = {
        label = "Controlled",
        hpf_freq = 60,
        eq_bands = {
          { type="bell", freq=250, gain_db=-2.5, q=3.0 },
          { type="bell", freq=800, gain_db=-2.5, q=3.0 },
          { type="bell", freq=3000, gain_db=-2, q=2.0 },
        },
        comp = { ratio=2.2, attack_ms=12, release_ms=220 },
      },
    },
  },

  CORTADO_STEREO = {
    ref = "CORTADO_MONO",
    desc = "Cortado Stereo",
  },

  MCM_TELECOIL_MONO = {
    desc = "MCM 36-010 Telephone Pick-Up Coil â€“ Telefonband / EM-Pickup",
    profiles = {
      default = {
        label = "Telephone Band",
        hpf_freq = 250,
        lpf_freq = 4000,
        eq_bands = {
          { type="bell", freq=1000, gain_db=-2, q=1.0 },
        },
        comp = { ratio=2.0, attack_ms=8, release_ms=150 },
      },
      narrow = {
        label = "Narrow / Radio",
        hpf_freq = 300,
        lpf_freq = 3500,
        eq_bands = {
          { type="bell", freq=800, gain_db=-2, q=1.0 },
          { type="bell", freq=2000, gain_db=-2, q=1.0 },
        },
        comp = { ratio=2.3, attack_ms=8, release_ms=160 },
      },
    },
  },
}

------------------------------------------------------------
-- Normalisierung, Profil-Zugriff
------------------------------------------------------------

function M.normalize_name(s)
  s = (s or ""):lower()
  s = s:gsub("Ã¤","ae"):gsub("Ã¶","oe"):gsub("Ã¼","ue"):gsub("ÃŸ","ss")
  s = s:gsub("[^a-z0-9]+","")
  return s
end

function M.get_mic_key_from_trackname(name)
  local key = M.normalize_name(name or "")
  return M.MIC_NAME_MAP[key]
end

function M.get_profile(mic_key, profile_name)
  local entry = M.MIC_PROFILES[mic_key]
  if not entry then return nil end

  if entry.ref then
    local base = M.MIC_PROFILES[entry.ref]
    entry = base
  end

  if not entry or not entry.profiles then return nil end
  profile_name = profile_name or "default"
  local prof = entry.profiles[profile_name]
  if not prof then
    prof = entry.profiles["default"]
  end
  return prof
end

function M.get_profile_names(mic_key)
  local entry = M.MIC_PROFILES[mic_key]
  if not entry then return {} end
  if entry.ref then
    entry = M.MIC_PROFILES[entry.ref]
  end
  if not entry or not entry.profiles then return {} end
  local t = {}
  for name, p in pairs(entry.profiles) do
    t[#t+1] = name
  end
  table.sort(t)
  return t
end

function M.get_profile_label(mic_key, profile_name)
  local p = M.get_profile(mic_key, profile_name)
  return p and (p.label or profile_name) or profile_name
end

------------------------------------------------------------
-- Mic-Chain + EQ-/Comp-Anwendung
------------------------------------------------------------

function M.add_mic_chain(track)
  if not track then return nil, nil end

  -- JS Gain
  r.TrackFX_AddByName(track, "VST: JS: Utility/gain", false, -1000)

  -- ReaEQ
  local fx_eq = r.TrackFX_GetEQ(track, true)

  -- ReaComp
  local fx_comp = r.TrackFX_AddByName(track, "ReaComp (Cockos)", false, -1000)

  return fx_eq, fx_comp
end

local BANDTYPE = {
  HIPASS   = 0,
  LOSHELF  = 1,
  BAND     = 2,
  NOTCH    = 3,
  HISHELF  = 4,
  LOPASS   = 5,
}

local PARAMTYPE = {
  FREQ = 0,
  GAIN = 1,
  Q    = 2,
}

local function set_eq_band(track, fx_eq, bandtype, bandidx, freq, gain_db, q)
  if not fx_eq or fx_eq < 0 then return end
  r.TrackFX_SetEQBandEnabled(track, fx_eq, bandtype, bandidx, true)
  if freq then
    r.TrackFX_SetEQParam(track, fx_eq, bandtype, bandidx, PARAMTYPE.FREQ, freq, false)
  end
  if gain_db then
    r.TrackFX_SetEQParam(track, fx_eq, bandtype, bandidx, PARAMTYPE.GAIN, gain_db, false)
  end
  if q then
    r.TrackFX_SetEQParam(track, fx_eq, bandtype, bandidx, PARAMTYPE.Q, q, false)
  end
end

local function apply_eq_profile(track, fx_eq, profile)
  if not fx_eq or fx_eq < 0 or not profile then return end

  -- HPF
  if profile.hpf_freq then
    set_eq_band(track, fx_eq, BANDTYPE.HIPASS, 0, profile.hpf_freq, nil, 0.7)
  end

  -- LPF
  if profile.lpf_freq then
    set_eq_band(track, fx_eq, BANDTYPE.LOPASS, 0, profile.lpf_freq, nil, 0.7)
  end

  -- zusÃ¤tzliche BÃ¤nder
  local band_counts = {}
  if profile.eq_bands then
    for _,b in ipairs(profile.eq_bands) do
      local bt = BANDTYPE.BAND
      if b.type == "bell" then
        bt = BANDTYPE.BAND
      elseif b.type == "shelf_low" then
        bt = BANDTYPE.LOSHELF
      elseif b.type == "shelf_high" then
        bt = BANDTYPE.HISHELF
      end

      local idx = band_counts[bt] or 0
      band_counts[bt] = idx + 1

      set_eq_band(
        track, fx_eq,
        bt, idx,
        b.freq,
        b.gain_db or 0,
        b.q or 0.7
      )
    end
  end
end

local function apply_comp_profile(track, fx_comp, profile)
  if not fx_comp or fx_comp < 0 or not profile or not profile.comp then return end

  local num_params = r.TrackFX_GetNumParams(track, fx_comp)
  if not num_params or num_params <= 0 then return end

  local idx_attack, idx_release, idx_ratio

  for p = 0, num_params-1 do
    local _, pname = r.TrackFX_GetParamName(track, fx_comp, p, "")
    pname = (pname or ""):lower()
    if pname:find("attack") then
      idx_attack = p
    elseif pname:find("release") then
      idx_release = p
    elseif pname:find("ratio") then
      idx_ratio = p
    end
  end

  local function set_ms(idx, desired_ms)
    if not idx or not desired_ms then return end
    local _, _, minval, maxval = r.TrackFX_GetParamEx(track, fx_comp, idx)
    local val = desired_ms
    if val < minval then val = minval end
    if val > maxval then val = maxval end
    local norm = (val - minval) / (maxval - minval)
    r.TrackFX_SetParamNormalized(track, fx_comp, idx, norm)
  end

  local function set_ratio(idx, desired_ratio)
    if not idx or not desired_ratio then return end
    local _, _, minval, maxval = r.TrackFX_GetParamEx(track, fx_comp, idx)
    local val = desired_ratio
    if val < minval then val = minval end
    if val > maxval then val = maxval end
    local norm = (val - minval) / (maxval - minval)
    r.TrackFX_SetParamNormalized(track, fx_comp, idx, norm)
  end

  set_ms(idx_attack, profile.comp.attack_ms)
  set_ms(idx_release, profile.comp.release_ms)
  set_ratio(idx_ratio, profile.comp.ratio)
end

function M.apply_profile(track, mic_key, profile_name)
  if not track or not mic_key then return end
  local prof = M.get_profile(mic_key, profile_name)
  if not prof then return end

  local fx_eq, fx_comp = M.add_mic_chain(track)
  apply_eq_profile(track, fx_eq, prof)
  apply_comp_profile(track, fx_comp, prof)
end

return M
