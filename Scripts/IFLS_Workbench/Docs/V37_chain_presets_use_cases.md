# V37 Chains: Presets + Use-Case Selector for Chain Builder Wizard

Timestamp: 2026-02-03T05:56:56Z

## Added data
- Data/IFLS_Workbench/chains/chain_presets.json
- Data/IFLS_Workbench/chains/use_cases.json
- Data/IFLS_Workbench/chains/presets.json
- Data/IFLS_Workbench/chains/README.md

## Added UI
- Chain Builder Wizard: new "Chain Presets" panel:
  - Use-Case dropdown
  - Preset dropdown
  - Load preset into builder
  - Copy preset summary
  - Step list + knob hints displayed as clock + percent

## Notes
- If a preset references a `device_id` not present in profiles_list, it will load empty for that step (safe no-op).
- knob_hints use 0..100 percent scale.

