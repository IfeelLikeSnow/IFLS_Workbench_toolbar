IFLS Workbench Toolbar – Installation (Windows)

Install into REAPER resource folder (NOT inside Scripts/IFLS_Workbench_toolbar):
  C:\Users\ifeel\AppData\Roaming\REAPER\

This ZIP is laid out like the REAPER resource root:
  Data/, Effects/, FXChains/, Scripts/, MenuSets/

IMPORTANT: If you currently have duplicates like:
  ...\Scripts\IFLS_Workbench_toolbar\IFLS Workbench\Scripts\IFLS_Workbench\...

Delete the whole folder:
  ...\Scripts\IFLS_Workbench_toolbar\IFLS Workbench\
and keep only:
  ...\Scripts\IFLS_Workbench\

After installing, run:
  Scripts/IFLS_Workbench/IFLS_Workbench_Toolbar_Generate_ReaperMenu.lua
to generate a local MenuSets/*.ReaperMenu that matches your command IDs.
