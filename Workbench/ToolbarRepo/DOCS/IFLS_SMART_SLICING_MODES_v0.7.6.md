# IFLS Smart Slicing Modes (v0.7.6)

## Adds
- Smart Slicing Mode Menu: Normal / Clicks & Pops / Drones
- Clickify: turns each slice into a micro click/pop around its peak (AudioAccessor)
- Drone Chop: glue -> time-chop with fades
- Helper: select items on IFLS Slices tracks

## Install
Copy into your REAPER resource path:
%APPDATA%\REAPER\Scripts\IFLS_Workbench\Tools\

Register via Actions -> ReaScript -> Load... or your IFLS installer.

## Notes
- AudioAccessor functions are documented in REAPER's ReaScript API.
- Drone chop uses built-in action 41588 ("Item: Glue items") if Glue first=1.
