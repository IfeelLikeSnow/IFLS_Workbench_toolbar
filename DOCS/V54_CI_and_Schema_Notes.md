# V54 CI + Schema Notes

## CI additions
- **Luacheck** is run via a GitHub Marketplace action. citeturn0search1
- **JSON Schema validation** is run via a GitHub Marketplace AJV-based validator action. citeturn0search2

## SysEx note (why framing is handled carefully)
REAPER ReaScript docs note that SysEx messages inserted/retrieved as sysex events should not include bounding F0/F7 (payload only). citeturn0search0

