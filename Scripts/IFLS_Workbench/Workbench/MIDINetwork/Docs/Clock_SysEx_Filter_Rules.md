# Clock / SysEx Filter Rules (per route)

Baseline:
- DAW is the only clock master.
- OXI is clock slave (receives clock from DAW).
- OXI -> devices: block clock/start/stop unless a device truly needs it.
- SysEx: only allow on DAW -> target routes that need it (FB-01, PSS-580; MicroFreak via MCC exports).

See `Data/midinet_profile.json` for:
- Route flags
- Filter policy
- `port_map` physical wiring hints (mioXM DIN/USB host mapping)
