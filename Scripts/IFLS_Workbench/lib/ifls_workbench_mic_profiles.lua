-- ifls_workbench_mic_profiles.lua
-- Simple, editable mic EQ starting points (field recording cleanup).
-- Values are intentionally conservative: mostly HPF + small presence shaping.

return {
  -- Dynamics (vocal / general purpose)
  {
    id="behringer_xm8500",
    aliases={"xm8500","behringer xm8500"},
    hpf_hz=90,
    presence={freq_hz=3500, gain_db=1.5, q=1.0},
    notes="Dynamic. Often benefits from rumble cut + mild presence."
  },
  {
    id="sennheiser_md400",
    aliases={"md 400","md400","sennheiser md 400","sennheiser md400"},
    hpf_hz=90,
    presence={freq_hz=3000, gain_db=1.0, q=1.0},
    notes="Dynamic. Gentle cleanup."
  },
  {
    id="beyerdynamic_tg_v35s",
    aliases={"tg v35","tg v35 s","v35s","beyerdynamic tg v35"},
    hpf_hz=100,
    presence={freq_hz=3800, gain_db=1.5, q=1.2},
    notes="Dynamic. Slight presence often helps."
  },

  -- Condensers
  {
    id="behringer_b1",
    aliases={"b-1","b1","behringer b-1","behringer b1"},
    hpf_hz=70,
    presence={freq_hz=4500, gain_db=1.0, q=1.0},
    notes="LDC. Keep it subtle; field recordings can get harsh fast."
  },
  {
    id="behringer_c2",
    aliases={"c-2","c2","behringer c-2","behringer c2"},
    hpf_hz=80,
    presence={freq_hz=5000, gain_db=0.8, q=1.0},
    notes="SDC pair/single. Often just needs rumble cut."
  },

  -- Shotgun
  {
    id="rode_ntg4plus",
    aliases={"ntg4","ntg4+","ntg 4+","rode ntg4+","røde ntg4+","rode ntg4plus"},
    hpf_hz=80,
    presence={freq_hz=4200, gain_db=0.8, q=1.0},
    notes="Shotgun. Conservative EQ; avoid over-brightening."
  },

  -- Contact / experimental
  {
    id="mcm_36_010_coil",
    aliases={"36-010","36 010","telephone pick-up","pickup coil","mcm 36-010"},
    hpf_hz=40,
    presence={freq_hz=2000, gain_db=-1.0, q=1.0},
    notes="Telephone pickup coil. Often mid-forward; cut gently if needed."
  },
  {
    id="soma_ether",
    aliases={"soma ether","ether"},
    hpf_hz=30,
    presence={freq_hz=2500, gain_db=-0.5, q=1.0},
    notes="SOMA Ether (electromagnetic). Very program dependent."
  },
  {
    id="lom_geofon",
    aliases={"geofon","geofón","lom geofon","lom geofón"},
    hpf_hz=25,
    presence={freq_hz=1600, gain_db=-0.5, q=1.0},
    notes="Geofón (contact). Usually: rumble management, then taste."
  },
  {
    id="korg_cm300",
    aliases={"cm-300","cm300","korg cm-300"},
    hpf_hz=35,
    presence={freq_hz=2200, gain_db=-0.5, q=1.0},
    notes="Contact mic (piezo). Often resonant; start with HPF."
  },

  -- Unknown / niche
  {
    id="zeppelin_cortado_mk3",
    aliases={"cortado","cortado mk iii","cortado mk3","zeppelin cortado"},
    hpf_hz=70,
    presence={freq_hz=4200, gain_db=0.5, q=1.0},
    notes="Assumed condenser-style profile. Fine-tune once you hear it."
  },

  -- Phone capture (cleanup profile)
  {
    id="samsung_s25_ultra",
    aliases={"s25","s25 ultra","galaxy s25 ultra","samsung s25","samsung s25 ultra"},
    hpf_hz=120,
    presence={freq_hz=3000, gain_db=0.5, q=1.0},
    notes="Phone recordings: reduce rumble + keep EQ minimal; depends on app/codec."
  },
}
