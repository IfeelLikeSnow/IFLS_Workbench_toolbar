#!/usr/bin/env python3
import json
from pathlib import Path
import pandas as pd
from datetime import datetime, timezone

def main():
    base = Path("Data/IFLS_Workbench/device_profiles")
    rows=[]
    for p in base.glob("*.json"):
        obj=json.loads(p.read_text(encoding="utf-8"))
        controls=obj.get("controls") or []
        ms=obj.get("manual_sources") or []
        meta=obj.get("meta") or {}
        rows.append({
            "id": obj.get("id"),
            "name_de": obj.get("name_de"),
            "manufacturer": obj.get("manufacturer"),
            "model": obj.get("model"),
            "priority_group": obj.get("priority_group"),
            "category_de": obj.get("category_de"),
            "controls_count": len(controls),
            "manual_sources_count": len(ms),
            "controls_completeness": meta.get("controls_completeness",""),
            "manual_verified": bool(meta.get("manual_verified")),
            "panel_verified": bool(meta.get("panel_verified")) or bool(obj.get("controls_verified_by_image")),
        })
    df=pd.DataFrame(rows).sort_values(["priority_group","manufacturer","name_de"])
    out_dir=Path("Docs")
    out_dir.mkdir(exist_ok=True)
    ts=datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    df.to_csv(out_dir/f"coverage_report_{ts}.csv", index=False)
    with pd.ExcelWriter(out_dir/f"coverage_report_{ts}.xlsx", engine="openpyxl") as w:
        df.to_excel(w, index=False, sheet_name="coverage")
        (df.groupby(["priority_group","controls_completeness"]).size().reset_index(name="devices")
         ).to_excel(w, index=False, sheet_name="summary")
    print("Wrote", ts)

if __name__ == "__main__":
    main()
