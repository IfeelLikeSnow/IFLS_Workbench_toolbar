# IFLS Workbench Foundations

Date: 2026-02-04

## Purpose
IFLS Workbench is a hybrid routing, sound-design, and recall system for REAPER + hardware (patchbay, Portal parallel loops, pedal FX loops), optimized for experimental / IDM workflows.

## Non‑Negotiables
- **Time-stability first**: no time‑bomb / muting / expiring plugins in shipped presets.
- **Parallel-first**: keep a Dry anchor in REAPER; destructive processing happens in parallel whenever possible.
- **Recallable**: every chain must be reproducible via patch instructions + knob clocks + routing metadata.
- **Decision support**: wizard helps choose/understand, not “auto-magic” everything.

## Design Principles
1. Routing is the language (Patchbay/Portal/FX-loops are first-class).
2. Presets are “recipes” with intent, risk, and recall.
3. Resampling is a workflow state (capture → slice → re-context).
4. Safety defaults: bandlimit, gate, clipper after feedbacky/destructive blocks.
5. Incremental evolution: deprecate, don’t silently delete/break.
