#!/usr/bin/env python3
"""
Enrich device_profiles from a manual_map.csv

- Downloads manuals (PDF or HTML) and extracts likely control labels using heuristics.
- Writes back to Data/IFLS_Workbench/device_profiles/<id>.json:
  - manual_sources[]
  - controls[] (EN short labels)
  - enriched=true
  - meta.manual_enriched_at_utc

This is a bootstrapper: it will not be perfect for every device, but it gets you 70% there fast.
You can then hand-edit the remaining details.

Usage:
  python tools/enrich_from_manual_map.py \
    --manual-map Data/IFLS_Workbench/manual_map.csv \
    --profiles-dir Data/IFLS_Workbench/device_profiles \
    --max 20

Notes:
- Designed for GitHub Actions (has internet). Local use requires internet.
"""
import argparse, csv, json, re
from pathlib import Path
from datetime import datetime, timezone

import requests

def now_utc():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()

def is_pdf(url: str) -> bool:
    return url.lower().endswith(".pdf")

def extract_controls_from_text(txt: str):
    # Heuristics: capture common pedal UI nouns
    patterns = [
        r"\b([A-Z][A-Z0-9/\-\s]{2,32}\b)\s+(KNOB|SWITCH|FOOTSWITCH|BUTTON|LED|JACK|INPUT|OUTPUT)",
        r"\b(KNOB|SWITCH|FOOTSWITCH|BUTTON|LED|JACK|INPUT|OUTPUT)\b[:\s\-]+([A-Z][A-Z0-9/\-\s]{2,32}\b)",
        r"\b(LEVEL|TONE|ATTACK|SUSTAIN|RATE|DEPTH|MIX|BIT|SAMPLE RATE|MODE|TYPE|TIME|FEEDBACK|REPEAT)\b",
    ]
    found = set()
    upper = txt.upper()
    for pat in patterns:
        for m in re.finditer(pat, upper):
            g = m.groups()
            if len(g) == 2 and g[0] in ("KNOB","SWITCH","FOOTSWITCH","BUTTON","LED","JACK","INPUT","OUTPUT"):
                label = g[1].strip()
            elif len(g) == 2 and g[1] in ("KNOB","SWITCH","FOOTSWITCH","BUTTON","LED","JACK","INPUT","OUTPUT"):
                label = g[0].strip()
            else:
                label = g[0].strip()
            label = re.sub(r"\s+", " ", label).strip()
            if 2 <= len(label) <= 40:
                found.add(label)
    # cleanup
    out = []
    for lab in sorted(found):
        # avoid pure nouns
        if lab in ("KNOB","SWITCH","FOOTSWITCH","BUTTON","LED","JACK","INPUT","OUTPUT"):
            continue
        out.append({"name_en": lab.title(), "type": "unknown", "notes_de": ""})
    return out[:40]

def fetch_text(url: str):
    r = requests.get(url, timeout=30)
    r.raise_for_status()
    ct = r.headers.get("content-type","").lower()
    return r.content, ct

def pdf_to_text(pdf_bytes: bytes):
    try:
        from pypdf import PdfReader
    except Exception as e:
        raise RuntimeError("Missing pypdf dependency. Add to requirements.txt") from e
    import io
    reader = PdfReader(io.BytesIO(pdf_bytes))
    text = []
    for page in reader.pages[:10]:  # cap to first 10 pages for speed
        text.append(page.extract_text() or "")
    return "\n".join(text)

def html_to_text(html_bytes: bytes):
    try:
        from bs4 import BeautifulSoup
    except Exception as e:
        raise RuntimeError("Missing beautifulsoup4 dependency. Add to requirements.txt") from e
    soup = BeautifulSoup(html_bytes, "html.parser")
    return soup.get_text("\n")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manual-map", type=Path, required=True)
    ap.add_argument("--profiles-dir", type=Path, required=True)
    ap.add_argument("--max", type=int, default=20)
    args = ap.parse_args()

    rows = []
    with args.manual_map.open("r", encoding="utf-8") as f:
        rd = csv.DictReader(f)
        for row in rd:
            if row.get("manual_url","").strip():
                rows.append(row)

    processed = 0
    for row in rows:
        if processed >= args.max:
            break
        pid = row["id"]
        url = row["manual_url"].strip()
        prof_path = args.profiles_dir / f"{pid}.json"
        if not prof_path.exists():
            continue

        prof = json.loads(prof_path.read_text(encoding="utf-8"))
        try:
            content, ct = fetch_text(url)
            if is_pdf(url) or "pdf" in ct:
                txt = pdf_to_text(content)
            else:
                txt = html_to_text(content)
            controls = extract_controls_from_text(txt)
        except Exception as e:
            prof.setdefault("meta", {})["manual_enrich_error"] = str(e)
            prof_path.write_text(json.dumps(prof, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
            continue

        # merge: keep existing controls if they look better
        if len(controls) > len(prof.get("controls") or []):
            prof["controls"] = controls
        prof["manual_sources"] = list(dict.fromkeys((prof.get("manual_sources") or []) + [url]))
        prof["enriched"] = True
        prof.setdefault("meta", {})["manual_enriched_at_utc"] = now_utc()

        prof_path.write_text(json.dumps(prof, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
        processed += 1

    print(f"Processed: {processed}")

if __name__ == "__main__":
    main()
