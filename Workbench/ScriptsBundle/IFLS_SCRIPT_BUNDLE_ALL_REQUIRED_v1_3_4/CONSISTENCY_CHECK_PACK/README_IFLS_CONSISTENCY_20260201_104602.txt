IFLS Consistency Check Pack
==========================
Timestamp: 20260201_104602

Inputs:
- Master: IFLS_ALWAYS_LATEST_v11_7_20260131_SINGLE_TRUTH_FINAL_AFTER_NEXT200_NEW6_INTEGRITYFIX2.zip
- Installed scan: IFLS_INSTALLED_FX_WITH_FORMAT_FOLDERS_PREFERRED_20260201_094232.csv

Outputs:
1) IFLS_CONSISTENCY_AUDIT_MASTER_vs_INSTALLED_20260201_104602.csv
   Row-level audit of master: format inference, multi-format groups, normalization flags.

2) IFLS_IDENT_NORMALIZATION_CANDIDATES_20260201_104602.csv
   All master rows whose ident contains VST3 'Contents' paths; includes suggested package-root ident.
   Note: applying this changes master idents and will stop matching raw installed idents, unless you use the Generator v1.3.4 normalization layer.

3) IFLS_INSTALLED_NOT_IN_MASTER_20260201_104602.csv
   38 installed FX missing from master (needs append or patch).
   Includes inferred format + suggested primary_category_v11.

4) IFLS_CONSISTENCY_SUMMARY_20260201_104602.json
   High-level counts + breakdowns.

Interpretation quick notes:
- master_minus_installed should ideally be 0 (it is).
- installed_minus_master should ideally be 0 if master intends to represent all installed FX (it is 38 currently).
- VST3 Contents paths are normal in REAPER's EnumInstalledFX ident strings; normalization can improve portability across machines/scans.
