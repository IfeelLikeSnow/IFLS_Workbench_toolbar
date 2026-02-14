# MIDI Network Fix Hints (V71)

Practical fixes for common MIDI Doctor findings.

## HIGH: Multiple clock masters
**Fix**
- Pick **one** master (recommended: DAW).
- Disable clock out on other devices (OXI, grooveboxes).
- In DAW MIDI settings: enable Sync only on the master->slave route.

## HIGH: OXI forwards clock while configured as slave
**Fix**
- In routing (mioXM/patch/router): **block clock** on OXI->devices routes.
- If you *want* OXI to be master, then DAW must not send clock.

## MED: Missing realtime.clock=block on OXI->device
**Fix**
- Add filter rule: realtime.clock=block on every OXI->device route.

## MED: SysEx route not restrictive
**Fix**
- Make SysEx routes dedicated to target devices:
  - DAW -> FB-01 (SysEx only)
  - DAW -> PSS-580 (SysEx only)
  - MicroFreak SysEx via MCC-export .syx (send with SWS)

## LOW: SysEx route carries clock/transport
**Fix**
- Split into:
  - realtime-only route
  - sysex-only route

## Recommended workflow
1) Open project → AutoDoctor runs → read `Docs/MIDINetwork_Doctor_Report.md`
2) Adjust `Workbench/MIDINetwork/Data/midinet_profile.json`
3) Re-export wiring sheet if topology changed
