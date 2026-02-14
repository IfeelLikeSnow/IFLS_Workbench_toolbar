# GitHub Push Guide (IFLS_Workbench Toolbar)

## 0) Prereqs
- Install **Git**
- Optional: install **GitHub CLI (gh)** for easy auth (recommended)

## 1) Create an empty repo on GitHub
Create a new repository (e.g. `IFLS_Workbench_toolbar`) with **no README** (we already have one).

## 2) Put this repo on your disk
Unzip the provided repository ZIP so you have a folder like:

```
IFLS_Workbench_toolbar/
  index.xml
  Scripts/
  MenuSets/
  Data/
  FXChains/
  Effects/
```

## 3) Initialize git + first push
Open a terminal in the repo root (`IFLS_Workbench_toolbar/`) and run:

```bash
git init
git add -A
git commit -m "IFLS_Workbench Toolbar v0.7.5"
git branch -M main
git remote add origin https://github.com/<YOUR_USER>/<YOUR_REPO>.git
git push -u origin main
```

## 4) Tag a release (recommended)
```bash
git tag -a v0.7.5 -m "v0.7.5"
git push --tags
```

Then create a GitHub Release for `v0.7.5` and (optionally) attach the ZIP.

## 5) ReaPack Import URL
ReaPack wants the **raw** URL to `index.xml`:

```
https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main/index.xml
```

(If your default branch isn't `main`, adjust accordingly.)
