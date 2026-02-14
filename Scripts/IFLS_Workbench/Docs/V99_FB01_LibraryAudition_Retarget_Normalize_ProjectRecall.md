# V99: FB-01 Library Audition + Retarget/Normalize + Project Recall

Generated: 2026-02-09T20:27:52.639296Z

## Added tools
- `IFLS_FB01_Project_Save_Recall.lua` : store a voice .syx path (+md5) into ProjectExtState
- `IFLS_FB01_Project_Apply_Recall.lua` : send stored voice on demand (safe hash prompt)
- `IFLS_FB01_Normalize_DeviceID.lua` : best-effort normalize SysEx device id / channel (FB-01 family header F0 43 75 <dev>)
- `IFLS_FB01_Retarget_Bank1_Bank2.lua` : retarget common bank dumps where byte7 indicates bank (0/1)

## Browser
- Adds audition workflow buttons:
  - Audition (send + remember)
  - Revert (re-send last audition)

## Sound Editor
- Library tab now includes:
  - Browser open
  - Project Recall save/apply
  - Normalize/Retarget shortcuts

## Reference implementation
- Edisyn YamahaFB01 / YamahaFB01Rec used as reference for:
  - Bank/voice recognition heuristics
  - Timing requirements (bank packet streaming, future)
