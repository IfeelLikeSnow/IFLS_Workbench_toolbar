# V59 PSS-580 Module Notes

This version adds a PSS-580 SysEx patch workflow module:
- Banks 1–5 library (manifest + .syx storage)
- ReaImGui patch browser (preview send + copy into project recall)
- Project recall send button (SWS SNM_SendSysEx)
- Capture helper to export recorded SysEx from a MIDI item to .syx

Web research (high-level):
- x80 workflow: patch banks 1–5 via MIDI send button sequences.
- device pauses briefly while receiving SysEx; manual send recommended.
- similar x80 notes via Electra One panel docs.

See sources:
- yamahamusicians x80 series editor thread
- stereoninjamusic PSS-580 specs
- electra.one PSS-480 panel notes (applies to 580/680/780)
