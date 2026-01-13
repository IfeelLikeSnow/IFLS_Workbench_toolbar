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
