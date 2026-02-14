# Release process (Stable vs Nightly)

## Nightly
- Every push to `main/master` regenerates `nightly/index.xml` via GitHub Actions.
- Users import nightly channel to test new changes early.

## Stable
- Create a tag: `vX.Y.Z`
- Workflow generates `index.xml` and uploads it as artifact.
- Recommended: create a GitHub Release for the tag, and paste a short changelog.

## Why channel split?
- Stable users don't get broken changes.
- Nightly users can test fixes and new scripts immediately.

ReaPack repo template guidance: citeturn0search4
reapack-index configuration support: citeturn0search0
