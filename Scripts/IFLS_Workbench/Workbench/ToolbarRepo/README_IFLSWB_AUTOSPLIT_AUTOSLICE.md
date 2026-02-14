# IFLSWB All-in-One (AutoSplit + AutoSlice AUTO)

New in this build:
- **AutoSplit + SmartSlice AUTO**: one-click mixed-content heuristic (HIT/TEX)
  - splits selected field recordings into HIT_ / TEX_ chunks (analysis before cutting)
  - then runs SmartSlice(Hits) on HIT chunks and SmartSlice(Textures) on TEX chunks
  - optional PostFix HQ tail detection

Scripts:
- Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_AutoSplit_Then_SmartSlice_AUTO.lua
- Scripts/IFLS_Workbench/Tools/SamplePack/IFLSWB_AutoSplit_MixedContent.lua

- Confidence scoring adds **MIX_** chunks when classification is uncertain; MIX is processed with the Textures slicer by default.
