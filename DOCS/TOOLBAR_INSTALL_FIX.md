# IFLSWB Toolbar install fix (Import error)

If REAPER shows:

> ReaperMenu file does not have menu/toolbar compatible with 'Floating toolbar 1'

…then the `.ReaperMenu` file you selected was exported for another toolbar slot (often TB16).

## Fix options

### Option A (no file editing)
In **Options → Customize toolbars/menus…** select the toolbar slot that matches the file:
- If your file is for TB16, select **Floating toolbar 16**, then import.

### Option B (retarget to TB1..TB16)
Run the script:

`Scripts/IFLS_Workbench/Tools/Toolbar/IFLSWB_Toolbar_Retarget_ReaperMenu.lua`

Pick the source `.ReaperMenu`, enter target toolbar number, then import the created file.

## Icons
REAPER does not embed PNGs into `.ReaperMenu` files; it only references icon filenames.
Ensure icons exist at:

`<REAPER resource path>/Data/toolbar_icons/`
