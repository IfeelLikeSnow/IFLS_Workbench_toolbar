# Clock Policy – Variant 1: REAPER is the Clock Master (recommended for recording/arrangement)

## Goal
REAPER transport (Play/Stop/Record) is the single source of truth.
mioXM distributes clock to OXI and any other devices that need it.

## REAPER settings (Windows)
1) Preferences → MIDI Devices:
   - Enable output on required mioXM ports.
2) Right-click ONLY ONE mioXM output port → enable "Send clock/SPP".
   - All other outputs: Send clock OFF.

## mioXM routing
- Route the single clock-carrying REAPER port to:
  - OXI ONE (set OXI to External clock)
  - Other devices that should follow DAW tempo
- Avoid clock loopback routes back to REAPER.

## SysEx devices (FB-01 / PSS580)
- Ensure their mioXM routes ALLOW SysEx (no SysEx filter).
- Keep SysEx routing independent of clock routing.

## Troubleshooting
- If timing drifts under heavy plugin load:
  - record with lower CPU load, or freeze/disable heavy FX during tracking.
- If double-start/stop or chaos:
  - you likely have two clock sources or a loopback route.
