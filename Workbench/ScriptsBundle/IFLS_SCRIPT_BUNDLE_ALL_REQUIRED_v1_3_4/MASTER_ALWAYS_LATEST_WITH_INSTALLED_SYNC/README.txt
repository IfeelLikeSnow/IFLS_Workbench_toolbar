IFLS ALWAYS_LATEST v11.7 (single truth) + Installed Sync
========================================================
Build timestamp: 20260201_090621

This package is based on:
- ALWAYS_LATEST: IFLS_ALWAYS_LATEST_v11_7_20260131_SINGLE_TRUTH_FINAL_AFTER_NEXT200_NEW6_INTEGRITYFIX2.zip
- Installed scan: IFLS_INSTALLED_FX_WITH_FORMAT_FOLDERS_PREFERRED_20260201_094232.csv

Changes:
- Added 38 installed plugins that were missing from master (IEM suite + local JSFX + Polygon2 + ReaTeam Autopan)
- Assigned primary_category_v11 and set verification flags:
  * IEM (21) + Polygon2 (1): web_verified_v11=true
  * IFLS Workbench JSFX (15) + ReaTeam JSFX (1): verified_auto_strict_v11=true

Files:
- IFLS_ALWAYS_LATEST_v11_7_20260201_090621_SINGLE_TRUTH_WITH_INSTALLED_SYNC.csv (master)
- IFLS_v11_7_ADD_MISSING_INSTALLED_PATCH_20260201_090621.csv (new rows only)
- IFLS_v11_7_ADD_MISSING_INSTALLED_REPORT_20260201_090621.json (summary)

Notes:
- Ident strings are kept as RAW installed idents ("truth").
- Use the included generator/scanner pack v1.3.4 for improved format detection + optional ident normalization matching.
