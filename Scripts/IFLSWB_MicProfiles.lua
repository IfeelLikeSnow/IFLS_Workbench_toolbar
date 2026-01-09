-- IFLSWB_MicProfiles.lua
-- Startpunkt-EQ-Kurven (ReaEQ) pro Mic.
-- WICHTIG: Das sind "Ear-first" Defaults, keine heiligen Wahrheiten.
-- Du kannst hier jederzeit feinjustieren.

local M = {}

local function prof(name, bands)
  return { name = name, eq = bands }
end

-- Band format:
-- { band = <int>, type = "<high pass|low pass|peak|notch|low shelf|high shelf>",
--   freq = <Hz>, gain = <dB>, q = <float> }
-- gain optional bei HP/LP, q optional (default 0.71)

M.profiles = {
  ["Generic Fieldrec"] = prof("Generic Fieldrec", {
    { band=1, type="high pass", freq=60,  q=0.71 },
    { band=2, type="peak",      freq=250, gain=-1.5, q=1.00 },
    { band=3, type="peak",      freq=4500,gain= 1.5, q=0.90 },
  }),

  ["Zoom F6 Line"] = prof("Zoom F6 Line", {
    { band=1, type="high pass", freq=40, q=0.71 },
    { band=2, type="peak",      freq=180, gain=-1.0, q=1.00 },
  }),

  ["Samsung S25 Ultra"] = prof("Samsung S25 Ultra", {
    { band=1, type="high pass", freq=80, q=0.71 },
    { band=2, type="peak",      freq=250, gain=-2.0, q=1.10 },
    { band=3, type="high shelf",freq=9000, gain=-1.5, q=0.70 },
  }),

  -- Dynamics
  ["Behringer XM8500"] = prof("Behringer XM8500", {
    { band=1, type="high pass", freq=80, q=0.71 },
    { band=2, type="peak",      freq=300, gain=-2.0, q=1.00 },
    { band=3, type="peak",      freq=4200,gain= 2.0, q=0.90 },
  }),

  ["Sennheiser MD 400"] = prof("Sennheiser MD 400", {
    { band=1, type="high pass", freq=70, q=0.71 },
    { band=2, type="peak",      freq=350, gain=-1.5, q=1.00 },
    { band=3, type="peak",      freq=3800,gain= 1.8, q=0.90 },
  }),

  ["beyerdynamic TG V35 s"] = prof("beyerdynamic TG V35 s", {
    { band=1, type="high pass", freq=80, q=0.71 },
    { band=2, type="peak",      freq=250, gain=-1.5, q=1.00 },
    { band=3, type="peak",      freq=5000,gain= 2.0, q=0.90 },
  }),

  -- Condensers / Shotgun
  ["Behringer B-1"] = prof("Behringer B-1", {
    { band=1, type="high pass", freq=60, q=0.71 },
    { band=2, type="peak",      freq=5000,gain=-1.2, q=1.20 },
    { band=3, type="high shelf",freq=11000,gain=-1.5, q=0.70 },
  }),

  ["Behringer C-2"] = prof("Behringer C-2", {
    { band=1, type="high pass", freq=80, q=0.71 },
    { band=2, type="peak",      freq=8000,gain=-1.0, q=1.00 },
    { band=3, type="peak",      freq=4500,gain= 1.0, q=0.90 },
  }),

  ["RØDE NTG4+"] = prof("RØDE NTG4+", {
    { band=1, type="high pass", freq=90, q=0.71 },
    { band=2, type="peak",      freq=4500,gain= 1.8, q=0.90 },
    { band=3, type="peak",      freq=250, gain=-1.2, q=1.10 },
  }),

  -- Contact / coils (oft band-limited)
  ["MCM 36-010 Telephone Pick-Up Coil"] = prof("MCM 36-010 Telephone Pick-Up Coil", {
    { band=1, type="high pass", freq=180, q=0.71 },
    { band=2, type="low pass",  freq=6000,q=0.71 },
    { band=3, type="peak",      freq=1200,gain= 1.0, q=1.00 },
  }),

  ["SOMA Ether"] = prof("SOMA Ether", {
    { band=1, type="high pass", freq=30, q=0.71 },
    { band=2, type="peak",      freq=120, gain=-1.0, q=1.10 },
    { band=3, type="peak",      freq=6000,gain= 1.2, q=0.90 },
  }),

  ["LOM Geofón"] = prof("LOM Geofón", {
    { band=1, type="high pass", freq=20, q=0.71 },
    { band=2, type="peak",      freq=200, gain=-1.0, q=1.00 },
    { band=3, type="peak",      freq=2500,gain= 1.0, q=0.90 },
  }),

  ["Korg CM-300"] = prof("Korg CM-300", {
    { band=1, type="high pass", freq=30, q=0.71 },
    { band=2, type="peak",      freq=3500,gain=-1.2, q=1.10 },
    { band=3, type="peak",      freq=180, gain= 0.8, q=0.90 },
  }),

  ["Zeppelin Cortado Mk III"] = prof("Zeppelin Cortado Mk III", {
    { band=1, type="high pass", freq=30, q=0.71 },
    { band=2, type="peak",      freq=250, gain=-1.0, q=1.00 },
    { band=3, type="peak",      freq=4500,gain= 1.0, q=0.90 },
  }),
}

-- Aliases / fuzzy tokens (lowercased, punctuation removed in matcher)
M.aliases = {
  ["xm8500"] = "Behringer XM8500",
  ["behringer xm8500"] = "Behringer XM8500",

  ["md400"] = "Sennheiser MD 400",
  ["md 400"] = "Sennheiser MD 400",
  ["sennheiser md 400"] = "Sennheiser MD 400",

  ["tg v35"] = "beyerdynamic TG V35 s",
  ["tg v35 s"] = "beyerdynamic TG V35 s",
  ["beyerdynamic tg v35 s"] = "beyerdynamic TG V35 s",

  ["b-1"] = "Behringer B-1",
  ["b1"] = "Behringer B-1",
  ["behringer b-1"] = "Behringer B-1",

  ["c-2"] = "Behringer C-2",
  ["c2"] = "Behringer C-2",
  ["behringer c-2"] = "Behringer C-2",

  ["ntg4"] = "RØDE NTG4+",
  ["ntg4+"] = "RØDE NTG4+",
  ["rode ntg4+"] = "RØDE NTG4+",
  ["røde ntg4+"] = "RØDE NTG4+",

  ["telephone pickup"] = "MCM 36-010 Telephone Pick-Up Coil",
  ["pick-up coil"] = "MCM 36-010 Telephone Pick-Up Coil",
  ["36-010"] = "MCM 36-010 Telephone Pick-Up Coil",
  ["mcm 36-010"] = "MCM 36-010 Telephone Pick-Up Coil",

  ["soma ether"] = "SOMA Ether",
  ["ether"] = "SOMA Ether",

  ["geofon"] = "LOM Geofón",
  ["lom geofon"] = "LOM Geofón",

  ["cm-300"] = "Korg CM-300",
  ["cm300"] = "Korg CM-300",
  ["korg cm-300"] = "Korg CM-300",

  ["cortado"] = "Zeppelin Cortado Mk III",
  ["cortado mk iii"] = "Zeppelin Cortado Mk III",
  ["zeppelin cortado"] = "Zeppelin Cortado Mk III",

  ["s25"] = "Samsung S25 Ultra",
  ["s25 ultra"] = "Samsung S25 Ultra",
  ["samsung s25 ultra"] = "Samsung S25 Ultra",

  ["zoom f6"] = "Zoom F6 Line",
  ["f6"] = "Zoom F6 Line",
}

return M