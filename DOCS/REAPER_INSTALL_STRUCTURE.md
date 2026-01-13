# IFLS_Workbench Toolbar – Correct REAPER install structure

REAPER reads different asset types from different subfolders of the **REAPER resource path**.

Open it via: `Options → Show REAPER resource path`

Expected layout:

```
<ResourcePath>/
  Scripts/
    IFLS_Workbench/
      ... (all ReaScripts)
  FXChains/
    IFLS_Workbench/
      Slicing_IDM/
      Slicing_Euclid/
      Slicing_Artists_Granular/
      ...
  Effects/
    IFLS_Workbench/
      ... (.jsfx)
  Data/
    IFLS_Workbench/
      ... (.json, icons, etc.)
  MenuSets/
    IFLS_Workbench_TB16.ReaperMenu
```

## Common mistake (breaks the Dropdown)

Do **not** place `FXChains/`, `Effects/`, `Data/` under `Scripts/`.

Example of a broken install:

```
<ResourcePath>/Scripts/IFLS_Workbench Toolbar/IFLS_Workbench/FXChains/...
```

Fix: move/copy the folders back to the resource root as shown above.

## After copying scripts

In REAPER, register scripts if needed:

- `Actions → Show action list…`
- `ReaScript → Load…`
- Load & run: `Scripts/IFLS_Workbench/IFLS_Workbench_Install_Toolbar.lua`


## Avoid nested installs (common mistake)

Do **not** extract the whole bundle into `<ResourcePath>/Scripts/`.
That creates a wrong nested layout like:

`<ResourcePath>/Scripts/IFLS Workbench Toolbar/IFLS Workbench/...`

Correct is:
- Install via **ReaPack** (recommended), or
- Run `TOOLS/Install_Zip_To_ReaperResourcePath.ps1` (copies into the right places), or
- Extract the ZIP to a temp folder and copy `Scripts/`, `Effects/`, `FXChains/`, `Data/` into the ResourcePath root.

If you already have a nested install, run:
`IFLS Workbench: Fix Misinstalled Nested Folders` (Action List).
