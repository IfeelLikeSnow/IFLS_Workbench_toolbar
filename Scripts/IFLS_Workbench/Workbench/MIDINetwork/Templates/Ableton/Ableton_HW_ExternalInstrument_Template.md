# Ableton Live Track Template (Hardware via External Instrument)

Use **External Instrument** per hardware device.

## Preferences -> Link/Tempo/MIDI
- Enable **Track** for ports used for Notes/CC.
- Enable **Sync** only where you want Live to send clock (usually only to OXI, if Live is master).
- Disable **Remote** unless you need mappings.

See Ableton's docs on using hardware synthesizers and MIDI settings.

## Per-device tracks
### FB-01 (8-part multitimbral)
Option A: 8 MIDI tracks:
- HW: FB-01 P1 (ch1) ... HW: FB-01 P8 (ch8)
Option B: 1 track + MIDI rack with channel-filter chains.

SysEx: Live stock workflow is weak for SysEx; use IFLS tools in REAPER or a dedicated SysEx librarian.

### PSS-580
- One External Instrument track, ch1.
- Bank 1-5 recall via device or IFLS PSS580 tools.

### MicroFreak
- One External Instrument track, ch1.
- CC automation in clips; preset recall via MCC-export .syx and IFLS SysEx tool.

### Neutron
- MIDI notes to ch1. Keep clock clean (no loops).

### Circuit Rhythm
- Configure its MIDI RX/TX settings (Note/CC/PC/Clock). Keep DAW as clock master.

## Naming convention
HW: FB-01 P1..P8, HW: PSS-580, HW: MicroFreak, HW: Neutron, HW: CircuitRhythm

## Clock policy
DAW = master, OXI = slave. Hardware receives clock only if needed.
