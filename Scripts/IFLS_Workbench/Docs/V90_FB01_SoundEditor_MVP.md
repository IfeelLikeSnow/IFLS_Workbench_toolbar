# V90: FB-01 Sound Editor (MVP)

Generated: 2026-02-09T17:27:36.018106Z

## Added
- `Workbench/FB01/Core/ifls_fb01_sysex.lua`
- `Workbench/FB01/Data/fb01_params_mvp.json`
- `Workbench/FB01/Editor/IFLS_FB01_SoundEditor.lua`
- `Workbench/FB01/Pack_v8/Scripts/IFLS_FB01_Send_SysEx_FromExtState.lua`

## Hub
- Added button: "FB-01 Sound Editor (MVP)"

## MVP scope
- Live SysEx parameter changes:
  - Voice params
  - Operator params (OP1..OP4)
  - Instrument params (basic)
- Request buttons:
  - Request Voice dump (per instrument)
  - Request Set dump
  - Request Bank dump (bank 0)

## Notes
- Values are exposed as 0..127 sliders for MVP.
- Librarian/Recall still uses existing Pack v8 dump/ExtState tools.
