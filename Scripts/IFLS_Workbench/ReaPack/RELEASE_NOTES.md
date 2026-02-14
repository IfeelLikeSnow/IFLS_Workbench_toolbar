# Release engineering notes (V104)

- Keep `-- @version` consistent across scripts.
- Prefer stable tags for ReaPack stable channel and `main` for nightly.
- CI should run:
  - Lua syntax check (luac/luacheck optional)
  - JSON validation for profiles
  - PSS580 test report on fixtures
