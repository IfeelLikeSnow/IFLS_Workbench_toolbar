IFLS Preferred Format + Workflow Pack v1.3.4
===========================================
Build: 2026-02-01T09:06:00.139635 UTC

New in v1.3.4
- Scanner v1.4:
  * infer_format detects file paths (.vst3/.clap/.dll/.component)
  * optional ident_norm column (package-root for VST3/CLAP)
- Generator v1.3.4:
  * optional ident normalization layer for matching (handles VST3 Contents/binary path vs package-root)
  * keeps output idents as RAW installed idents (required by REAPER FX folders)
  * retains v1.3.3 features: deterministic preferred selection, hard-preferred, audit report, merge mode

Scripts included
1) IFLS_Scan_InstalledFX_WithFormat_AndFolders_v1_4.lua
2) IFLS_Generate_FX_Folders_from_primary_category_v11_v1_3_4.lua
3) IFLS_Create_FXChains_And_TrackTemplates_v1_0.lua

Recommended workflow
1) Run Scanner v1.4 -> creates CSV in Resource Path
2) Run Generator v1.3.4:
   - Format-split: NO (dedup)
   - Use scanner CSV: YES (recommended)
   - Hard-Preferred: optional
   - Ident normalization: YES if you see VST3 "Contents" idents or want standardized package-root in master
   - Audit report: YES (recommended)
3) Import generated reaper-fxfolders.IFLS.generated.ini

References
- EnumInstalledFX: https://www.reaper.fm/sdk/reascript/reascripthelp.html
- reaper-fxfolders.ini structure: https://mespotin.uber.space/Ultraschall/Reaper-Filetype-Descriptions.html
