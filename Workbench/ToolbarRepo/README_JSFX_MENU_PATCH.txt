IFLS Workbench - JSFX Menu Patch

This adds a single ReaScript that scans REAPER's resource folder:
  Effects/IFLS_Workbench/

and presents all found JSFX in a popup menu (Track FX / Take FX).

Install (repo):
  Scripts/IFLS_Workbench/Tools/JSFX/IFLS_Workbench_Menu_JSFX_All.lua

Then in REAPER:
  Actions -> Show action list -> ReaScript: Load -> select the file

Toolbar:
  Options -> Customize menus/toolbars...
  Select Floating toolbar 16 (or your toolbar)
  Remove individual JSFX buttons
  Add one button that runs: IFLS Workbench - JSFX Menu (compact launcher)

Then Export the toolbar to MenuSets/ and commit to GitHub.
