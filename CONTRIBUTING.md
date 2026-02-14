# Contributing

## Quick rules
1. Follow POLICY.md (no time-limited/muting plugins in shipped presets).
2. Keep changes small and reviewable.
3. For big changes, open a SIP or RFC first.

## Adding a new preset checklist
- [ ] Intent & use_case_id
- [ ] Routing mode specified
- [ ] mix_ready vs resample_only set
- [ ] Patch instructions included (if hardware involved)
- [ ] Knob clocks included (if hardware involved)
- [ ] Safety post-chain present (EQ/gate/clip if destructive)
- [ ] No disallowed plugins

## Files
- Presets: `Data/IFLS_Workbench/chains/chain_presets.json`
- Use-cases: `Data/IFLS_Workbench/chains/use_cases.json`
- Docs: `Docs/`
