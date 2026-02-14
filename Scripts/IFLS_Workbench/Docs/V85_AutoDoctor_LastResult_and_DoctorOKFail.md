# V85: AutoDoctor last-result + Doctor OK/FAIL

Generated: 2026-02-07T22:00:32.038236Z

## Doctor
- Doctor now sets `doctor_last_ok=0` when it detects missing `reaper_*_exact` (for devices with contains hints).
- `doctor_last_err` will contain a short actionable message (run ApplyPorts).

## AutoDoctor
- AutoDoctor now records:
  - autodoctor_last_run_utc
  - autodoctor_last_ok
  - autodoctor_last_err
- Hub shows these fields.

## Wiring export
- Ensures a deterministic fallback wiring sheet exists if exporter didn't create one.

## Notes
- AutoDoctor last-result uses a best-effort doctor invocation wrapper.
