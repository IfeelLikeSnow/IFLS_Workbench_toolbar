#!/usr/bin/env python3
"""
Generate device profile skeletons (mixed language) from gear.json or the source XLSX.

Usage:
  python tools/generate_device_profiles.py --gear-json Data/IFLS_Workbench/gear.json --out Data/IFLS_Workbench/device_profiles
"""
import argparse, json, re
from pathlib import Path
from datetime import datetime, timezone

PRIORITY = ("synth", "fx", "routing")

def slug_id(manufacturer: str, model: str) -> str:
    s = f"{manufacturer} {model}".strip().lower()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    return s or "item"

def parse_controls(raw: str):
    if not raw:
        return []
    parts = re.split(r"[\n\r]+|•|\u2022", str(raw))
    out = []
    for p in parts:
        p = p.strip(" -\t")
        if not p:
            continue
        out.append({"name_en": p, "type": "unknown", "notes_de": ""})
    return out

def classify_priority(item):
    text = " ".join([
        item.get("main_category",""),
        item.get("sub_category",""),
        item.get("category_type",""),
        item.get("manufacturer",""),
        item.get("model",""),
        item.get("notes_text",""),
        item.get("tech_text",""),
    ]).lower()
    synth_kw = ["synth", "toy", "keyboard", "keys", "groove", "drum machine", "drum", "sampler"]
    fx_kw = ["delay","reverb","chorus","flanger","phaser","vibrato","tremolo","mod","lofi","bit","crusher","ring","pitch","whammy","filter","envelope"]
    routing_kw = ["di","reamp","patch","patchbay","mixer","interface","compress","gate","limiter","preamp"]
    if any(k in text for k in synth_kw):
        return "synth"
    if any(k in text for k in routing_kw):
        return "routing"
    if any(k in text for k in fx_kw):
        return "fx"
    return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gear-json", required=True, type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--docs-out", default=None, type=Path)
    args = ap.parse_args()

    data = json.loads(args.gear_json.read_text(encoding="utf-8"))
    gear = data.get("gear", [])
    now = datetime.now(timezone.utc).replace(microsecond=0).isoformat()

    args.out.mkdir(parents=True, exist_ok=True)
    if args.docs_out:
        args.docs_out.mkdir(parents=True, exist_ok=True)

    idx = []
    for it in gear:
        grp = classify_priority(it)
        if not grp:
            continue
        pid = it.get("id") or slug_id(it.get("manufacturer",""), it.get("model",""))
        profile = {
            "meta": {"generated_at_utc": now, "language": "mixed", "source": str(args.gear_json)},
            "id": pid,
            "name_de": f"{it.get('manufacturer','')} {it.get('model','')}".strip(),
            "manufacturer": it.get("manufacturer",""),
            "model": it.get("model",""),
            "count": int(it.get("count",0) or 0),
            "categories_de": {
                "Hauptkategorie": it.get("main_category",""),
                "Unterkategorie": it.get("sub_category",""),
                "Kategorie-Typ": it.get("category_type",""),
            },
            "priority_group": grp,
            "signal_role": [],
            "level_guess": "instrument_or_line",
            "io_raw_de": it.get("io_text",""),
            "controls_raw_de": it.get("controls_text",""),
            "controls": parse_controls(it.get("controls_text","")),
            "power_raw_de": it.get("power_text",""),
            "notes_raw_de": it.get("notes_text",""),
            "tech_raw_de": it.get("tech_text",""),
            "patchbay_name": "",
            "manual_sources": [],
            "enriched": False,
            "best_for_tags": [],
            "danger_zones_de": []
        }
        (args.out/f"{pid}.json").write_text(json.dumps(profile, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        idx.append({"id": pid, "name_de": profile["name_de"], "priority_group": grp})

        if args.docs_out:
            md = f"# {profile['name_de']}\n\n**Priority:** {grp}\n\n## Controls (EN)\n"
            for c in profile["controls"][:40]:
                md += f"- **{c['name_en']}**\n"
            (args.docs_out/f"{pid}.md").write_text(md, encoding="utf-8")

    (args.out.parent/"device_profiles_index.json").write_text(
        json.dumps({"meta":{"generated_at_utc": now}, "devices": idx}, ensure_ascii=False, indent=2)+"\n",
        encoding="utf-8"
    )

if __name__ == "__main__":
    main()
